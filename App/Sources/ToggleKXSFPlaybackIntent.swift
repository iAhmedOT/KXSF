import AppIntents

struct ToggleKXSFPlaybackIntent: AudioPlaybackIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Play or pause KXSF"
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            AudioPlayerService.shared.togglePlayback()
        }
        return .result()
    }
}
