import AppKit
import SwiftUI
import Combine
import KXSFCore

// MARK: - Lifecycle contract
//
// * The app is a regular (Dock + app menu) app: `LSUIElement` is NOT set in Info.plist.
// * `MacAppDelegate` owns the one `MacRadioPlayer`, `LiveShowStore`, and `MenuBarSession`.
//   Views only observe them, so showing, hiding, minimizing or closing the window never
//   creates, restarts, or stops playback.
// * The red close button closes the window only: `applicationShouldTerminateAfterLastWindowClosed`
//   is false, so the process, the status item, and playback keep running.
// * The yellow button minimizes to the Dock (standard window behaviour).
// * The status-item popover has "Open KXSF Window"; a Dock click does the same.
// * Quit is explicit: app menu / Cmd-Q, or "Quit KXSF" in the popover. Both terminate.

enum MacWindowID {
    static let main = "kxsf-main"
}

@main
struct KXSFMacApp: App {
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) private var delegate

    var body: some Scene {
        Window("KXSF", id: MacWindowID.main) {
            MacMainView(delegate: delegate)
        }
        .defaultSize(width: 980, height: 760)
        .windowResizability(.contentMinSize)
    }
}

@MainActor
final class MacAppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    // Lifetime is the app's, not the window's or the panel's.
    let player = MacRadioPlayer()
    let store = LiveShowStore()
    lazy var session = MenuBarSession(transport: player)
    private var titleItem: NSStatusItem!

    private let popover = NSPopover()
    private var subscriptions = Set<AnyCancellable>()

    /// Registered by the main window's view, which owns SwiftUI's `openWindow` action.
    var openMainWindowAction: (() -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        titleItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        titleItem.button?.target = self
        titleItem.button?.action = #selector(togglePanel)
        titleItem.button?.image = NSImage(named: "KXSFLogo")
        titleItem.button?.image?.size = NSSize(width: 19, height: 19)
        titleItem.button?.imagePosition = .imageLeading
        titleItem.button?.setAccessibilityLabel("KXSF: open player")

        popover.behavior = .transient
        popover.delegate = self
        popover.contentSize = NSSize(width: 380, height: 520)
        popover.contentViewController = NSHostingController(
            rootView: MacPlayerPanel(
                session: session,
                player: player,
                store: store,
                openWindow: { [weak self] in self?.showMainWindow() }
            )
        )
        store.$schedule.sink { [weak self] schedule in
            self?.updateStatus(show: schedule.currentShow)
        }.store(in: &subscriptions)
        Task { await store.refresh() }
    }

    private func updateStatus(show: KXSFShow?) {
        let name = show?.name ?? "KXSF 102.5 FM"
        titleItem.button?.title = " " + (name.count > 24 ? String(name.prefix(23)) + "…" : name)
        titleItem.button?.toolTip = name

    }

    /// Closing the last window must not quit: the menu-bar player keeps running.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    /// Dock click with no visible window (closed or minimized) brings the window back.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showMainWindow() }
        return true
    }

    func showMainWindow() {
        popover.performClose(nil)
        NSApp.activate()
        for window in NSApp.windows where window.isMiniaturized && window.canBecomeMain {
            window.deminiaturize(nil)
        }
        // For a single-instance `Window` scene this re-creates a closed window, or
        // fronts the existing one. It never touches the player.
        openMainWindowAction?()
    }

    @objc private func togglePanel() {
        if popover.isShown { popover.performClose(nil) }
        else if let button = titleItem.button {
            session.isPanelPresented = true
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
    func popoverDidClose(_ notification: Notification) { session.isPanelPresented = false }
    func applicationWillTerminate(_ notification: Notification) { player.pause() }
}

// MARK: - Main window (iPad-inspired: Listen unifies live player + schedule)

private enum MacDestination: String, CaseIterable, Identifiable {
    case listen = "Listen"
    case video = "KXSF Video"
    case about = "About"

    var id: Self { self }

    var icon: String {
        switch self {
        case .listen: "dot.radiowaves.left.and.right"
        case .video: "play.tv"
        case .about: "info.circle"
        }
    }
}

private enum MacPalette {
    static let yellow = Color(red: 0.95, green: 0.77, blue: 0.10)
    static let red = Color(red: 0.71, green: 0.11, blue: 0.14)
    static let canvas = Color(red: 0.05, green: 0.05, blue: 0.06)
}

struct MacMainView: View {
    let delegate: MacAppDelegate
    @ObservedObject private var player: MacRadioPlayer
    @ObservedObject private var store: LiveShowStore
    @State private var destination: MacDestination? = .listen
    @Environment(\.openWindow) private var openWindow

    init(delegate: MacAppDelegate) {
        self.delegate = delegate
        _player = ObservedObject(wrappedValue: delegate.player)
        _store = ObservedObject(wrappedValue: delegate.store)
    }

    var body: some View {
        NavigationSplitView {
            List(MacDestination.allCases, selection: $destination) { item in
                Label(item.rawValue, systemImage: item.icon)
                    .tag(item)
                    .accessibilityIdentifier("mac-sidebar-\(item.rawValue)")
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 240)
        } detail: {
            ZStack {
                MacPalette.canvas.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        switch destination ?? .listen {
                        case .listen: MacListenPage(delegate: delegate, player: player, store: store)
                        case .video: MacVideoPage(store: store)
                        case .about: MacAboutPage()
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 28)
                    .frame(maxWidth: 820, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(minWidth: 520, minHeight: 480)
        .preferredColorScheme(.dark)
        .tint(MacPalette.yellow)
        .task {
            delegate.openMainWindowAction = { openWindow(id: MacWindowID.main) }
            await store.refresh()
        }
    }
}

private struct MacPageHeader: View {
    let eyebrow: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(eyebrow)
                .font(.caption.weight(.bold))
                .tracking(1.15)
                .foregroundStyle(MacPalette.yellow)
            Text(title)
                .font(.largeTitle.weight(.bold))
                .accessibilityAddTraits(.isHeader)
        }
    }
}

// MARK: Listen

private struct MacListenPage: View {
    let delegate: MacAppDelegate
    @ObservedObject var player: MacRadioPlayer
    @ObservedObject var store: LiveShowStore
    @State private var expandedDay: KXSFWeekday?

    var body: some View {
        MacPageHeader(eyebrow: "LIVE RADIO & WEEKLY SCHEDULE", title: "Listen")
        MacListenCard(session: delegate.session, player: player, store: store)
        scheduleSurface
            .task {
                if expandedDay == nil { expandedDay = KXSFStationClock.weekday(of: .now) }
            }
        Link(destination: URL(string: "https://kxsf.fm/shows/")!) {
            MacLinkLabel(title: "Browse the complete show archive", symbol: "arrow.up.right.square")
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var scheduleSurface: some View {
        if store.isLoading && store.schedule.shows.isEmpty {
            MacInfoCard(title: "Loading the schedule", detail: "Getting the latest programming directly from KXSF.", symbol: "dot.radiowaves.left.and.right")
        } else if store.schedule.shows.isEmpty {
            MacInfoCard(
                title: "Official schedule unavailable",
                detail: "KXSF’s schedule could not be loaded right now. The complete show archive is still available below.",
                symbol: "wifi.exclamationmark"
            )
        } else {
            VStack(alignment: .leading, spacing: 16) {
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    VStack(alignment: .leading, spacing: 10) {
                        Text("UP NEXT")
                            .font(.caption.weight(.bold))
                            .tracking(1.1)
                            .foregroundStyle(.white.opacity(0.62))
                            .accessibilityAddTraits(.isHeader)
                        switch KXSFUpNext.calculate(in: store.schedule, at: context.date) {
                        case .next(let occurrence):
                            MacShowRow(show: occurrence.show, prefix: "\(occurrence.show.day.rawValue.uppercased()) · ")
                                .accessibilityLabel("Up next: \(occurrence.show.name), \(occurrence.show.day.rawValue), \(occurrence.show.timeRange), Pacific time")
                                .accessibilityIdentifier("up-next-card")
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

                Text("FULL SCHEDULE")
                    .font(.caption.weight(.bold))
                    .tracking(1.1)
                    .foregroundStyle(.white.opacity(0.62))

                ForEach(store.schedule.sections(startingWith: KXSFStationClock.weekday(of: .now))) { section in
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedDay == section.day },
                            set: { expandedDay = $0 ? section.day : nil }
                        )
                    ) {
                        VStack(spacing: 10) {
                            ForEach(section.shows) { show in
                                MacShowRow(show: show, prefix: "")
                                    .accessibilityLabel("\(show.name), \(show.day.rawValue), \(show.timeRange)")
                            }
                        }
                        .padding(.top, 10)
                    } label: {
                        Text(section.day.rawValue.uppercased()).font(.headline)
                    }
                    .padding(14)
                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("schedule-shows-content")
        }
    }
}

/// Current show + play control. Compact width: play centred on top, show beneath at full
/// width. Wide: show on the left, play on the right. No persistent status text; the control
/// is play (idle), a spinner (loading), pause (confirmed playing only), and an error row
/// with retry appears only on failure. Playback goes through the shared `MenuBarSession`.
private struct MacListenCard: View {
    let session: MenuBarSession
    @ObservedObject var player: MacRadioPlayer
    @ObservedObject var store: LiveShowStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var cardWidth: Double = 0

    private var presentation: PlaybackPresentation { PlaybackPresentation(state: player.state) }

    private var isStacked: Bool {
        StationLayout.stacksListenCard(availableWidth: cardWidth, accessibilityText: dynamicTypeSize.isAccessibilitySize)
    }

    var body: some View {
        VStack(spacing: 12) {
            if isStacked {
                VStack(spacing: 16) {
                    playButton
                    identity.frame(maxWidth: .infinity, alignment: .leading)
                }
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
            if let message = presentation.errorMessage {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(MacPalette.yellow)
                        .accessibilityHidden(true)
                    Text(message)
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("playback-error")
                    Button("Try again") { session.togglePlayback() }
                        .accessibilityIdentifier("playback-retry")
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 24))
        .overlay { RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.14), lineWidth: 1) }
        .onGeometryChange(for: Double.self) { Double($0.size.width) } action: { cardWidth = $0 }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("playback-status-card")
    }

    @ViewBuilder
    private var identity: some View {
        if let show = store.currentShow {
            Link(destination: show.detailURL) {
                HStack(spacing: 14) {
                    MacArtwork(url: show.artworkURL, size: 84)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ON AIR NOW")
                            .font(.caption2.weight(.bold))
                            .tracking(1.1)
                            .foregroundStyle(MacPalette.yellow)
                        Text(show.name)
                            .font(.title3.weight(.bold))
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                        if let host = show.hostName {
                            Text("with \(host)").font(.subheadline).foregroundStyle(.white.opacity(0.72))
                        }
                        Text(show.timeRange)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(MacPalette.yellow)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("On air now, \(show.name), \(show.hostName.map { "with \($0), " } ?? "")\(show.timeRange)")
            .accessibilityIdentifier("on-air-now-card")
        } else {
            HStack(spacing: 14) {
                Image("KXSFLogo").resizable().scaledToFit().frame(width: 84, height: 84)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("SAN FRANCISCO")
                        .font(.caption2.weight(.bold))
                        .tracking(1.1)
                        .foregroundStyle(MacPalette.yellow)
                    Text("KXSF 102.5 FM").font(.title3.weight(.bold))
                    Text("Community Radio").font(.subheadline).foregroundStyle(.white.opacity(0.72))
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("KXSF 102.5 FM, San Francisco Community Radio")
            .accessibilityIdentifier("station-identity-card")
        }
    }

    private var playButton: some View {
        Button { session.togglePlayback() } label: {
            Group {
                switch presentation.control {
                case .loading: ProgressView().controlSize(.regular)
                case .pause: Image(systemName: "pause.fill").font(.system(size: 30, weight: .bold))
                case .play: Image(systemName: "play.fill").font(.system(size: 30, weight: .bold))
                }
            }
            .frame(width: 80, height: 80)
            .background(.white.opacity(0.10), in: Circle())
            .overlay { Circle().stroke(.white.opacity(0.18), lineWidth: 1) }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(presentation.control == .pause ? MacPalette.red : MacPalette.yellow)
        .accessibilityIdentifier("playback-control")
        .accessibilityLabel(presentation.accessibilityLabel)
        .accessibilityValue(presentation.accessibilityValue)
    }
}

// MARK: Video

private struct MacVideoPage: View {
    @ObservedObject var store: LiveShowStore

    var body: some View {
        MacPageHeader(eyebrow: "WATCH PERFORMANCES FROM THE STATION", title: "KXSF Video")
            .task { await store.refreshUploads() }
        if store.isLoadingUploads && store.uploads.isEmpty {
            MacInfoCard(title: "Loading KXSF Video", detail: "Getting the latest official uploads from KXSF’s YouTube channel.", symbol: "play.tv")
        } else if store.uploads.isEmpty {
            MacInfoCard(title: "KXSF Video is unavailable", detail: "The latest uploads could not be loaded right now. Open the official channel below.", symbol: "wifi.exclamationmark")
        } else {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(store.uploads) { upload in
                    Link(destination: upload.watchURL) {
                        HStack(spacing: 14) {
                            AsyncImage(url: upload.thumbnailURL) { phase in
                                if case let .success(image) = phase {
                                    image.resizable().scaledToFill()
                                } else {
                                    ZStack { MacPalette.red; Image(systemName: "play.fill") }
                                }
                            }
                            .frame(width: 108, height: 62)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .accessibilityHidden(true)
                            Text(upload.title)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(3)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(10)
                        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
                    }
                    .buttonStyle(.plain)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("kxsf-live-content")
        }
        Link(destination: URL(string: "https://youtube.com/@kxsfradio")!) {
            MacLinkLabel(title: "Open KXSF on YouTube", symbol: "play.rectangle")
        }
        .buttonStyle(.plain)
    }
}

// MARK: About

private struct MacAboutPage: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var contentWidth: Double = 0

    private let socialLinks: [(title: String, url: URL, symbol: String)] = [
        ("Instagram", URL(string: "https://www.instagram.com/kxsfradio/")!, "camera.fill"),
        ("Facebook", URL(string: "https://www.facebook.com/kxsfradio/")!, "f.circle.fill"),
        ("X", URL(string: "https://x.com/kxsfradio/")!, "x.circle.fill"),
        ("YouTube", URL(string: "https://www.youtube.com/@kxsfradio")!, "play.rectangle.fill"),
    ]

    var body: some View {
        MacPageHeader(eyebrow: "SAN FRANCISCO COMMUNITY RADIO", title: "About KXSF")

        MacInfoCard(
            title: "Broadcasting diverse voices",
            detail: "KXSF 102.5 FM is a San Francisco Community Radio project: an all-volunteer, IRS-recognized 501(c)(3) nonprofit supporting creative, socially aware, and community-led programming.",
            symbol: "building.2"
        )
        .onGeometryChange(for: Double.self) { Double($0.size.width) } action: { contentWidth = $0 }
        .accessibilityIdentifier("about-intro-card")

        let visit = Link(destination: URL(string: "https://kxsf.fm/")!) {
            MacLinkLabel(title: "Visit KXSF.FM", symbol: "globe")
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("about-visit-link")
        let support = Link(destination: URL(string: "https://kxsf.fm/support/")!) {
            MacLinkLabel(title: "Support KXSF", symbol: "heart.fill", accent: MacPalette.red)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("about-support-link")

        Group {
            if StationLayout.aboutActionsSideBySide(availableWidth: contentWidth, accessibilityText: dynamicTypeSize.isAccessibilitySize) {
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
                .foregroundStyle(MacPalette.yellow)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(socialLinks, id: \.title) { social in
                    Link(destination: social.url) {
                        HStack(spacing: 10) {
                            Image(systemName: social.symbol).font(.title3.weight(.semibold)).frame(width: 28)
                            Text(social.title).font(.subheadline.weight(.semibold))
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 14)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
                        .overlay { RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.12), lineWidth: 1) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open KXSF on \(social.title)")
                }
            }
        }
    }
}

// MARK: Shared small views

private struct MacArtwork: View {
    let url: URL?
    let size: CGFloat

    var body: some View {
        AsyncImage(url: url) { phase in
            if case let .success(image) = phase {
                image.resizable().scaledToFill()
            } else {
                ZStack {
                    LinearGradient(colors: [MacPalette.red, Color(red: 0.12, green: 0.08, blue: 0.04)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: "music.note")
                        .font(.system(size: size * 0.34, weight: .bold))
                        .foregroundStyle(MacPalette.yellow)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        .accessibilityHidden(true)
    }
}

private struct MacShowRow: View {
    let show: KXSFShow
    let prefix: String

    var body: some View {
        Link(destination: show.detailURL) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(prefix)\(show.timeRange)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(MacPalette.yellow)
                    Text(show.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let host = show.hostName {
                        Text("with \(host)").font(.caption).foregroundStyle(.white.opacity(0.66))
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.white.opacity(0.48))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
            .overlay { RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.11), lineWidth: 1) }
        }
        .buttonStyle(.plain)
    }
}

private struct MacInfoCard: View {
    let title: String
    let detail: String
    let symbol: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol)
                .font(.title2.weight(.semibold))
                .foregroundStyle(MacPalette.yellow)
                .frame(width: 36, height: 36)
                .background(.white.opacity(0.08), in: Circle())
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.white.opacity(0.68))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 24))
        .overlay { RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.14), lineWidth: 1) }
    }
}

private struct MacLinkLabel: View {
    let title: String
    let symbol: String
    var accent: Color = MacPalette.yellow

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
        .contentShape(RoundedRectangle(cornerRadius: 18))
    }
}

// MARK: - Menu-bar popover (unchanged behaviour; adds "Open KXSF Window")

struct MacPlayerPanel: View {
    @Bindable var session: MenuBarSession
    @ObservedObject var player: MacRadioPlayer
    @ObservedObject var store: LiveShowStore
    var openWindow: () -> Void = {}

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("KXSF 102.5 FM").font(.headline)
                Spacer()
                Button { Task { await store.refresh() } } label: { Image(systemName: "arrow.clockwise") }
                    .help("Refresh official schedule")
            }
            Picker("Destination", selection: $session.selectedTab) {
                ForEach(MenuBarTab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented).labelsHidden()
            ScrollView {
                switch session.selectedTab {
                case .listen: listen
                case .shows: shows
                case .about: about
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            HStack {
                Text(status).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Open KXSF Window") { openWindow() }
                Button("Quit KXSF") { NSApplication.shared.terminate(nil) }
            }
        }
        .padding(20)
        .frame(width: 380, height: 520)
    }

    private var status: String {
        switch player.state {
        case .idle: "Ready to listen"
        case .loading: "Connecting to KXSF…"
        case .playing: "Playing live"
        case .failed: "Stream unavailable. Try again."
        }
    }

    private var listen: some View {
        VStack(spacing: 14) {
            AsyncImage(url: store.currentShow?.artworkURL) { image in
                image.resizable().scaledToFill()
            } placeholder: { Image("KXSFLogo").resizable().scaledToFit() }
            .frame(width: 136, height: 136).clipShape(RoundedRectangle(cornerRadius: 20))
            Text(store.currentShow?.name ?? "San Francisco Community Radio")
                .font(.title3.bold()).multilineTextAlignment(.center)
            if let host = store.currentShow?.hostName { Text("with \(host)").foregroundStyle(.secondary) }
            if let time = store.currentShow?.timeRange { Text(time).font(.caption) }
            Button { session.togglePlayback() } label: {
                Label(player.state == .loading ? "Cancel connection" : player.state.isPlaying ? "Pause" : "Listen live", systemImage: player.state == .loading ? "xmark" : player.state.isPlaying ? "pause.fill" : "play.fill")
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
            }.buttonStyle(.borderedProminent).tint(.red)
        }.padding(.vertical, 8)
    }

    private var shows: some View {
        VStack(alignment: .leading, spacing: 12) {
            if store.schedule.shows.isEmpty {
                Text(store.isLoading ? "Loading official schedule…" : "Official schedule unavailable.")
                Link("Open KXSF schedule", destination: URL(string: "https://kxsf.fm/schedule-shows/")!)
            }
            ForEach(store.schedule.sections) { section in
                DisclosureGroup(section.day.rawValue) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(section.shows) { show in
                            Link(destination: show.detailURL) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(show.name).fontWeight(.semibold)
                                    Text(show.timeRange).font(.caption).foregroundStyle(.secondary)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }.padding(.vertical, 8)
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("San Francisco Community Radio").font(.title3.bold())
            Text("Listen live to KXSF 102.5 FM and explore the station’s official programming.")
            Link("Visit KXSF", destination: URL(string: "https://kxsf.fm/")!)
            Link("Support KXSF", destination: URL(string: "https://kxsf.fm/support/")!)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
