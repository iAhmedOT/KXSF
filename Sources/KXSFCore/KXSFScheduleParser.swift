import Foundation

public enum KXSFWeekday: String, CaseIterable, Sendable, Equatable, Identifiable {
    case monday = "Monday"
    case tuesday = "Tuesday"
    case wednesday = "Wednesday"
    case thursday = "Thursday"
    case friday = "Friday"
    case saturday = "Saturday"
    case sunday = "Sunday"

    public var id: String { rawValue }
}

public struct KXSFShow: Sendable, Equatable, Identifiable {
    public let day: KXSFWeekday
    public let name: String
    public let timeRange: String
    public let detailURL: URL
    public let artworkURL: URL?
    public let hostName: String?
    public let isNowPlaying: Bool

    public var id: String { detailURL.absoluteString }

    public init(
        day: KXSFWeekday,
        name: String,
        timeRange: String,
        detailURL: URL,
        artworkURL: URL?,
        hostName: String? = nil,
        isNowPlaying: Bool
    ) {
        self.day = day
        self.name = name
        self.timeRange = timeRange
        self.detailURL = detailURL
        self.artworkURL = artworkURL
        self.hostName = hostName
        self.isNowPlaying = isNowPlaying
    }
}

public struct KXSFScheduleSection: Sendable, Equatable, Identifiable {
    public let day: KXSFWeekday
    public let shows: [KXSFShow]

    public var id: KXSFWeekday { day }

    public init(day: KXSFWeekday, shows: [KXSFShow]) {
        self.day = day
        self.shows = shows
    }
}

public struct KXSFSchedule: Sendable, Equatable {
    public let sections: [KXSFScheduleSection]

    public var shows: [KXSFShow] { sections.flatMap(\.shows) }
    public var currentShow: KXSFShow? { shows.first(where: \.isNowPlaying) }

    public func sections(startingWith day: KXSFWeekday) -> [KXSFScheduleSection] {
        guard let startIndex = sections.firstIndex(where: { $0.day == day }) else { return sections }
        return Array(sections[startIndex...]) + Array(sections[..<startIndex])
    }

    public func showsPrioritizingCurrent() -> [KXSFShow] {
        shows.filter(\.isNowPlaying) + shows.filter { !$0.isNowPlaying }
    }

    public func enrichingHosts(_ hostsByURL: [URL: String]) -> KXSFSchedule {
        KXSFSchedule(sections: sections.map { section in
            KXSFScheduleSection(day: section.day, shows: section.shows.map { show in
                let identity = KXSFHTMLText.showIdentity(from: show.name) ?? .init(title: show.name)
                let preferredHost = KXSFHTMLText.preferredHostName(
                    showTitle: identity.title,
                    candidateHost: hostsByURL[show.detailURL] ?? show.hostName ?? identity.embeddedHostName
                )
                return KXSFShow(
                    day: show.day,
                    name: identity.title,
                    timeRange: show.timeRange,
                    detailURL: show.detailURL,
                    artworkURL: show.artworkURL,
                    hostName: preferredHost,
                    isNowPlaying: show.isNowPlaying
                )
            })
        })
    }

    public init(sections: [KXSFScheduleSection]) {
        self.sections = sections
    }
}

public enum KXSFScheduleParser {
    public static func schedule(in html: String) -> KXSFSchedule {
        let dayMarkers = markers(in: html)
        let articles = matches(
            "<article\\b[^>]*>.*?</article>",
            in: html
        )

        var showsByDay: [KXSFWeekday: [KXSFShow]] = [:]
        var encounteredDays: [KXSFWeekday] = []

        for article in articles {
            guard
                let day = dayMarkers.last(where: { $0.offset <= article.offset })?.day,
                let show = parseShow(article.text, day: day)
            else {
                continue
            }

            if showsByDay[day] == nil {
                encounteredDays.append(day)
            }
            showsByDay[day, default: []].append(show)
        }

        return KXSFSchedule(
            sections: encounteredDays.compactMap { day in
                guard let shows = showsByDay[day], !shows.isEmpty else { return nil }
                return KXSFScheduleSection(day: day, shows: shows)
            }
        )
    }

    private static func parseShow(_ article: String, day: KXSFWeekday) -> KXSFShow? {
        guard
            let titleHTML = firstCapture(
                "<h3[^>]*class=[\\\"'][^\\\"']*proradio-post__title[^\\\"']*[\\\"'][^>]*>(.*?)</h3>",
                in: article
            ),
            let identity = KXSFHTMLText.showIdentity(from: titleHTML),
            let detailURLString = firstCapture(
                "<a[^>]*class=[\\\"'][^\\\"']*proradio-post__header__link[^\\\"']*[\\\"'][^>]*href=[\\\"']([^\\\"']+)[\\\"']",
                in: article
            ),
            let detailURL = URL(string: KXSFHTMLText.decodeEntities(detailURLString)),
            let timeHTML = firstCapture(
                "<p[^>]*class=[\\\"'][^\\\"']*proradio-itemmetas[^\\\"']*[\\\"'][^>]*>(.*?)</p>",
                in: article
            ),
            let timeRange = text(fromHTML: timeHTML)
        else {
            return nil
        }

        let artworkURL = firstCapture("<img[^>]*src=[\\\"']([^\\\"']+)[\\\"']", in: article)
            .flatMap { URL(string: KXSFHTMLText.decodeEntities($0)) }

        return KXSFShow(
            day: day,
            name: identity.title,
            timeRange: timeRange,
            detailURL: detailURL,
            artworkURL: artworkURL,
            hostName: identity.embeddedHostName,
            isNowPlaying: article.range(of: "now playing", options: [.caseInsensitive, .diacriticInsensitive]) != nil
        )
    }

    private static func markers(in html: String) -> [(offset: Int, day: KXSFWeekday)] {
        KXSFWeekday.allCases.flatMap { day in
            let escapedDay = NSRegularExpression.escapedPattern(for: day.rawValue)
            return matches("<h[1-6][^>]*>\\s*\(escapedDay)\\s*</h[1-6]>", in: html)
                .map { (offset: $0.offset, day: day) }
        }
        .sorted { $0.offset < $1.offset }
    }

    private static func text(fromHTML html: String) -> String? {
        KXSFHTMLText.plainText(html)
    }

    private static func firstCapture(_ pattern: String, in text: String) -> String? {
        matches(pattern, in: text).first?.captures.first
    }

    private static func matches(_ pattern: String, in text: String) -> [Match] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return []
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { result in
            guard let fullRange = Range(result.range, in: text) else { return nil }
            let captures = (1..<result.numberOfRanges).compactMap { index -> String? in
                guard let range = Range(result.range(at: index), in: text) else { return nil }
                return String(text[range])
            }
            return Match(offset: result.range.location, text: String(text[fullRange]), captures: captures)
        }
    }

    private struct Match {
        let offset: Int
        let text: String
        let captures: [String]
    }
}
