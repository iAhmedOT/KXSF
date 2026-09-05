import ActivityKit
import SwiftUI
import WidgetKit

@main
struct KXSFLiveActivities: WidgetBundle {
    var body: some Widget {
        KXSFNowPlayingLiveActivity()
        KXSFHomeWidget()
    }
}

private struct KXSFNowPlayingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: KXSFLiveActivityAttributes.self) { context in
            HStack(spacing: 14) {
                LiveArtwork(revision: context.state.artworkRevision, size: 60)
                    .fixedSize()

                VStack(alignment: .leading, spacing: 3) {
                    Text("NOW PLAYING")
                        .font(.caption2.weight(.bold))
                        .tracking(1.1)
                        .foregroundStyle(KXSFColors.mediaOrange)
                    Text(context.state.showTitle)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    activityMetadata(context: context)
                }

                Spacer(minLength: 0)
                playbackButton(context: context, size: 46)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .activityBackgroundTint(.black)
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    LiveArtwork(revision: context.state.artworkRevision, size: 46)
                        .fixedSize()
                        .frame(maxHeight: .infinity, alignment: .center)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("NOW PLAYING")
                            .font(.caption2.weight(.bold))
                            .tracking(0.8)
                            .foregroundStyle(KXSFColors.mediaOrange)
                        Text(context.state.showTitle)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        activityMetadata(context: context)
                            .font(.caption2)
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    playbackButton(context: context, size: 38)
                        .frame(maxHeight: .infinity, alignment: .center)
                }
            } compactLeading: {
                // Pre-baked circular bitmap — SwiftUI clipShape is unreliable in compact DI.
                LiveArtwork(
                    revision: context.state.artworkRevision,
                    size: 24,
                    style: .compactIsland
                )
            } compactTrailing: {
                Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(KXSFColors.mediaOrange)
                    .frame(minWidth: 16, minHeight: 16)
            } minimal: {
                LiveArtwork(
                    revision: context.state.artworkRevision,
                    size: 22,
                    style: .compactIsland
                )
            }
            .widgetURL(KXSFConstants.listenDeepLink)
            .keylineTint(KXSFColors.mediaOrange)
        }
    }

    @ViewBuilder
    private func activityMetadata(
        context: ActivityViewContext<KXSFLiveActivityAttributes>
    ) -> some View {
        HStack(spacing: 5) {
            if let hostName = context.state.hostName {
                Text("with \(hostName)")
            }
            if context.state.hostName != nil, context.state.timeRange != nil {
                Text("•")
            }
            if let timeRange = context.state.timeRange {
                Text(timeRange)
            }
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.white.opacity(0.70))
        .lineLimit(1)
    }

    private func playbackButton(
        context: ActivityViewContext<KXSFLiveActivityAttributes>,
        size: CGFloat
    ) -> some View {
        Button(intent: ToggleKXSFPlaybackIntent()) {
            Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: size * 0.40, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(KXSFColors.signalRed, in: Circle())
                .overlay { Circle().stroke(.white.opacity(0.16), lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(context.state.isPlaying ? "Pause KXSF live stream" : "Play KXSF live stream")
    }
}
