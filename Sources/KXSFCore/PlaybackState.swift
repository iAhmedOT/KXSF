/// What the play control and its accessibility description show for a player state.
/// No persistent written status: idle is play, loading is a spinner, and pause is shown
/// only once the player confirms playback (`.playing`). An error is visible only on failure.
public struct PlaybackPresentation: Equatable, Sendable {
    public enum Control: Equatable, Sendable {
        case play, loading, pause
    }

    public let control: Control
    public let accessibilityLabel: String
    public let accessibilityValue: String
    public let errorMessage: String?

    public var showsError: Bool { errorMessage != nil }

    public init(state: PlaybackState) {
        switch state {
        case .idle:
            control = .play
            accessibilityLabel = "Play KXSF live stream"
            accessibilityValue = "Stopped"
            errorMessage = nil
        case .loading:
            control = .loading
            accessibilityLabel = "Cancel connection to KXSF"
            accessibilityValue = "Connecting"
            errorMessage = nil
        case .playing:
            control = .pause
            accessibilityLabel = "Pause KXSF live stream"
            accessibilityValue = "Playing"
            errorMessage = nil
        case .failed:
            control = .play
            accessibilityLabel = "Retry KXSF live stream"
            accessibilityValue = "Stream unavailable"
            errorMessage = "Stream unavailable. Try again."
        }
    }
}

public enum PlaybackEvent: Equatable, Sendable {
    case playRequested
}

public enum PlaybackFailure: Equatable, Sendable {
    case streamUnavailable
}

public enum PlaybackState: Equatable, Sendable {
    case idle
    case loading
    case playing
    case failed(PlaybackFailure)

    public var isPlaying: Bool {
        switch self {
        case .playing:
            true
        case .idle, .loading, .failed:
            false
        }
    }

    public func applying(_ event: PlaybackEvent) -> PlaybackState {
        switch (self, event) {
        case (.idle, .playRequested):
            .loading
        default:
            self
        }
    }
}
