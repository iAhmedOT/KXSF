import XCTest
@testable import KXSFCore

final class PlaybackStateTests: XCTestCase {
    func test_idle_state_is_not_playing() {
        XCTAssertFalse(PlaybackState.idle.isPlaying)
    }

    func test_loading_state_is_not_playing() {
        XCTAssertFalse(PlaybackState.loading.isPlaying)
    }

    func test_playing_state_is_playing() {
        XCTAssertTrue(PlaybackState.playing.isPlaying)
    }

    func test_play_request_from_idle_enters_loading() {
        XCTAssertEqual(
            PlaybackState.idle.applying(.playRequested),
            .loading
        )
    }

    func test_failed_state_is_not_playing() {
        XCTAssertFalse(PlaybackState.failed(.streamUnavailable).isPlaying)
    }
}
