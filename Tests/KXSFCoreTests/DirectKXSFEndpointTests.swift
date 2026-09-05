import XCTest
@testable import KXSFCore

final class DirectKXSFEndpointTests: XCTestCase {
    func test_direct_endpoint_uses_the_verified_kxsf_stream() {
        XCTAssertEqual(
            DirectKXSFEndpoint().liveStreamURL.absoluteString,
            "http://stream.kxsf.fm:8000/sfcr"
        )
    }
}
