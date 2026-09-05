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
