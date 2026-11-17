import SwiftUI
import KXSFCore

private let stationYellow = Color(red: 0.95, green: 0.77, blue: 0.10)
private let stationRed = Color(red: 0.71, green: 0.11, blue: 0.14)

extension EnvironmentValues {
    /// Space reserved under page content for the iPhone custom tab bar.
    /// iPad's native TabView manages its own insets, so it sets a small value.
    @Entry var stationBottomClearance: CGFloat = 112
}

/// iPhone: the Shows schedule (pass no player).
/// iPad: the unified Listen destination — the same schedule, with the live
/// play/pause control on the current-show card (pass the shared player).
struct ShowsView: View {
    @ObservedObject var liveShow: LiveShowStore
    var player: AudioPlayerService?
    @State private var expandedDay: KXSFWeekday?

    init(liveShow: LiveShowStore, player: AudioPlayerService? = nil) {
        self.liveShow = liveShow
        self.player = player
    }

    var body: some View {
        StationPage(
            title: player == nil ? "Shows" : "Listen",
            eyebrow: player == nil ? "WEEKLY KXSF SCHEDULE" : "LIVE RADIO & WEEKLY SCHEDULE"
        ) {
            if let player {
                UnifiedListenCard(player: player, liveShow: liveShow)
            }
            scheduleSurface
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("schedule-shows-content")

            Link(destination: URL(string: "https://kxsf.fm/shows/")!) {
                StationLinkLabel(title: "Browse the complete show archive", symbol: "arrow.up.right.square")
            }
        }
        .task {
            await liveShow.refresh()
            if expandedDay == nil { expandedDay = listenerWeekday }
        }
    }

    /// Station (Pacific) weekday, so the expanded day matches the schedule's own clock.
    private var listenerWeekday: KXSFWeekday { KXSFStationClock.weekday(of: .now) }

    /// Up Next is computed from station time, never from list order, so a show that has
    /// already aired (or is on air) can't appear here. Re-evaluated every 30 seconds.
    private var upNextSection: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            VStack(alignment: .leading, spacing: 10) {
                Text("UP NEXT")
                    .font(.caption.weight(.bold))
                    .tracking(1.1)
                    .foregroundStyle(.white.opacity(0.62))
                    .accessibilityAddTraits(.isHeader)
                switch KXSFUpNext.calculate(in: liveShow.schedule, at: context.date) {
                case .next(let occurrence):
                    UpNextRow(occurrence: occurrence)
                case .unavailable:
                    Text("Up Next is unavailable right now. Browse the full schedule below.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.68))
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
                        .accessibilityIdentifier("up-next-unavailable")
                }
            }
        }
    }

    @ViewBuilder
    private var scheduleSurface: some View {
        if liveShow.isLoading && liveShow.schedule.shows.isEmpty {
            StationCard(title: "Loading the schedule", detail: "Getting the latest programming directly from KXSF.", symbol: "dot.radiowaves.left.and.right")
        } else if liveShow.schedule.shows.isEmpty {
            StationCard(
                title: "Official schedule unavailable",
                detail: "KXSF’s schedule could not be loaded right now. The complete show archive is still available below.",
                symbol: "wifi.exclamationmark"
            )
        } else {
            VStack(alignment: .leading, spacing: 16) {
                // On iPad the current show lives in the unified Listen card.
                if player == nil, let currentShow = liveShow.currentShow {
                    ShowRow(show: currentShow, emphasis: true)
                }

                upNextSection

                Text("FULL SCHEDULE")
                    .font(.caption.weight(.bold))
                    .tracking(1.1)
                    .foregroundStyle(.white.opacity(0.62))

                ForEach(liveShow.schedule.sections(startingWith: listenerWeekday)) { section in
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedDay == section.day },
                            set: { isExpanded in expandedDay = isExpanded ? section.day : nil }
                        )
                    ) {
                        VStack(spacing: 10) {
                            ForEach(section.shows) { show in
                                ScheduleRow(show: show)
                            }
                        }
                        .padding(.top, 10)
                    } label: {
                        Text(section.day.rawValue.uppercased())
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                    .tint(stationYellow)
                    .padding(14)
                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
                }
            }
        }
    }
}

struct KXSFLiveView: View {
    @ObservedObject var liveShow: LiveShowStore

    var body: some View {
        StationPage(title: "KXSF Video", eyebrow: "WATCH PERFORMANCES FROM THE STATION") {
            if liveShow.isLoadingUploads && liveShow.uploads.isEmpty {
                StationCard(title: "Loading KXSF Video", detail: "Getting the latest official uploads from KXSF’s YouTube channel.", symbol: "play.tv")
            } else if liveShow.uploads.isEmpty {
                StationCard(title: "KXSF Video is unavailable", detail: "The latest uploads could not be loaded right now. Open the official channel below.", symbol: "wifi.exclamationmark")
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(liveShow.uploads) { upload in
                        Link(destination: upload.watchURL) {
                            HStack(spacing: 14) {
                                YouTubeThumbnail(upload: upload)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(upload.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .lineLimit(3)
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(10)
                            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
                        }
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("kxsf-live-content")
            }

            Link(destination: URL(string: "https://youtube.com/@kxsfradio")!) {
                StationLinkLabel(title: "Open KXSF on YouTube", symbol: "play.rectangle")
            }
        }
        .task { await liveShow.refreshUploads() }
    }
}

private struct YouTubeThumbnail: View {
    let upload: KXSFYouTubeUpload

    var body: some View {
        Group {
            if let url = upload.thumbnailURL {
                AsyncImage(url: url) { phase in
                    if case let .success(image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: 108, height: 62)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityHidden(true)
    }

    private var fallback: some View {
        ZStack {
            Color(red: 0.71, green: 0.11, blue: 0.14)
            Image(systemName: "play.fill").foregroundStyle(.white)
        }
    }
}

struct AboutKXSFView: View {
    private let socialLinks: [(title: String, url: URL, symbol: String, tint: Color)] = [
        (
            "Instagram",
            URL(string: "https://www.instagram.com/kxsfradio/")!,
            "camera.fill",
            Color(red: 0.91, green: 0.25, blue: 0.53)
        ),
        (
            "Facebook",
            URL(string: "https://www.facebook.com/kxsfradio/")!,
            "f.circle.fill",
            Color(red: 0.23, green: 0.35, blue: 0.60)
        ),
        (
            "X",
            URL(string: "https://x.com/kxsfradio/")!,
            "x.circle.fill",
            Color.white
        ),
        (
            "YouTube",
            URL(string: "https://www.youtube.com/@kxsfradio")!,
            "play.rectangle.fill",
            Color(red: 0.90, green: 0.13, blue: 0.15)
        ),
    ]

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Width of the page content column, measured so layout follows the window,
    /// not the device. Starts narrow (stacked) until the first measurement.
    @State private var contentWidth: Double = 0

    var body: some View {
        StationPage(title: "About KXSF", eyebrow: "SAN FRANCISCO COMMUNITY RADIO") {
            StationCard(
                title: "Broadcasting diverse voices",
                detail: "KXSF 102.5 FM is a San Francisco Community Radio project: an all-volunteer, IRS-recognized 501(c)(3) nonprofit supporting creative, socially aware, and community-led programming.",
                symbol: "building.2"
            )
            .onGeometryChange(for: Double.self) { Double($0.size.width) } action: { contentWidth = $0 }
            // One element for the whole card, so the identifier resolves to the card's frame
            // and not to its leading icon.
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("about-intro-card")

            // Side by side when both labels read comfortably; stacked when narrow or at
            // accessibility text sizes. Same destinations either way.
            let visit = Link(destination: URL(string: "https://kxsf.fm/")!) {
                StationLinkLabel(title: "Visit KXSF.FM", symbol: "globe")
            }
            .accessibilityIdentifier("about-visit-link")
            let support = Link(destination: URL(string: "https://kxsf.fm/support/")!) {
                StationLinkLabel(title: "Support KXSF", symbol: "heart.fill", accent: stationRed)
            }
            .accessibilityIdentifier("about-support-link")

            Group {
                if StationLayout.aboutActionsSideBySide(
                    availableWidth: contentWidth,
                    accessibilityText: dynamicTypeSize.isAccessibilitySize
                ) {
                    HStack(spacing: 12) { visit; support }
                } else {
                    VStack(spacing: 12) { visit; support }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("about-actions")

            VStack(alignment: .leading, spacing: 12) {
                Text("FOLLOW KXSF")
                    .font(.caption.weight(.bold))
                    .tracking(1.1)
                    .foregroundStyle(stationYellow)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(socialLinks, id: \.title) { social in
                        Link(destination: social.url) {
                            SocialLinkButton(title: social.title, symbol: social.symbol, tint: social.tint)
                        }
                        .accessibilityLabel("Open KXSF on \(social.title)")
                    }
                }
            }
            .padding(.top, 4)
        }
    }
}

private struct SocialLinkButton: View {
    let title: String
    let symbol: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
    }
}

private struct ShowRow: View {
    let show: KXSFShow
    var emphasis = false

    var body: some View {
        Link(destination: show.detailURL) {
            HStack(spacing: 14) {
                ShowArtwork(show: show, size: emphasis ? 76 : 58)
                VStack(alignment: .leading, spacing: 4) {
                    if emphasis {
                        Text("ON AIR NOW")
                            .font(.caption2.weight(.bold))
                            .tracking(1.1)
                            .foregroundStyle(stationYellow)
                    }
                    Text(show.name)
                        .font(emphasis ? .headline.weight(.bold) : .subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let hostName = show.hostName {
                        Text("with \(hostName)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.66))
                    }
                    if emphasis {
                        Text(show.timeRange)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(stationYellow)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(stationYellow)
            }
            .padding(emphasis ? 14 : 10)
            .background(.white.opacity(emphasis ? 0.11 : 0.06), in: RoundedRectangle(cornerRadius: 20))
            .overlay { RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.12), lineWidth: 1) }
        }
        .accessibilityLabel("\(emphasis ? "On air now, " : "")\(show.name), \(show.hostName.map { "with \($0), " } ?? "")\(show.timeRange)")
        .accessibilityIdentifier(emphasis ? "on-air-now-card" : "show-row")
    }
}

private struct UpNextRow: View {
    let occurrence: KXSFShowOccurrence

    var body: some View {
        let show = occurrence.show
        Link(destination: show.detailURL) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(show.day.rawValue.uppercased()) · \(show.timeRange)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(stationYellow)
                    Text(show.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let hostName = show.hostName {
                        Text("with \(hostName)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.66))
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.48))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 18))
            .overlay { RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.14), lineWidth: 1) }
        }
        .accessibilityLabel("Up next: \(show.name), \(show.day.rawValue), \(show.timeRange), Pacific time")
        .accessibilityIdentifier("up-next-card")
    }
}

private struct ScheduleRow: View {
    let show: KXSFShow

    var body: some View {
        Link(destination: show.detailURL) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(show.timeRange)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(stationYellow)
                    Text(show.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let hostName = show.hostName {
                        Text("with \(hostName)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.66))
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.48))
            }
            .padding(14)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
            .overlay { RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.11), lineWidth: 1) }
        }
        .accessibilityLabel("\(show.name), \(show.day.rawValue), \(show.timeRange)")
    }
}

/// iPad Listen: the current show card with the live play/pause control on it.
/// When schedule data is absent (loading, offline, or between listed shows) the
/// card falls back to the station identity so Play is always visible. State text
/// comes straight from the shared player, so loading/playing/error stay truthful.
private struct UnifiedListenCard: View {
    @ObservedObject var player: AudioPlayerService
    @ObservedObject var liveShow: LiveShowStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Measured width of this card (the same column width as the schedule cards).
    @State private var cardWidth: Double = 0

    private var presentation: PlaybackPresentation { PlaybackPresentation(state: player.state) }

    private var isStacked: Bool {
        StationLayout.stacksListenCard(
            availableWidth: cardWidth,
            accessibilityText: dynamicTypeSize.isAccessibilitySize
        )
    }

    var body: some View {
        VStack(spacing: 12) {
            // Compact: play centred on top, current show beneath at full card width.
            // Wide: show identity on the left, play on the right.
            if isStacked {
                VStack(spacing: 16) {
                    playButton
                    identity.frame(maxWidth: .infinity, alignment: .leading)
                }
                // .contain makes the stack its own element so the identifier is not
                // pushed down onto (and overwriting) the play button and show link.
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("listen-layout-compact")
            } else {
                HStack(spacing: 16) {
                    identity.frame(maxWidth: .infinity, alignment: .leading)
                    playButton
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("listen-layout-wide")
            }
            // No persistent status line. Written text appears only when something is wrong.
            if let message = presentation.errorMessage {
                errorRow(message)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .overlay { RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.14), lineWidth: 1) }
        .onGeometryChange(for: Double.self) { Double($0.size.width) } action: { cardWidth = $0 }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("playback-status-card")
    }

    private func errorRow(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(stationYellow)
                .accessibilityHidden(true)
            Text(message)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("playback-error")
            Button("Try again", action: player.togglePlayback)
                .font(.footnote.weight(.bold))
                .buttonStyle(.bordered)
                .tint(stationYellow)
                .accessibilityIdentifier("playback-retry")
        }
    }

    @ViewBuilder
    private var identity: some View {
        if let show = liveShow.currentShow {
            Link(destination: show.detailURL) {
                HStack(spacing: 14) {
                    ShowArtwork(show: show, size: 84)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ON AIR NOW")
                            .font(.caption2.weight(.bold))
                            .tracking(1.1)
                            .foregroundStyle(stationYellow)
                        Text(show.name)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                        if let hostName = show.hostName {
                            Text("with \(hostName)")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.72))
                        }
                        Text(show.timeRange)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(stationYellow)
                    }
                }
                // A Link's accessibility frame and hit region are its label's own bounds, not an
                // outer frame, so fill the width inside the label and keep the whole area tappable.
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("On air now, \(show.name), \(show.hostName.map { "with \($0), " } ?? "")\(show.timeRange)")
            .accessibilityIdentifier("on-air-now-card")
        } else {
            HStack(spacing: 14) {
                Image("KXSFLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 84, height: 84)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("SAN FRANCISCO")
                        .font(.caption2.weight(.bold))
                        .tracking(1.1)
                        .foregroundStyle(stationYellow)
                    Text("KXSF 102.5 FM")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                    Text("Community Radio")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("KXSF 102.5 FM, San Francisco Community Radio")
            .accessibilityIdentifier("station-identity-card")
        }
    }

    private var playButton: some View {
        Button(action: player.togglePlayback) {
            Group {
                switch presentation.control {
                case .loading:
                    ProgressView().controlSize(.large)
                case .pause:
                    Image(systemName: "pause.fill").font(.system(size: 30, weight: .bold))
                case .play:
                    Image(systemName: "play.fill").font(.system(size: 30, weight: .bold))
                }
            }
            .frame(width: 80, height: 80)
            .background(.ultraThinMaterial, in: Circle())
            .overlay { Circle().stroke(.white.opacity(0.18), lineWidth: 1) }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .tint(presentation.control == .pause ? KXSFColors.signalRed : KXSFColors.signalYellow)
        .foregroundStyle(presentation.control == .pause ? KXSFColors.signalRed : KXSFColors.signalYellow)
        .accessibilityIdentifier("playback-control")
        .accessibilityLabel(presentation.accessibilityLabel)
        .accessibilityValue(presentation.accessibilityValue)
    }
}

private struct StationPage<Content: View>: View {
    let title: String
    let eyebrow: String?
    @ViewBuilder let content: Content
    @Environment(\.stationBottomClearance) private var bottomClearance

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let eyebrow {
                    Text(eyebrow)
                        .font(.caption.weight(.bold))
                        .tracking(1.15)
                        .foregroundStyle(stationYellow)
                }
                Text(title)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)
                content
                Spacer(minLength: bottomClearance)
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .padding(.bottom, 24)
        }
    }
}

private struct StationCard: View {
    let title: String
    let detail: String
    let symbol: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol)
                .font(.title2.weight(.semibold))
                .foregroundStyle(stationYellow)
                .frame(width: 36, height: 36)
                .background(.white.opacity(0.08), in: Circle())
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.headline).foregroundStyle(.white)
                Text(detail).font(.subheadline).foregroundStyle(.white.opacity(0.68))
            }
        }
        .padding(20)
        // Same width as every other card and link in the column.
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .overlay { RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.14), lineWidth: 1) }
    }
}

private struct StationLinkLabel: View {
    let title: String
    let symbol: String
    var accent: Color = stationYellow

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).frame(width: 24)
            Text(title).font(.headline)
            Spacer()
            Image(systemName: "chevron.right").font(.caption.weight(.bold))
        }
        .foregroundStyle(accent)
        .frame(maxWidth: .infinity, minHeight: 52)
        .padding(.horizontal, 16)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.12), lineWidth: 1) }
    }
}
