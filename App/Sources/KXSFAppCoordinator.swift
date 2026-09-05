import Combine
import Foundation
import KXSFCore
import WidgetKit

@MainActor
final class KXSFAppCoordinator: ObservableObject {
    let player: AudioPlayerService
    let liveShow: LiveShowStore

    private var cancellables: Set<AnyCancellable> = []
    private var artworkTask: Task<Void, Never>?
    private var requestedArtworkURL: URL?

    init(
        player: AudioPlayerService = .shared,
        liveShow: LiveShowStore = LiveShowStore()
    ) {
        self.player = player
        self.liveShow = liveShow

        player.$state
            .combineLatest(liveShow.$schedule)
            .sink { [weak self] state, schedule in
                guard let self else { return }
                let show = schedule.currentShow
                let programChanged = KXSFPlaybackSnapshot.setProgram(
                    title: show?.name,
                    timeRange: show?.timeRange,
                    artworkURL: show?.artworkURL
                )
                if programChanged {
                    WidgetCenter.shared.reloadTimelines(ofKind: KXSFConstants.homeWidgetKind)
                }

                let expectedArtworkRevision: String? = show?.artworkURL?.absoluteString
                let artworkRevision = expectedArtworkRevision.flatMap { revision in
                    KXSFArtworkRepository.data(matching: revision) == nil ? nil : revision
                }
                Task {
                    await KXSFLiveActivityManager.shared.synchronize(
                        show: show,
                        isPlaying: state.isPlaying,
                        artworkRevision: artworkRevision
                    )
                }
                self.prepareArtwork(for: show)
            }
            .store(in: &cancellables)
    }

    private func prepareArtwork(for show: KXSFShow?) {
        guard let artworkURL = show?.artworkURL else {
            artworkTask?.cancel()
            artworkTask = nil
            requestedArtworkURL = nil
            return
        }

        let revision = artworkURL.absoluteString
        if KXSFArtworkRepository.data(matching: revision) != nil {
            requestedArtworkURL = artworkURL
            // Cache hit: still push the revision into any active Live Activity.
            Task {
                await KXSFLiveActivityManager.shared.synchronize(
                    show: show,
                    isPlaying: player.state.isPlaying,
                    artworkRevision: revision
                )
            }
            return
        }
        guard requestedArtworkURL != artworkURL else { return }

        artworkTask?.cancel()
        requestedArtworkURL = artworkURL
        artworkTask = Task { [weak self] in
            do {
                let (data, response) = try await URLSession.shared.data(from: artworkURL)
                guard
                    !Task.isCancelled,
                    (response as? HTTPURLResponse)?.statusCode == 200,
                    data.count <= 5_000_000
                else { throw URLError(.badServerResponse) }
                try KXSFArtworkRepository.store(data, revision: revision)
                guard !Task.isCancelled, self?.requestedArtworkURL == artworkURL else { return }

                WidgetCenter.shared.reloadTimelines(ofKind: KXSFConstants.homeWidgetKind)
                if let self {
                    await KXSFLiveActivityManager.shared.synchronize(
                        show: self.liveShow.currentShow,
                        isPlaying: self.player.state.isPlaying,
                        artworkRevision: revision
                    )
                }
            } catch {
                if self?.requestedArtworkURL == artworkURL {
                    self?.requestedArtworkURL = nil
                }
            }
            self?.artworkTask = nil
        }
    }
}
