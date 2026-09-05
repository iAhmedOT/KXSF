import Foundation
import XCTest
@testable import KXSFCore

final class KXSFArtworkFileCacheTests: XCTestCase {
    func test_accepts_square_or_near_square_artwork_for_compact_extensions() {
        // Policy remains available for callers that still want a pure suitability check.
        XCTAssertTrue(KXSFArtworkPolicy.isSuitableForCompactPresentation(width: 1200, height: 1200))
        XCTAssertTrue(KXSFArtworkPolicy.isSuitableForCompactPresentation(width: 1200, height: 1180))
        XCTAssertFalse(KXSFArtworkPolicy.isSuitableForCompactPresentation(width: 1200, height: 675))
        XCTAssertFalse(KXSFArtworkPolicy.isSuitableForCompactPresentation(width: 0, height: 1200))
    }

    func test_loads_only_artwork_matching_the_requested_revision() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = KXSFArtworkFileCache(directoryURL: directory)
        let imageBytes = Data([0x89, 0x50, 0x4E, 0x47])
        let revision = "https://kxsf.fm/current-show.jpg"

        try cache.store(imageBytes, revision: revision)

        XCTAssertEqual(cache.data(matching: revision), imageBytes)
        XCTAssertNil(cache.data(matching: "https://kxsf.fm/previous-show.jpg"))
    }
}
