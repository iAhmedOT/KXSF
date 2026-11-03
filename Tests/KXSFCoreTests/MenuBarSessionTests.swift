import Testing
@testable import KXSFCore

@MainActor
struct MenuBarSessionTests {
    @Test func closingPanelDoesNotPausePlayback() {
        let transport = RecordingTransport()
        let session = MenuBarSession(transport: transport)
        session.togglePlayback()
        session.isPanelPresented = true
        session.isPanelPresented = false
        #expect(transport.playCalls == 1)
        #expect(transport.pauseCalls == 0)
    }

    @Test func switchingTabsDoesNotRestartPlayback() {
        let transport = RecordingTransport()
        let session = MenuBarSession(transport: transport)
        session.togglePlayback()
        session.selectedTab = .shows
        session.selectedTab = .about
        session.selectedTab = .listen
        #expect(transport.playCalls == 1)
        #expect(transport.pauseCalls == 0)
    }

    @Test func secondPlaybackCommandCancelsConnection() {
        let transport = RecordingTransport()
        let session = MenuBarSession(transport: transport)
        session.togglePlayback()
        session.togglePlayback()
        #expect(transport.playCalls == 1)
        #expect(transport.pauseCalls == 1)
    }
}

@MainActor
private final class RecordingTransport: RadioTransport {
    var state: PlaybackState = .idle
    var playCalls = 0
    var pauseCalls = 0
    func play() { playCalls += 1; state = .loading }
    func pause() { pauseCalls += 1; state = .idle }
}
