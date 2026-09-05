import XCTest
@testable import KXSFCore

final class KXSFLiveShowParserTests: XCTestCase {
    func test_extracts_the_show_after_the_now_playing_marker() {
        let html = """
        <section>
          <h5>Now playing</h5>
          <h3><a href="https://kxsf.fm/shows/moon-wax-radio/">Moon Wax Radio</a></h3>
        </section>
        """

        XCTAssertEqual(KXSFLiveShowParser.showName(in: html), "Moon Wax Radio")
    }

    func test_returns_nil_when_no_now_playing_marker_exists() {
        XCTAssertNil(KXSFLiveShowParser.showName(in: "<h3>Archive</h3>"))
    }
}
