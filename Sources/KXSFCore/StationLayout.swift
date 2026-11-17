/// Minimum usable space for a 360-point player, a detail pane, and gutters.
/// Window geometry, not hardware identity, determines the layout.
public enum StationLayout {
    public static func usesTwoColumns(
        width: Double,
        height: Double,
        accessibilityText: Bool = false
    ) -> Bool {
        width >= 820 && height >= 600 && !accessibilityText
    }

    /// Unified Listen card. Below this available width the play control is
    /// centred on top with the current show beneath it, full width. At or above it
    /// the show identity sits left and play sits right.
    public static let listenCardStackThreshold = 560.0

    public static func stacksListenCard(availableWidth: Double, accessibilityText: Bool = false) -> Bool {
        accessibilityText || availableWidth < listenCardStackThreshold
    }

    /// About: "Visit KXSF.FM" and "Support KXSF" share a row only when both labels read comfortably.
    public static let aboutActionsSideBySideThreshold = 440.0

    public static func aboutActionsSideBySide(availableWidth: Double, accessibilityText: Bool = false) -> Bool {
        !accessibilityText && availableWidth >= aboutActionsSideBySideThreshold
    }
}
