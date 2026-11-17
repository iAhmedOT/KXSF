import XCTest
@testable import KXSFCore

final class KXSFLaunchSplashPolicyTests: XCTestCase {
    func test_default_hold_is_two_seconds_and_bounded() {
        XCTAssertEqual(KXSFLaunchSplashPolicy.minimumHold, 2.0)
        XCTAssertLessThanOrEqual(KXSFLaunchSplashPolicy.minimumHold, KXSFLaunchSplashPolicy.maximumHold)
        XCTAssertEqual(KXSFLaunchSplashPolicy.clampedHold(), 2.0)
    }

    func test_hold_is_clamped_and_invalid_values_fall_back() {
        XCTAssertEqual(KXSFLaunchSplashPolicy.clampedHold(60), KXSFLaunchSplashPolicy.maximumHold)
        XCTAssertEqual(KXSFLaunchSplashPolicy.clampedHold(0), KXSFLaunchSplashPolicy.minimumHold)
        XCTAssertEqual(KXSFLaunchSplashPolicy.clampedHold(-1), KXSFLaunchSplashPolicy.minimumHold)
        XCTAssertEqual(KXSFLaunchSplashPolicy.clampedHold(.infinity), KXSFLaunchSplashPolicy.minimumHold)
        XCTAssertEqual(KXSFLaunchSplashPolicy.clampedHold(.nan), KXSFLaunchSplashPolicy.minimumHold)
        XCTAssertEqual(KXSFLaunchSplashPolicy.clampedHold(1.5), 1.5)
    }

    func test_splash_is_enabled_unless_the_explicit_ui_test_argument_is_present() {
        XCTAssertTrue(KXSFLaunchSplashPolicy.isEnabled(arguments: []))
        XCTAssertTrue(KXSFLaunchSplashPolicy.isEnabled(arguments: ["-AppleLanguages", "(en)"]))
        XCTAssertFalse(KXSFLaunchSplashPolicy.isEnabled(arguments: ["-KXSFUITestSkipSplash"]))
    }

    func test_production_hold_is_the_configured_two_seconds_without_test_arguments() {
        XCTAssertEqual(KXSFLaunchSplashPolicy.hold(arguments: []), 2.0)
        XCTAssertEqual(KXSFLaunchSplashPolicy.hold(arguments: ["-KXSFUITestLoadProbe"]), 2.0)
        XCTAssertEqual(KXSFLaunchSplashPolicy.hold(arguments: ["-AppleLanguages", "(en)"]),
                       KXSFLaunchSplashPolicy.minimumHold)
    }

    func test_extended_hold_applies_only_with_its_explicit_ui_test_argument() {
        XCTAssertEqual(KXSFLaunchSplashPolicy.uiTestExtendedHoldArgument, "-KXSFUITestExtendedSplashHold")
        XCTAssertEqual(KXSFLaunchSplashPolicy.hold(arguments: ["-KXSFUITestExtendedSplashHold"]),
                       KXSFLaunchSplashPolicy.uiTestExtendedHold)
        XCTAssertGreaterThan(KXSFLaunchSplashPolicy.uiTestExtendedHold, KXSFLaunchSplashPolicy.maximumHold)
        XCTAssertEqual(KXSFLaunchSplashPolicy.clampedHold(KXSFLaunchSplashPolicy.uiTestExtendedHold),
                       KXSFLaunchSplashPolicy.maximumHold, "Production clamp is unchanged")
    }

    func test_load_probe_requires_its_explicit_argument() {
        XCTAssertFalse(KXSFLaunchSplashPolicy.exposesLoadProbe(arguments: []))
        XCTAssertFalse(KXSFLaunchSplashPolicy.exposesLoadProbe(arguments: ["-KXSFUITestSkipSplash"]))
        XCTAssertTrue(KXSFLaunchSplashPolicy.exposesLoadProbe(arguments: ["-KXSFUITestLoadProbe"]))
    }
}
