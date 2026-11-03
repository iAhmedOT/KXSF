import AppKit
import SwiftUI
import Combine
import KXSFCore

@main
struct KXSFMacApp: App {
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) private var delegate
    var body: some Scene { Settings { EmptyView() } }
}

@MainActor
final class MacAppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    // Lifetime is the app's, not the panel's.
    let player = MacRadioPlayer()
    let store = LiveShowStore()
    lazy var session = MenuBarSession(transport: player)
    private var titleItem: NSStatusItem!

    private let popover = NSPopover()
    private var subscriptions = Set<AnyCancellable>()

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
        popover.contentViewController = NSHostingController(rootView: MacPlayerPanel(session: session, player: player, store: store))
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

struct MacPlayerPanel: View {
    @Bindable var session: MenuBarSession
    @ObservedObject var player: MacRadioPlayer
    @ObservedObject var store: LiveShowStore

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
