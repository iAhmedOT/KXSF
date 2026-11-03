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

    @Test func accessibilityTextUsesSingleColumn() {
        #expect(!StationLayout.usesTwoColumns(width: 1180, height: 820, accessibilityText: true))
    }
}
