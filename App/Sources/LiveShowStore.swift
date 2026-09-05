import Combine
import Foundation
import KXSFCore

@MainActor
final class LiveShowStore: ObservableObject {
    nonisolated private static let scheduleURL = URL(string: "https://kxsf.fm/schedule-shows/")!
    nonisolated private static let youTubeVideosURL = URL(string: "https://www.youtube.com/@kxsfradio/videos")!
    nonisolated private static let userAgent = "KXSF/2.0 (iOS)"
    nonisolated private static let youTubeUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
    nonisolated private static let refreshInterval: TimeInterval = 15 * 60
    nonisolated private static let hostRequestLimit = 5
    nonisolated private static let uploadLimit = 12
    nonisolated private static let uploadsCacheKey = "kxsf.live.last-known-good-uploads.v1"

    @Published private(set) var schedule = KXSFSchedule(sections: [])
    @Published private(set) var uploads: [KXSFYouTubeUpload] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingUploads = false
    @Published private(set) var didFailToLoad = false

    private var lastScheduleRefresh: Date?
    private var lastUploadsRefresh: Date?
    private var hostCache: [URL: String] = [:]

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.uploadsCacheKey),
           let cached = try? JSONDecoder().decode([KXSFYouTubeUpload].self, from: data) {
            uploads = Array(cached.prefix(Self.uploadLimit))
        }
    }

    var currentShow: KXSFShow? { schedule.currentShow }
    var showName: String? { currentShow?.name }

    func refresh() async {
        if let lastScheduleRefresh,
           Date().timeIntervalSince(lastScheduleRefresh) < Self.refreshInterval,
           !schedule.shows.isEmpty {
            return
        }
        guard !isLoading else { return }

        isLoading = true
        didFailToLoad = false
        defer { isLoading = false }

        do {
            let parsedSchedule = try await Self.loadSchedule()
            guard !parsedSchedule.shows.isEmpty else {
                didFailToLoad = true
                return
            }
            schedule = parsedSchedule
            await refreshShowHosts()
            lastScheduleRefresh = .now
        } catch {
            didFailToLoad = true
        }
    }

    func refreshUploads() async {
        if let lastUploadsRefresh,
           Date().timeIntervalSince(lastUploadsRefresh) < Self.refreshInterval,
           !uploads.isEmpty {
            return
        }
        guard !isLoadingUploads else { return }
        isLoadingUploads = true
        defer { isLoadingUploads = false }

        do {
            let parsed = try await KXSFRetry.run(
                maxAttempts: 3,
                delay: { failedAttempt in
                    try await Task.sleep(for: .milliseconds(300 * failedAttempt))
                },
                operation: { _ in
                    let pageData = try await Self.fetchYouTubeVideosPage()
                    let result = await Task.detached {
                        KXSFYouTubePageParser.uploads(in: String(decoding: pageData, as: UTF8.self))
                    }.value
                    guard !result.isEmpty else { throw URLError(.cannotParseResponse) }
                    return Array(result.prefix(Self.uploadLimit))
                }
            )
            uploads = parsed
            lastUploadsRefresh = .now
            if let data = try? JSONEncoder().encode(parsed) {
                UserDefaults.standard.set(data, forKey: Self.uploadsCacheKey)
            }
        } catch {
            // Preserve the last known good official YouTube list on transient failures.
        }
    }

    private nonisolated static func fetchYouTubeVideosPage() async throws -> Data {
        var request = URLRequest(url: youTubeVideosURL)
        request.setValue(youTubeUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.timeoutInterval = 20
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    private nonisolated static func fetch(_ url: URL, timeout: TimeInterval = 15) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = timeout
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    private nonisolated static func loadSchedule() async throws -> KXSFSchedule {
        let data = try await fetch(scheduleURL)
        return await Task.detached {
            KXSFScheduleParser.schedule(in: String(decoding: data, as: UTF8.self))
        }.value
    }

    private func refreshShowHosts() async {
        var unresolved = schedule.showsPrioritizingCurrent().filter { hostCache[$0.detailURL] == nil }

        if unresolved.first?.isNowPlaying == true {
            await refreshHosts(for: [unresolved.removeFirst()])
        }

        for start in stride(from: 0, to: unresolved.count, by: Self.hostRequestLimit) {
            let end = min(start + Self.hostRequestLimit, unresolved.count)
            await refreshHosts(for: Array(unresolved[start..<end]))
        }
    }

    private func refreshHosts(for batch: [KXSFShow]) async {
        let entries = await withTaskGroup(of: (URL, String?).self, returning: [(URL, String?)].self) { group in
            for show in batch {
                group.addTask {
                    do {
                        let data = try await Self.fetch(show.detailURL, timeout: 10)
                        let host = KXSFShowDetailParser.hostName(in: String(decoding: data, as: UTF8.self))
                        return (show.detailURL, host)
                    } catch {
                        return (show.detailURL, nil)
                    }
                }
            }

            var results: [(URL, String?)] = []
            for await entry in group {
                results.append(entry)
            }
            return results
        }

        for (url, host) in entries {
            if let host { hostCache[url] = host }
        }
        schedule = schedule.enrichingHosts(hostCache)
    }
}
