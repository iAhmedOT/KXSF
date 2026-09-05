import Foundation

public enum KXSFArtworkPolicy {
    /// Compact WidgetKit and ActivityKit surfaces reserve artwork for a square tile.
    /// Accept tiny source rounding differences, but use the official KXSF logo for
    /// landscape, portrait, missing, or invalid show artwork.
    public static func isSuitableForCompactPresentation(
        width: Double,
        height: Double,
        minimumAspectRatio: Double = 0.95
    ) -> Bool {
        guard width > 0, height > 0 else { return false }
        return min(width, height) / max(width, height) >= minimumAspectRatio
    }
}
