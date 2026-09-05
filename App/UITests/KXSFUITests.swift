import XCTest

final class KXSFUITests: XCTestCase {
    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("-UITestSkipLaunchSplash")
        app.launch()
        return app
    }

    @MainActor
    func test_launch_exposes_the_play_control() {
        let app = launchApp()
        defer { app.terminate() }

        let playControl = app.buttons["playback-control"]
        XCTAssertTrue(playControl.waitForExistence(timeout: 5))
        XCTAssertTrue(playControl.isHittable)
        XCTAssertTrue(app.staticTexts["Listen Now"].exists)
    }

    @MainActor
    func test_bottom_navigation_reaches_station_destinations() {
        let app = launchApp()
        defer { app.terminate() }

        attachScreenshot(named: "Listen")

        app.buttons["tab-shows"].tap()
        let showsTitle = app.scrollViews.staticTexts["Shows"]
        let windowFrame = app.windows.firstMatch.frame
        let tabFrame = app.buttons["tab-shows"].frame
        print("KXSF_LAYOUT window=\(windowFrame) title=\(showsTitle.frame) tab=\(tabFrame)")
        XCTAssertTrue(showsTitle.waitForExistence(timeout: 5))
        XCTAssertTrue(showsTitle.isHittable)
        XCTAssertTrue(app.staticTexts["WEEKLY KXSF SCHEDULE"].exists)
        XCTAssertGreaterThan(showsTitle.frame.minY, windowFrame.minY + 40)
        XCTAssertLessThan(showsTitle.frame.minY, windowFrame.midY)
        XCTAssertGreaterThan(tabFrame.maxY, windowFrame.maxY - 80)
        XCTAssertLessThan(tabFrame.maxY, windowFrame.maxY)
        XCTAssertTrue(app.otherElements["schedule-shows-content"].exists)
        attachScreenshot(named: "Shows")

        app.buttons["tab-live"].tap()
        let liveTitle = app.scrollViews.staticTexts["KXSF Live"]
        XCTAssertTrue(liveTitle.waitForExistence(timeout: 5))
        XCTAssertTrue(liveTitle.isHittable)
        XCTAssertTrue(app.staticTexts["WATCH PERFORMANCES FROM THE STATION"].exists)
        XCTAssertGreaterThan(liveTitle.frame.minY, windowFrame.minY + 40)
        XCTAssertLessThan(liveTitle.frame.minY, windowFrame.midY)
        let liveContent = app.otherElements["kxsf-live-content"]
        let loadedOfficialVideos = liveContent.waitForExistence(timeout: 25)
        let honestFallback = app.staticTexts["KXSF Live is unavailable"].exists
        XCTAssertTrue(loadedOfficialVideos || honestFallback)
        attachScreenshot(named: "KXSF Live")

        app.buttons["tab-about"].tap()
        let aboutTitle = app.scrollViews.staticTexts["About KXSF"]
        XCTAssertTrue(aboutTitle.waitForExistence(timeout: 5))
        XCTAssertTrue(aboutTitle.isHittable)
        XCTAssertGreaterThan(aboutTitle.frame.minY, windowFrame.minY + 40)
        XCTAssertLessThan(aboutTitle.frame.minY, windowFrame.midY)
        XCTAssertTrue(app.staticTexts["FOLLOW KXSF"].exists)
        attachScreenshot(named: "About")
    }

    @MainActor
    func test_on_air_card_contains_label_and_duration() {
        let app = launchApp()
        defer { app.terminate() }

        app.buttons["tab-shows"].tap()
        let card = app.descendants(matching: .any)["on-air-now-card"]
        XCTAssertTrue(card.waitForExistence(timeout: 12))
        XCTAssertTrue(card.label.localizedCaseInsensitiveContains("On air now"), "Card label: \(card.label)")
        XCTAssertNotNil(
            card.label.range(
                of: #"\d{1,2}:\d{2}\s*(?:am|pm)\s*[-–—]\s*\d{1,2}:\d{2}\s*(?:am|pm)"#,
                options: [.regularExpression, .caseInsensitive]
            ),
            "Card label has no duration: \(card.label)"
        )
    }

    @MainActor
    func test_listen_status_card_keeps_a_stable_frame_during_playback_transition() {
        let app = launchApp()
        defer { app.terminate() }

        let card = app.descendants(matching: .any)["playback-status-card"]
        XCTAssertTrue(card.waitForExistence(timeout: 3))
        let initialFrame = card.frame

        let playbackControl = app.buttons["playback-control"]
        playbackControl.tap()
        let becameLive = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "Pause KXSF live stream"),
            object: playbackControl
        )
        XCTAssertEqual(XCTWaiter.wait(for: [becameLive], timeout: 20), .completed)
        XCTAssertEqual(card.frame.height, initialFrame.height, accuracy: 1)
        XCTAssertEqual(card.frame.minY, initialFrame.minY, accuracy: 1)
    }

    @MainActor
    func test_rapid_play_pause_keeps_latest_intent() {
        let app = launchApp()
        defer { app.terminate() }

        let playbackControl = app.buttons["playback-control"]
        playbackControl.tap()
        playbackControl.tap()

        let ready = app.staticTexts["Listen Now"]
        XCTAssertTrue(ready.waitForExistence(timeout: 2))
        Thread.sleep(forTimeInterval: 2)
        XCTAssertTrue(ready.exists)
        XCTAssertEqual(playbackControl.label, "Play KXSF live stream")
    }

    @MainActor
    func test_play_starts_the_kxsf_stream() {
        let app = launchApp()
        defer { app.terminate() }

        let playbackControl = app.buttons["playback-control"]
        playbackControl.tap()

        let becameLive = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "Pause KXSF live stream"),
            object: playbackControl
        )
        let result = XCTWaiter.wait(for: [becameLive], timeout: 20)
        print("KXSF_PLAYBACK_CONTROL label=\(playbackControl.label)")
        XCTAssertEqual(result, .completed)
    }

    @MainActor
    func test_about_exposes_station_social_links() {
        let app = launchApp()
        defer { app.terminate() }

        app.buttons["tab-about"].tap()
        XCTAssertTrue(app.scrollViews.staticTexts["About KXSF"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["FOLLOW KXSF"].exists)
        XCTAssertTrue(app.staticTexts["Instagram"].exists)
        XCTAssertTrue(app.staticTexts["Facebook"].exists)
        XCTAssertTrue(app.staticTexts["X"].exists)
        XCTAssertTrue(app.staticTexts["YouTube"].exists)
    }

    @MainActor
    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
