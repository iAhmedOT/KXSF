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
}
