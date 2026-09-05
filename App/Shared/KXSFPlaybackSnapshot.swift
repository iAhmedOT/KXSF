import Foundation

/// Cross-process state shared by the app and WidgetKit extension. Values are
/// published only after the app receives confirmed player or schedule state.
enum KXSFPlaybackSnapshot {
    private enum Key {
        static let isPlaying = "isPlaying"
        static let showTitle = "showTitle"
        static let timeRange = "timeRange"
        static let artworkURL = "artworkURL"
    }

    static var isPlaying: Bool {
        defaults?.bool(forKey: Key.isPlaying) ?? false
    }

    static var showTitle: String? {
        defaults?.string(forKey: Key.showTitle)
    }

    static var timeRange: String? {
        defaults?.string(forKey: Key.timeRange)
    }

    static var artworkURL: URL? {
        defaults?.string(forKey: Key.artworkURL).flatMap(URL.init(string:))
    }

    @discardableResult
    static func setIsPlaying(_ isPlaying: Bool) -> Bool {
        guard let defaults, defaults.bool(forKey: Key.isPlaying) != isPlaying else {
            return false
        }
        defaults.set(isPlaying, forKey: Key.isPlaying)
        return true
    }

    @discardableResult
    static func setProgram(title: String?, timeRange: String?, artworkURL: URL?) -> Bool {
        guard let defaults else { return false }

        let artwork = artworkURL?.absoluteString
        let changed = defaults.string(forKey: Key.showTitle) != title
            || defaults.string(forKey: Key.timeRange) != timeRange
            || defaults.string(forKey: Key.artworkURL) != artwork
        guard changed else { return false }

        defaults.set(title, forKey: Key.showTitle)
        defaults.set(timeRange, forKey: Key.timeRange)
        defaults.set(artwork, forKey: Key.artworkURL)
        return true
    }

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: KXSFConstants.appGroup)
    }
}
