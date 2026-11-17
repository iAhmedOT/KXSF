import Foundation

/// Policy for the timed in-app launch splash (iPhone and iPad).
///
/// The splash is a bounded *minimum* hold: it never waits on the network and
/// never promises that data has loaded. Real app state is created and loading
/// begins while it is visible.
public enum KXSFLaunchSplashPolicy {
    /// Default minimum hold, pending Ahmed's visual acceptance.
    public static let minimumHold: TimeInterval = 2.0

    /// Hard ceiling regardless of configuration; the splash can never exceed it.
    public static let maximumHold: TimeInterval = 3.0

    /// UI-test-only argument that skips the splash for unrelated UI tests.
    public static let uiTestSkipArgument = "-KXSFUITestSkipSplash"

    /// UI-test-only argument that exposes a probe element reporting whether
    /// app loading has started behind the splash.
    public static let uiTestLoadProbeArgument = "-KXSFUITestLoadProbe"

    /// UI-test-only argument that lengthens the splash hold so XCUITest, which
    /// waits for app idle inside `launch()`, can still observe it. Production
    /// launches never pass it and always use `minimumHold`.
    public static let uiTestExtendedHoldArgument = "-KXSFUITestExtendedSplashHold"

    /// Hold used only when `uiTestExtendedHoldArgument` is present.
    public static let uiTestExtendedHold: TimeInterval = 12.0

    /// Hold for this launch: the production hold (clamped) unless the explicit
    /// UI-test-only extended-hold argument is present.
    public static func hold(arguments: [String]) -> TimeInterval {
        arguments.contains(uiTestExtendedHoldArgument) ? uiTestExtendedHold : clampedHold()
    }

    public static func isEnabled(arguments: [String]) -> Bool {
        !arguments.contains(uiTestSkipArgument)
    }

    public static func exposesLoadProbe(arguments: [String]) -> Bool {
        arguments.contains(uiTestLoadProbeArgument)
    }

    /// Hold actually used, always within (0, maximumHold]; invalid values fall
    /// back to `minimumHold`.
    public static func clampedHold(_ requested: TimeInterval = minimumHold) -> TimeInterval {
        guard requested.isFinite, requested > 0 else { return minimumHold }
        return min(requested, maximumHold)
    }
}
