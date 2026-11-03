import AVFoundation
import Combine
import KXSFCore

@MainActor
final class MacRadioPlayer: NSObject, ObservableObject, RadioTransport {
    @Published private(set) var state: PlaybackState = .idle
    private var player: AVPlayer?
    private var observation: NSKeyValueObservation?
    private var itemObservation: NSKeyValueObservation?

    func play() {
        guard player == nil else { return }
        state = .loading
        let item = AVPlayerItem(url: DirectKXSFEndpoint().liveStreamURL)
        let next = AVPlayer(playerItem: item)
        player = next
        observation = next.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] observed, _ in
            Task { @MainActor in
                guard let self, self.player === observed else { return }
                switch observed.timeControlStatus {
                case .playing: self.state = .playing
                case .waitingToPlayAtSpecifiedRate: self.state = .loading
                case .paused:
                    if observed.currentItem?.status == .failed { self.fail() }
                @unknown default: self.fail()
                }
            }
        }
        itemObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] observed, _ in
            Task { @MainActor in
                guard let self, self.player?.currentItem === observed else { return }
                if observed.status == .failed { self.fail() }
            }
        }
        next.play()
    }

    func pause() {
        observation?.invalidate()
        itemObservation?.invalidate()
        observation = nil
        itemObservation = nil
        player?.pause()
        player = nil
        state = .idle
    }

    private func fail() {
        pause()
        state = .failed(.streamUnavailable)
    }
}
