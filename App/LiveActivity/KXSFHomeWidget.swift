import AppIntents
import SwiftUI
import WidgetKit
import KXSFCore

struct KXSFHomeEntry: TimelineEntry {
    let date: Date
    let showTitle: String
    let timeRange: String?
    let artworkURL: URL?
    let isPlaying: Bool
}

struct KXSFHomeWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "KXSF Now Playing"
    static let description = IntentDescription("Show KXSF's current program and control the live stream.")
}

struct KXSFHomeWidget: Widget {
    let kind = KXSFConstants.homeWidgetKind

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: KXSFHomeWidgetIntent.self, provider: KXSFHomeTimelineProvider()) { entry in
            KXSFHomeWidgetView(entry: entry)
        }
        .configurationDisplayName("KXSF Now Playing")
        .description("See the current KXSF show and control the live stream.")
        .supportedFamilies([.systemSmall, .systemMedium])
        // Own the inset so small/medium padding stays intentional and consistent.
        .contentMarginsDisabled()
    }
}

private struct KXSFHomeTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> KXSFHomeEntry {
        KXSFHomeEntry(date: .now, showTitle: "KXSF live radio", timeRange: nil, artworkURL: nil, isPlaying: KXSFPlaybackSnapshot.isPlaying)
    }

    func snapshot(for configuration: KXSFHomeWidgetIntent, in context: Context) async -> KXSFHomeEntry {
        await currentEntry()
    }

    func timeline(for configuration: KXSFHomeWidgetIntent, in context: Context) async -> Timeline<KXSFHomeEntry> {
        let entry = await currentEntry()
        let refresh = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now.addingTimeInterval(900)
        return Timeline(entries: [entry], policy: .after(refresh))
    }

    private func currentEntry() async -> KXSFHomeEntry {
        KXSFHomeEntry(
            date: .now,
            showTitle: KXSFPlaybackSnapshot.showTitle ?? "KXSF live radio",
            timeRange: KXSFPlaybackSnapshot.timeRange,
            artworkURL: KXSFPlaybackSnapshot.artworkURL,
            isPlaying: KXSFPlaybackSnapshot.isPlaying
        )
    }
}

private struct KXSFHomeWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: KXSFHomeEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                smallLayout
            default:
                mediumLayout
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [.black, Color(red: 0.13, green: 0.025, blue: 0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var mediumLayout: some View {
        HStack(alignment: .center, spacing: 14) {
            WidgetArtwork(revision: entry.artworkURL?.absoluteString, size: 68)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.isPlaying ? "NOW PLAYING" : "KXSF 102.5 FM")
                    .font(.caption2.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(KXSFColors.mediaOrange)
                    .lineLimit(1)

                Text(entry.showTitle)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .fixedSize(horizontal: false, vertical: true)

                if let timeRange = entry.timeRange {
                    Text(timeRange)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.70))
                        .lineLimit(1)
                        .minimumScaleFactor(0.88)
                        .padding(.top, 1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            playbackButton(size: 42)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .accessibilityElement(children: .contain)
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                WidgetArtwork(revision: entry.artworkURL?.absoluteString, size: 42)
                Spacer(minLength: 0)
                playbackButton(size: 34)
            }

            Spacer(minLength: 10)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.isPlaying ? "NOW PLAYING" : "KXSF 102.5 FM")
                    .font(.caption2.weight(.bold))
                    .tracking(0.7)
                    .foregroundStyle(KXSFColors.mediaOrange)
                    .lineLimit(1)

                Text(entry.showTitle)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(entry.timeRange == nil ? 3 : 2)
                    .minimumScaleFactor(0.82)
                    .fixedSize(horizontal: false, vertical: true)

                if let timeRange = entry.timeRange {
                    Text(timeRange)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.70))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .padding(.top, 1)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 11)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
    }

    private func playbackButton(size: CGFloat) -> some View {
        Button(intent: ToggleKXSFPlaybackIntent()) {
            Image(systemName: entry.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: size * 0.38, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(KXSFColors.signalRed, in: Circle())
                .overlay { Circle().stroke(.white.opacity(0.16), lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(entry.isPlaying ? "Pause KXSF live stream" : "Play KXSF live stream")
    }
}

private struct WidgetArtwork: View {
    let revision: String?
    let size: CGFloat

    var body: some View {
        LiveArtwork(revision: revision, size: size)
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .stroke(.white.opacity(0.14), lineWidth: 1)
            }
            .accessibilityHidden(true)
    }
}
