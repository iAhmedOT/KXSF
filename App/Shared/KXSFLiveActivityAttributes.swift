import ActivityKit

struct KXSFLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var showTitle: String
        var hostName: String?
        var timeRange: String?
        var artworkRevision: String?
        var isPlaying: Bool
    }

    var stationName: String
}
