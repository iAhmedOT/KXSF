import SwiftUI

@main
struct KXSFApp: App {
    @StateObject private var coordinator = KXSFAppCoordinator()
    @State private var showsLaunchSplash: Bool

    /// Long enough to read the anniversary poster; short enough not to feel stuck.
    private let launchSplashDuration: Duration = .seconds(4)

    init() {
        // UI tests skip the timed splash so assertions can target the real app shell.
        let skipSplash = ProcessInfo.processInfo.arguments.contains("-UITestSkipLaunchSplash")
        _showsLaunchSplash = State(initialValue: !skipSplash)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView(
                    player: coordinator.player,
                    liveShow: coordinator.liveShow
                )

                if showsLaunchSplash {
                    LaunchSplashView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .animation(.easeOut(duration: 0.45), value: showsLaunchSplash)
            .task {
                guard showsLaunchSplash else { return }
                try? await Task.sleep(for: launchSplashDuration)
                showsLaunchSplash = false
            }
        }
    }
}
