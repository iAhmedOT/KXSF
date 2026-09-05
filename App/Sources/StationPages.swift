import SwiftUI
import KXSFCore

private let stationYellow = Color(red: 0.95, green: 0.77, blue: 0.10)
private let stationRed = Color(red: 0.71, green: 0.11, blue: 0.14)

struct ShowsView: View {
    @ObservedObject var liveShow: LiveShowStore
    @State private var expandedDay: KXSFWeekday?

    var body: some View {
        StationPage(title: "Shows", eyebrow: "WEEKLY KXSF SCHEDULE") {
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

    private var listenerWeekday: KXSFWeekday {
        switch Calendar.current.component(.weekday, from: .now) {
        case 1: .sunday
        case 2: .monday
        case 3: .tuesday
        case 4: .wednesday
        case 5: .thursday
        case 6: .friday
        default: .saturday
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
                if let currentShow = liveShow.currentShow {
                    ShowRow(show: currentShow, emphasis: true)
                }

                Text("UP NEXT")
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
        StationPage(title: "KXSF Live", eyebrow: "WATCH PERFORMANCES FROM THE STATION") {
            if liveShow.isLoadingUploads && liveShow.uploads.isEmpty {
                StationCard(title: "Loading KXSF Live", detail: "Getting the latest official uploads from KXSF’s YouTube channel.", symbol: "play.tv")
            } else if liveShow.uploads.isEmpty {
                StationCard(title: "KXSF Live is unavailable", detail: "The latest uploads could not be loaded right now. Open the official channel below.", symbol: "wifi.exclamationmark")
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

    var body: some View {
        StationPage(title: "About KXSF", eyebrow: "SAN FRANCISCO COMMUNITY RADIO") {
            StationCard(
                title: "Broadcasting diverse voices",
                detail: "KXSF 102.5 FM is a San Francisco Community Radio project: an all-volunteer, IRS-recognized 501(c)(3) nonprofit supporting creative, socially aware, and community-led programming.",
                symbol: "building.2"
            )

            Link(destination: URL(string: "https://kxsf.fm/")!) {
                StationLinkLabel(title: "Visit KXSF.FM", symbol: "globe")
            }

            Link(destination: URL(string: "https://kxsf.fm/support/")!) {
                StationLinkLabel(title: "Support KXSF", symbol: "heart.fill", accent: stationRed)
            }

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

private struct StationPage<Content: View>: View {
    let title: String
    let eyebrow: String?
    @ViewBuilder let content: Content

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
                Spacer(minLength: 112)
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
