import AVFoundation
import Combine
import KXSFCore
import WidgetKit

@MainActor
final class AudioPlayerService: NSObject, ObservableObject {
    static let shared = AudioPlayerService()

    @Published private(set) var state: PlaybackState = .idle {
        didSet {
            guard oldValue.isPlaying != state.isPlaying else { return }
            if KXSFPlaybackSnapshot.setIsPlaying(state.isPlaying) {
                WidgetCenter.shared.reloadTimelines(ofKind: KXSFConstants.homeWidgetKind)
            }
        }
    }

    private let endpoint: any StreamEndpointProviding
    private var player: AVPlayer?
    private var timeControlObservation: NSKeyValueObservation?
    private var startupTask: Task<Void, Never>?
    private var playbackGeneration = 0

    init(endpoint: any StreamEndpointProviding = DirectKXSFEndpoint()) {
        self.endpoint = endpoint
        super.init()
    }

    func togglePlayback() {
        switch state {
        case .loading, .playing:
            pause()
        case .idle, .failed:
            play()
        }
    }

    func play() {
        guard startupTask == nil else { return }
        switch state {
        case .idle, .failed:
            break
        case .loading, .playing:
            return
        }

        playbackGeneration += 1
        let generation = playbackGeneration
        state = state.applying(.playRequested)

        startupTask = Task { [weak self] in
            guard await Self.configureAudioSession() else {
                guard let self, generation == self.playbackGeneration, !Task.isCancelled else { return }
                self.startupTask = nil
                self.state = .failed(.streamUnavailable)
                return
            }
            guard let self, generation == self.playbackGeneration, !Task.isCancelled else { return }

            let player = AVPlayer(url: self.endpoint.liveStreamURL)
            self.player = player
            self.observePlaybackState(of: player)
            self.startupTask = nil
            player.play()
        }
    }

    func pause() {
        playbackGeneration += 1
        startupTask?.cancel()
        startupTask = nil
        timeControlObservation?.invalidate()
        timeControlObservation = nil
        player?.pause()
        player = nil
        state = .idle
    }

    private nonisolated static func configureAudioSession() async -> Bool {
        await Task.detached(priority: .userInitiated) {
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .default)
                try session.setActive(true)
                return true
            } catch {
                return false
            }
        }.value
    }

    private func observePlaybackState(of player: AVPlayer) {
        timeControlObservation?.invalidate()
        timeControlObservation = player.observe(
            \.timeControlStatus,
            options: [.initial, .new]
        ) { [weak self] player, _ in
            Task { @MainActor [weak self] in
                guard let self, self.player === player else { return }

                switch player.timeControlStatus {
                case .playing:
                    self.state = .playing
                case .waitingToPlayAtSpecifiedRate:
                    self.state = .loading
                case .paused:
                    if player.currentItem?.status == .failed {
                        self.state = .failed(.streamUnavailable)
                    }
                @unknown default:
                    self.state = .failed(.streamUnavailable)
                }
            }
        }
    }
}
