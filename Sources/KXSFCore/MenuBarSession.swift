import Observation

/// The platform player owns AVFoundation. UI state never owns its lifetime.
@MainActor
public protocol RadioTransport: AnyObject {
    var state: PlaybackState { get }
    func play()
    func pause()
}

public enum MenuBarTab: String, CaseIterable, Sendable {
    case listen = "Listen"
    case shows = "Shows"
    case about = "About"
}

@Observable @MainActor
public final class MenuBarSession {
    public var isPanelPresented = false
    public var selectedTab: MenuBarTab = .listen
    private let transport: any RadioTransport

    public init(transport: any RadioTransport) {
        self.transport = transport
    }

    public func togglePlayback() {
        switch transport.state {
        case .idle, .failed: transport.play()
        case .loading, .playing: transport.pause()
        }
    }
}
