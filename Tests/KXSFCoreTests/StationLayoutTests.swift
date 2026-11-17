import Testing
@testable import KXSFCore

struct StationLayoutTests {
    @Test(arguments: [(820.0, 1180.0), (1180.0, 820.0), (1024.0, 768.0)])
    func roomyWindowsUseTwoColumns(size: (Double, Double)) {
        #expect(StationLayout.usesTwoColumns(width: size.0, height: size.1))
    }

    @Test(arguments: [(819.0, 1180.0), (600.0, 900.0), (393.0, 852.0), (852.0, 393.0)])
    func narrowOrShortWindowsUseOneColumn(size: (Double, Double)) {
        #expect(!StationLayout.usesTwoColumns(width: size.0, height: size.1))
    }

    @Test(arguments: [320.0, 500.0, 559.0])
    func listenCardStacksWhenAvailableWidthIsCompact(width: Double) {
        #expect(StationLayout.stacksListenCard(availableWidth: width))
    }

    @Test(arguments: [560.0, 700.0, 772.0])
    func listenCardKeepsIdentityLeftAndPlayRightWhenWide(width: Double) {
        #expect(!StationLayout.stacksListenCard(availableWidth: width))
    }

    @Test func listenCardAlwaysStacksForAccessibilityText() {
        #expect(StationLayout.stacksListenCard(availableWidth: 1000, accessibilityText: true))
    }

    @Test(arguments: [440.0, 600.0, 772.0])
    func aboutActionsSitSideBySideWhenReadable(width: Double) {
        #expect(StationLayout.aboutActionsSideBySide(availableWidth: width))
    }

    @Test(arguments: [280.0, 360.0, 439.0])
    func aboutActionsStackWhenNarrow(width: Double) {
        #expect(!StationLayout.aboutActionsSideBySide(availableWidth: width))
    }

    @Test func aboutActionsStackForAccessibilityText() {
        #expect(!StationLayout.aboutActionsSideBySide(availableWidth: 900, accessibilityText: true))
    }

    @Test func accessibilityTextUsesSingleColumn() {
        #expect(!StationLayout.usesTwoColumns(width: 1180, height: 820, accessibilityText: true))
    }
}
