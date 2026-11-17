import KXSFCore
import SwiftUI

@main
struct KXSFApp: App {
    @StateObject private var coordinator = KXSFAppCoordinator()
    @State private var isSplashVisible = KXSFLaunchSplashPolicy.isEnabled(
        arguments: ProcessInfo.processInfo.arguments
    )
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some Scene {
        WindowGroup {
            ZStack {
                // The real app is created, and its normal background loading
                // (ContentView's refresh task) starts, while the splash is on
                // screen. The splash is a bounded minimum hold only: it never
                // waits for the network and does not imply data is ready.
                ContentView(
                    player: coordinator.player,
                    liveShow: coordinator.liveShow
                )
                .accessibilityHidden(isSplashVisible)
                .allowsHitTesting(!isSplashVisible)

                if isSplashVisible {
                    LaunchSplashOverlay(liveShow: coordinator.liveShow)
                        .transition(reduceMotion ? .identity : .opacity)
                        .zIndex(1)
                        .task {
                            let hold = KXSFLaunchSplashPolicy.hold(arguments: ProcessInfo.processInfo.arguments)
                            try? await Task.sleep(for: .seconds(hold))
                            guard !Task.isCancelled else { return }
                            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
                                isSplashVisible = false
                            }
                        }
                }
            }
        }
    }

}

/// Observes the live-show store so the test-only load probe updates when loading starts.
private struct LaunchSplashOverlay: View {
    @ObservedObject var liveShow: LiveShowStore

    var body: some View {
        let probe = KXSFLaunchSplashPolicy.exposesLoadProbe(arguments: ProcessInfo.processInfo.arguments)
        LaunchSplashView(
            loadProbeValue: probe ? (liveShow.hasStartedInitialRefresh ? "started" : "pending") : nil
        )
    }
}
