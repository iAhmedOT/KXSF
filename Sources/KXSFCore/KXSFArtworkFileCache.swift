import Foundation

public struct KXSFArtworkFileCache: Sendable {
    private let directoryURL: URL

    public init(directoryURL: URL) {
        self.directoryURL = directoryURL
    }

    public func store(_ data: Data, revision: String) throws {
        guard !data.isEmpty, !revision.isEmpty else { throw CacheError.invalidPayload }
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        try data.write(to: artworkURL, options: .atomic)
        try Data(revision.utf8).write(to: revisionURL, options: .atomic)
    }

    public func data(matching revision: String?) -> Data? {
        guard
            let revision,
            let storedRevisionData = try? Data(contentsOf: revisionURL),
            String(decoding: storedRevisionData, as: UTF8.self) == revision
        else { return nil }
        return try? Data(contentsOf: artworkURL)
    }

    private var artworkURL: URL {
        directoryURL.appendingPathComponent("current-show-artwork.data")
    }

    private var revisionURL: URL {
        directoryURL.appendingPathComponent("current-show-artwork.revision")
    }

    private enum CacheError: Error {
        case invalidPayload
    }
}
