import ActivityKit
import KXSFCore
import OSLog

actor KXSFLiveActivityManager {
    static let shared = KXSFLiveActivityManager()

    private struct DesiredState: Equatable, Sendable {
        let content: KXSFLiveActivityAttributes.ContentState
        let isPlaying: Bool
    }

    private let logger = Logger(subsystem: "com.KXSF.fm", category: "LiveActivity")
    private var desiredState: DesiredState?
    private var worker: Task<Void, Never>?

    func synchronize(show: KXSFShow?, isPlaying: Bool, artworkRevision: String?) {
        desiredState = DesiredState(
            content: KXSFLiveActivityAttributes.ContentState(
                showTitle: show?.name ?? "Live on KXSF",
                hostName: show?.hostName,
                timeRange: show?.timeRange,
                artworkRevision: artworkRevision,
                isPlaying: isPlaying
            ),
            isPlaying: isPlaying
        )

        guard worker == nil else { return }
        worker = Task { await drainDesiredStates() }
    }

    private func drainDesiredStates() async {
        while let state = desiredState {
            desiredState = nil
            await apply(state)
        }
        worker = nil
    }

    private func apply(_ desired: DesiredState) async {
        let content = ActivityContent(state: desired.content, staleDate: nil)
        let activities = Activity<KXSFLiveActivityAttributes>.activities

        if desired.isPlaying {
            guard ActivityAuthorizationInfo().areActivitiesEnabled else {
                logger.info("Live Activities are disabled")
                return
            }

            if let activity = activities.first {
                await activity.update(content)
                for duplicate in activities.dropFirst() {
                    await duplicate.end(content, dismissalPolicy: .immediate)
                }
            } else {
                do {
                    _ = try Activity.request(
                        attributes: KXSFLiveActivityAttributes(stationName: "KXSF 102.5 FM"),
                        content: content,
                        pushType: nil
                    )
                } catch {
                    logger.error("Unable to start Live Activity: \(error.localizedDescription, privacy: .public)")
                }
            }
        } else {
            for activity in activities {
                await activity.end(content, dismissalPolicy: .immediate)
            }
        }
    }
}
