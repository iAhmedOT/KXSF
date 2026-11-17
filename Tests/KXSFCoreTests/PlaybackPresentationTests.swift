import XCTest
@testable import KXSFCore

final class PlaybackPresentationTests: XCTestCase {
    func test_idle_shows_play_with_no_error() {
        let p = PlaybackPresentation(state: .idle)
        XCTAssertEqual(p.control, .play)
        XCTAssertFalse(p.showsError)
        XCTAssertEqual(p.accessibilityLabel, "Play KXSF live stream")
        XCTAssertEqual(p.accessibilityValue, "Stopped")
        XCTAssertNil(p.errorMessage)
    }

    func test_loading_shows_spinner_and_cancel_label() {
        let p = PlaybackPresentation(state: .loading)
        XCTAssertEqual(p.control, .loading)
        XCTAssertFalse(p.showsError)
        XCTAssertEqual(p.accessibilityLabel, "Cancel connection to KXSF")
        XCTAssertEqual(p.accessibilityValue, "Connecting")
    }

    func test_pause_appears_only_for_confirmed_playback() {
        XCTAssertEqual(PlaybackPresentation(state: .playing).control, .pause)
        for state in [PlaybackState.idle, .loading, .failed(.streamUnavailable)] {
            XCTAssertNotEqual(PlaybackPresentation(state: state).control, .pause)
        }
        XCTAssertEqual(PlaybackPresentation(state: .playing).accessibilityLabel, "Pause KXSF live stream")
        XCTAssertEqual(PlaybackPresentation(state: .playing).accessibilityValue, "Playing")
    }

    func test_failure_offers_retry_without_claiming_playback() {
        let p = PlaybackPresentation(state: .failed(.streamUnavailable))
        XCTAssertEqual(p.control, .play)
        XCTAssertTrue(p.showsError)
        XCTAssertEqual(p.accessibilityLabel, "Retry KXSF live stream")
        XCTAssertEqual(p.accessibilityValue, "Stream unavailable")
        XCTAssertEqual(p.errorMessage, "Stream unavailable. Try again.")
    }

    func test_non_failure_states_have_no_error_message() {
        for state in [PlaybackState.idle, .loading, .playing] {
            XCTAssertNil(PlaybackPresentation(state: state).errorMessage)
        }
    }

    func test_every_state_has_a_distinct_accessibility_value() {
        let values = [PlaybackState.idle, .loading, .playing, .failed(.streamUnavailable)]
            .map { PlaybackPresentation(state: $0).accessibilityValue }
        XCTAssertEqual(Set(values).count, 4)
    }
}
