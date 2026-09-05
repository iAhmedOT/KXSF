import AppIntents

// This target-visible declaration allows the Live Activity UI to construct the
// intent. Because it adopts AudioPlaybackIntent, WidgetKit runs the matching
// app-target implementation in KXSF's process where AVPlayer lives.
struct ToggleKXSFPlaybackIntent: AudioPlaybackIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Play or pause KXSF"
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        .result()
    }
}
