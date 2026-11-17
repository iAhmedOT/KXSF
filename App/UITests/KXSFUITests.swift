import XCTest

final class KXSFUITests: XCTestCase {
    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    /// Launches for unrelated UI tests with the explicit UI-test-only splash skip.
    /// The real splash is exercised only by the dedicated launch tests below, which
    /// use `launchWithRealSplash`.
    @MainActor
    private func launchApp(arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-KXSFUITestSkipSplash"] + arguments
        app.launch()
        // The iPad tab selection can survive between launches in the simulator; every test
        // starts from Listen explicitly (iPhone always starts there).
        if isPad {
            let listen = tab(app, id: "listen", title: "Listen")
            if listen.waitForExistence(timeout: 10), !listen.isSelected { listen.tap() }
        }
        return app
    }

    /// iPhone: custom bar buttons identified `tab-<id>`. iPad: native TabView items found by title.
    @MainActor
    private func tab(_ app: XCUIApplication, id: String, title: String) -> XCUIElement {
        if !isPad { return app.buttons["tab-\(id)"] }
        let inBar = app.tabBars.buttons[title]
        return inBar.exists ? inBar : app.buttons[title].firstMatch
    }

    @MainActor
    private func waitForPlayLabel(_ label: String, on control: XCUIElement, timeout: TimeInterval = 20) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", label),
            object: control
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    // MARK: Launch

    /// Real launch: no skip argument. The 2-second minimum-hold splash must appear,
    /// then dismiss on its own and reveal usable content. Network state is irrelevant.
    @MainActor
    private func launchWithRealSplash(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = extraArguments
        app.launch()
        return app
    }

    @MainActor
    func test_real_timed_splash_shows_then_dismisses_to_app_content() {
        let app = launchWithRealSplash()
        defer { app.terminate() }
        XCTAssertEqual(app.state, .runningForeground)
        XCTAssertFalse(app.launchArguments.contains("-KXSFUITestSkipSplash"), "Splash test must not skip the splash")

        // XCUITest's launch() waits for the app to go idle, which can consume most or
        // all of the real 2 s hold, so presentation is NOT asserted on this path (that
        // would be flaky). The production-hold value itself is asserted in
        // KXSFLaunchSplashPolicyTests; presentation is proven by the extended-hold tests
        // below. This path proves the unmodified production launch ends with usable content.
        let playControl = app.buttons["playback-control"]
        XCTAssertTrue(playControl.waitForExistence(timeout: 10), "App content should appear after the production-hold splash")
        let splash = app.otherElements["launch-splash"]
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: splash)
        XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: 8), .completed, "Splash must not remain after the bounded hold")
        XCTAssertTrue(playControl.isHittable)
        attachScreenshot(named: "Launch content after production splash")
    }

    @MainActor
    func test_extended_hold_splash_is_presented_covers_content_and_dismisses_in_bounded_time() {
        let hold: TimeInterval = 12 // mirrors KXSFLaunchSplashPolicy.uiTestExtendedHold (core test pins it)
        let app = launchWithRealSplash(extraArguments: ["-KXSFUITestExtendedSplashHold"])
        let launched = Date()
        defer { app.terminate() }
        XCTAssertFalse(app.launchArguments.contains("-KXSFUITestSkipSplash"))

        // The extended hold leaves time to observe the real splash after launch() returns.
        let splash = app.otherElements["launch-splash"]
        XCTAssertTrue(splash.waitForExistence(timeout: 5), "Real splash must be presented on launch")
        attachScreenshot(named: "Launch splash")
        XCTAssertLessThan(Date().timeIntervalSince(launched), hold, "Splash must have been observed within its hold")

        // Content is covered (hidden from accessibility and hit testing) while the splash is up.
        XCTAssertFalse(app.buttons["playback-control"].isHittable, "App content must be covered by the splash")

        // Dismissal is bounded: hold + 0.25 s fade, with slack for slow simulators.
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: splash)
        XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: hold + 8), .completed, "Splash must dismiss on its own")

        let playControl = app.buttons["playback-control"]
        XCTAssertTrue(playControl.waitForExistence(timeout: 5), "App content should appear after the splash")
        XCTAssertTrue(playControl.isHittable)
        attachScreenshot(named: "Launch content after splash")
    }

    @MainActor
    func test_app_loading_starts_behind_the_splash() {
        let app = launchWithRealSplash(extraArguments: ["-KXSFUITestExtendedSplashHold", "-KXSFUITestLoadProbe"])
        defer { app.terminate() }

        let splash = app.otherElements["launch-splash"]
        XCTAssertTrue(splash.waitForExistence(timeout: 5))
        // Loading has been *requested* while the splash is still on screen. The probe
        // reports start only, never success, so this holds offline too (bounded wait).
        let probe = app.otherElements["launch-splash-load-state"]
        if probe.waitForExistence(timeout: 3) {
            let started = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "value == %@", "started"), object: probe
            )
            XCTAssertEqual(
                XCTWaiter.wait(for: [started], timeout: 3), .completed,
                "App loading should start while the splash is visible"
            )
        } else {
            XCTFail("Load probe was not exposed on the splash; splash may have dismissed before it could be checked")
        }
    }

    @MainActor
    func test_launch_exposes_the_play_control() {
        let app = launchApp()
        defer { app.terminate() }

        let playControl = app.buttons["playback-control"]
        XCTAssertTrue(playControl.waitForExistence(timeout: 5))
        XCTAssertTrue(playControl.isHittable)
        if isPad {
            XCTAssertTrue(app.scrollViews.staticTexts["Listen"].waitForExistence(timeout: 5))
        } else {
            XCTAssertTrue(app.staticTexts["Listen Now"].exists)
        }
    }

    // MARK: iPhone navigation

    @MainActor
    func test_iphone_bottom_navigation_reaches_station_destinations() throws {
        try XCTSkipIf(isPad, "iPhone navigation")
        let app = launchApp()
        defer { app.terminate() }

        attachScreenshot(named: "Listen")

        // Separate Listen and Shows destinations, with the renamed video destination.
        XCTAssertTrue(app.buttons["tab-listen"].exists)
        XCTAssertTrue(app.buttons["tab-shows"].exists)
        XCTAssertEqual(app.buttons["tab-live"].label, "KXSF Video")
        XCTAssertFalse(app.buttons["KXSF Live"].exists)
        XCTAssertTrue(app.buttons["tab-about"].exists)

        app.buttons["tab-shows"].tap()
        let showsTitle = app.scrollViews.staticTexts["Shows"]
        let windowFrame = app.windows.firstMatch.frame
        let tabFrame = app.buttons["tab-shows"].frame
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
        assertKXSFVideoDestination(app, windowFrame: windowFrame)
        attachScreenshot(named: "KXSF Video")

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
    private func assertKXSFVideoDestination(_ app: XCUIApplication, windowFrame: CGRect) {
        let title = app.scrollViews.staticTexts["KXSF Video"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertTrue(title.isHittable)
        XCTAssertFalse(app.scrollViews.staticTexts["KXSF Live"].exists, "Old destination name must be gone")
        XCTAssertTrue(app.staticTexts["WATCH PERFORMANCES FROM THE STATION"].exists)
        XCTAssertGreaterThan(title.frame.minY, windowFrame.minY + 40)
        XCTAssertLessThan(title.frame.minY, windowFrame.midY)
        // Network-dependent: official uploads load, or the truthful fallback is shown.
        let loadedOfficialVideos = app.otherElements["kxsf-live-content"].waitForExistence(timeout: 25)
        let honestFallback = app.staticTexts["KXSF Video is unavailable"].exists
        XCTAssertTrue(loadedOfficialVideos || honestFallback)
        XCTAssertTrue(app.staticTexts["Open KXSF on YouTube"].exists, "Official YouTube link must remain")
    }

    @MainActor
    func test_on_air_card_contains_label_and_duration() {
        let app = launchApp()
        defer { app.terminate() }

        if !isPad { app.buttons["tab-shows"].tap() }
        let card = app.descendants(matching: .any)["on-air-now-card"]
        guard card.waitForExistence(timeout: 12) else {
            // Network-dependent feed: without schedule data the app must say so and stay playable.
            let fallback = app.descendants(matching: .any)["station-identity-card"].exists
                || app.staticTexts["Official schedule unavailable"].exists
                || app.staticTexts["Loading the schedule"].exists
            XCTAssertTrue(fallback, "No current-show card and no truthful fallback")
            if isPad { XCTAssertTrue(app.buttons["playback-control"].isHittable) }
            return
        }
        XCTAssertTrue(card.label.localizedCaseInsensitiveContains("On air now"), "Card label: \(card.label)")
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "on-air-now-card").count, 1,
                       "Exactly one current-show card expected")
        XCTAssertNotNil(
            card.label.range(
                of: #"\d{1,2}:\d{2}\s*(?:am|pm)\s*[-–—]\s*\d{1,2}:\d{2}\s*(?:am|pm)"#,
                options: [.regularExpression, .caseInsensitive]
            ),
            "Card label has no duration: \(card.label)"
        )
    }

    // MARK: Playback

    @MainActor
    func test_listen_status_card_keeps_a_stable_frame_during_playback_transition() throws {
        try XCTSkipIf(isPad, "iPad status card is covered by the unified Listen tests")
        let app = launchApp()
        defer { app.terminate() }

        let card = app.descendants(matching: .any)["playback-status-card"]
        XCTAssertTrue(card.waitForExistence(timeout: 3))
        let initialFrame = card.frame

        let playbackControl = app.buttons["playback-control"]
        playbackControl.tap()
        XCTAssertTrue(waitForPlayLabel("Pause KXSF live stream", on: playbackControl))
        XCTAssertEqual(card.frame.height, initialFrame.height, accuracy: 1)
        XCTAssertEqual(card.frame.minY, initialFrame.minY, accuracy: 1)
    }

    @MainActor
    func test_rapid_play_pause_keeps_latest_intent() {
        let app = launchApp()
        defer { app.terminate() }

        let playbackControl = app.buttons["playback-control"]
        XCTAssertTrue(playbackControl.waitForExistence(timeout: 5))
        playbackControl.tap()
        playbackControl.tap()

        if isPad {
            // iPad has no written status line: idle is the Play control with a "Stopped" value.
            XCTAssertTrue(waitForPlayLabel("Play KXSF live stream", on: playbackControl, timeout: 5))
            Thread.sleep(forTimeInterval: 2)
            XCTAssertEqual(playbackControl.label, "Play KXSF live stream")
            XCTAssertEqual(playbackControl.value as? String, "Stopped")
        } else {
            let ready = app.staticTexts["Listen Now"]
            XCTAssertTrue(ready.waitForExistence(timeout: 2))
            Thread.sleep(forTimeInterval: 2)
            XCTAssertTrue(ready.exists)
            XCTAssertEqual(playbackControl.label, "Play KXSF live stream")
        }
    }

    @MainActor
    func test_play_starts_the_kxsf_stream() {
        let app = launchApp()
        defer { app.terminate() }

        let playbackControl = app.buttons["playback-control"]
        playbackControl.tap()
        let result = waitForPlayLabel("Pause KXSF live stream", on: playbackControl)
        print("KXSF_PLAYBACK_CONTROL label=\(playbackControl.label)")
        XCTAssertTrue(result)
    }

    // MARK: About

    @MainActor
    func test_about_exposes_station_social_links() {
        let app = launchApp()
        defer { app.terminate() }

        tab(app, id: "about", title: "About").tap()
        XCTAssertTrue(app.scrollViews.staticTexts["About KXSF"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["FOLLOW KXSF"].exists)
        XCTAssertTrue(app.staticTexts["Instagram"].exists)
        XCTAssertTrue(app.staticTexts["Facebook"].exists)
        XCTAssertTrue(app.staticTexts["X"].exists)
        XCTAssertTrue(app.staticTexts["YouTube"].exists)
    }

    // MARK: iPad unified navigation

    @MainActor
    func test_ipad_unified_listen_has_single_play_control_and_native_destinations() throws {
        try XCTSkipUnless(isPad, "iPad navigation")
        XCUIDevice.shared.orientation = .portrait
        let app = launchApp()
        defer {
            app.terminate()
            XCUIDevice.shared.orientation = .portrait
        }

        let play = app.buttons["playback-control"]
        XCTAssertTrue(play.waitForExistence(timeout: 5))
        XCTAssertTrue(play.isHittable)
        XCTAssertTrue(app.scrollViews.staticTexts["Listen"].waitForExistence(timeout: 5))

        // No bespoke two-column player, and exactly one Play control.
        XCTAssertFalse(app.otherElements["station-two-column-layout"].exists)
        XCTAssertEqual(app.buttons.matching(identifier: "playback-control").count, 1)

        // Destinations: Listen, KXSF Video, About. No separate Shows or old "KXSF Live".
        XCTAssertTrue(tab(app, id: "listen", title: "Listen").exists)
        XCTAssertTrue(tab(app, id: "live", title: "KXSF Video").exists)
        XCTAssertTrue(tab(app, id: "about", title: "About").exists)
        XCTAssertFalse(app.tabBars.buttons["Shows"].exists)
        XCTAssertFalse(app.buttons["KXSF Live"].exists)

        // Current show info appears once: on the card with Play (or a visible fallback).
        let showCard = app.descendants(matching: .any)["on-air-now-card"]
        let fallbackCard = app.descendants(matching: .any)["station-identity-card"]
        XCTAssertTrue(showCard.waitForExistence(timeout: 12) || fallbackCard.exists)
        XCTAssertLessThanOrEqual(app.descendants(matching: .any).matching(identifier: "on-air-now-card").count, 1)
        // The schedule section must not repeat the current show as a second "On air now" card.
        // A broad `label CONTAINS 'on air now'` over .any matches both the card's combined
        // accessibility label ("On air now, <show>, ...") and its child "ON AIR NOW" text,
        // so it double-counts one card. Count each kind separately instead.
        // 1) Combined card labels, any element type: a second rendering of the show would add one.
        let onAirCardLabel = NSPredicate(format: "label BEGINSWITH[c] 'on air now,'")
        XCTAssertLessThanOrEqual(app.descendants(matching: .any).matching(onAirCardLabel).count, 1,
                                 "Current show must render as an 'On air now' card only once on iPad")
        // 2) Standalone eyebrow text: exact match, static texts only.
        let onAirEyebrow = NSPredicate(format: "label ==[c] 'on air now'")
        XCTAssertLessThanOrEqual(app.staticTexts.matching(onAirEyebrow).count, 1,
                                 "'ON AIR NOW' eyebrow must appear only once on iPad")
        // Schedule is still part of Listen.
        XCTAssertTrue(app.otherElements["schedule-shows-content"].waitForExistence(timeout: 12)
            || app.staticTexts["Official schedule unavailable"].exists
            || app.staticTexts["Loading the schedule"].exists)
        attachScreenshot(named: "iPad Listen portrait")
    }

    @MainActor
    func test_ipad_playback_survives_navigation_and_rotation() throws {
        try XCTSkipUnless(isPad, "iPad navigation")
        XCUIDevice.shared.orientation = .portrait
        let app = launchApp()
        defer {
            app.terminate()
            XCUIDevice.shared.orientation = .portrait
        }

        let play = app.buttons["playback-control"]
        XCTAssertTrue(play.waitForExistence(timeout: 5))
        play.tap()
        XCTAssertTrue(waitForPlayLabel("Pause KXSF live stream", on: play))

        tab(app, id: "live", title: "KXSF Video").tap()
        assertKXSFVideoDestination(app, windowFrame: app.windows.firstMatch.frame)
        attachScreenshot(named: "iPad KXSF Video")

        tab(app, id: "about", title: "About").tap()
        XCTAssertTrue(app.scrollViews.staticTexts["About KXSF"].waitForExistence(timeout: 5))

        tab(app, id: "listen", title: "Listen").tap()
        let listenPlay = app.buttons["playback-control"]
        XCTAssertTrue(listenPlay.waitForExistence(timeout: 5))
        XCTAssertEqual(listenPlay.label, "Pause KXSF live stream", "Playback must continue through navigation")

        XCUIDevice.shared.orientation = .landscapeLeft
        let landscape = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                let frame = app.windows.firstMatch.frame
                return frame.width > frame.height
            },
            object: nil
        )
        XCTAssertEqual(XCTWaiter.wait(for: [landscape], timeout: 5), .completed)
        XCTAssertTrue(listenPlay.waitForExistence(timeout: 5))
        XCTAssertTrue(listenPlay.isHittable)
        XCTAssertEqual(listenPlay.label, "Pause KXSF live stream")
        attachScreenshot(named: "iPad Listen landscape")

        listenPlay.tap()
        XCTAssertTrue(waitForPlayLabel("Play KXSF live stream", on: listenPlay, timeout: 10))
    }

    @MainActor
    func test_ipad_accessibility_text_keeps_play_reachable() throws {
        try XCTSkipUnless(isPad, "iPad navigation")
        XCUIDevice.shared.orientation = .portrait
        let app = launchApp(arguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        defer { app.terminate() }

        let play = app.buttons["playback-control"]
        XCTAssertTrue(play.waitForExistence(timeout: 5))
        XCTAssertTrue(play.isHittable)
        XCTAssertFalse(app.otherElements["station-two-column-layout"].exists)
        attachScreenshot(named: "iPad accessibility text")
        tab(app, id: "about", title: "About").tap()
        XCTAssertTrue(app.scrollViews.staticTexts["About KXSF"].waitForExistence(timeout: 5))
    }

    // MARK: iPad unified Listen: layout, hit testing, state

    @MainActor
    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    /// Guards against the layout marker's identifier propagating onto its children:
    /// the accessible button and the current-show element must keep their own identifiers,
    /// and the marker must be a distinct element enclosing both.
    @MainActor
    private func assertChildIdentifiersSurvive(_ app: XCUIApplication, layout: String, play: XCUIElement, identity: XCUIElement) {
        XCTAssertEqual(play.identifier, "playback-control")
        XCTAssertEqual(play.elementType, .button)
        XCTAssertTrue(play.label.hasSuffix("KXSF live stream") || play.label.hasPrefix("Cancel"),
                      "Play button keeps its own label, got '\(play.label)'")
        XCTAssertEqual(app.buttons.matching(identifier: "playback-control").count, 1)
        // Child uniqueness: the enclosing card's identifier must not leak onto the children.
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "playback-status-card").count, 1,
                       "Exactly one playback-status-card; it must not be inherited by children")
        XCTAssertNotEqual(play.identifier, "playback-status-card")
        XCTAssertNotEqual(identity.identifier, "playback-status-card")
        if identity.identifier == "on-air-now-card" {
            XCTAssertTrue(identity.label.hasPrefix("On air now, "), "Current show identity label: '\(identity.label)'")
        } else {
            XCTAssertEqual(identity.identifier, "station-identity-card")
            XCTAssertEqual(identity.label, "KXSF 102.5 FM, San Francisco Community Radio")
        }
        let card = element(app, "playback-status-card")
        XCTAssertTrue(card.exists)
        XCTAssertTrue(card.frame.contains(play.frame), "Playback card encloses the play button (\(layout))")
        XCTAssertTrue(card.frame.contains(identity.frame), "Playback card encloses the show identity (\(layout))")
    }

    @MainActor
    func test_ipad_wide_listen_keeps_show_left_and_play_right() throws {
        try XCTSkipUnless(isPad, "iPad layout")
        XCUIDevice.shared.orientation = .portrait
        let app = launchApp()
        defer { app.terminate() }

        let play = app.buttons["playback-control"]
        XCTAssertTrue(play.waitForExistence(timeout: 5))
        let identity = element(app, "on-air-now-card").exists ? element(app, "on-air-now-card") : element(app, "station-identity-card")
        XCTAssertTrue(identity.waitForExistence(timeout: 12))
        // Wide arrangement is proven by real frames: identity entirely left of play, side by side.
        XCTAssertLessThanOrEqual(identity.frame.maxX, play.frame.minX + 1, "Full-width iPad uses the wide arrangement")
        assertChildIdentifiersSurvive(app, layout: "listen-layout-wide", play: play, identity: identity)
        XCTAssertLessThan(identity.frame.midX, play.frame.midX, "Show identity left of play")
        XCTAssertLessThanOrEqual(identity.frame.maxX, play.frame.minX + 1, "Identity must not overlap play")
        XCTAssertEqual(identity.frame.midY, play.frame.midY, accuracy: 60, "Play is level with the show")
        attachScreenshot(named: "iPad Listen wide arrangement")
    }

    @MainActor
    func test_ipad_compact_listen_centers_play_over_a_full_width_show_card() throws {
        try XCTSkipUnless(isPad, "iPad layout")
        XCUIDevice.shared.orientation = .portrait
        // Accessibility text forces the compact arrangement regardless of window width.
        // Narrow Split View / Slide Over widths (< 560 pt) use the same code path and are
        // covered by StationLayoutTests plus Pixel's manual multitasking pass.
        let app = launchApp(arguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        defer { app.terminate() }

        let play = app.buttons["playback-control"]
        XCTAssertTrue(play.waitForExistence(timeout: 5))
        let card = element(app, "playback-status-card")
        XCTAssertTrue(card.exists)
        XCTAssertEqual(play.frame.midX, card.frame.midX, accuracy: 4, "Play is horizontally centred in the card")

        let identity = element(app, "on-air-now-card").exists ? element(app, "on-air-now-card") : element(app, "station-identity-card")
        XCTAssertTrue(identity.waitForExistence(timeout: 12))
        assertChildIdentifiersSurvive(app, layout: "listen-layout-compact", play: play, identity: identity)
        XCTAssertLessThanOrEqual(play.frame.maxY, identity.frame.minY + 1, "Play sits above the current show")
        XCTAssertGreaterThan(identity.frame.width, card.frame.width * 0.85, "Show fills the card width")

        // The outer card spans the same column as the schedule content.
        let schedule = element(app, "schedule-shows-content")
        if schedule.waitForExistence(timeout: 12) {
            XCTAssertEqual(card.frame.minX, schedule.frame.minX, accuracy: 2)
            XCTAssertEqual(card.frame.width, schedule.frame.width, accuracy: 2)
        }
        attachScreenshot(named: "iPad Listen compact arrangement")
    }

    @MainActor
    func test_ipad_has_no_written_status_and_shows_state_through_the_control() throws {
        try XCTSkipUnless(isPad, "iPad status")
        let app = launchApp()
        defer { app.terminate() }

        let play = app.buttons["playback-control"]
        XCTAssertTrue(play.waitForExistence(timeout: 5))
        for forbidden in ["Ready to listen", "Live on KXSF", "Connecting to KXSF…", "Playing live"] {
            XCTAssertFalse(app.staticTexts[forbidden].exists, "Persistent status text '\(forbidden)' must be gone")
        }
        XCTAssertEqual(play.label, "Play KXSF live stream")
        XCTAssertEqual(play.value as? String, "Stopped")
        XCTAssertFalse(element(app, "playback-error").exists, "No error before anything fails")

        play.tap()
        // Pause may only appear once playback is confirmed; until then it is Cancel (spinner).
        let confirmed = waitForPlayLabel("Pause KXSF live stream", on: play)
        if confirmed {
            XCTAssertEqual(play.value as? String, "Playing")
            XCTAssertFalse(element(app, "playback-error").exists)
        } else {
            // Network-dependent: failure must be visible and retryable, never a false playing state.
            XCTAssertNotEqual(play.label, "Pause KXSF live stream")
            XCTAssertTrue(element(app, "playback-error").waitForExistence(timeout: 5)
                || play.label == "Cancel connection to KXSF")
        }
        for forbidden in ["Ready to listen", "Live on KXSF", "Connecting to KXSF…"] {
            XCTAssertFalse(app.staticTexts[forbidden].exists)
        }
    }

    @MainActor
    func test_ipad_controls_are_hittable_and_do_not_overlap() throws {
        try XCTSkipUnless(isPad, "iPad hit testing")
        let app = launchApp()
        defer { app.terminate() }

        let play = app.buttons["playback-control"]
        XCTAssertTrue(play.waitForExistence(timeout: 5))
        XCTAssertTrue(play.isHittable)
        XCTAssertGreaterThanOrEqual(play.frame.width, 44)
        XCTAssertGreaterThanOrEqual(play.frame.height, 44)

        let show = element(app, "on-air-now-card")
        if show.waitForExistence(timeout: 12) {
            XCTAssertTrue(show.isHittable)
            XCTAssertFalse(show.frame.intersects(play.frame), "Show link and play must not overlap")
        }
        // The retry button exists only when an error is showing; when it does, it must be tappable.
        let retry = app.buttons["playback-retry"]
        if retry.exists { XCTAssertTrue(retry.isHittable) }
    }

    @MainActor
    func test_ipad_up_next_is_truthful_and_the_full_schedule_remains() throws {
        try XCTSkipUnless(isPad, "iPad schedule")
        let app = launchApp()
        defer { app.terminate() }

        let schedule = element(app, "schedule-shows-content")
        guard schedule.waitForExistence(timeout: 15) else {
            XCTAssertTrue(app.staticTexts["Official schedule unavailable"].exists
                || app.staticTexts["Loading the schedule"].exists)
            return
        }
        // Up Next is computed from station time: it shows one show, or says it is unavailable.
        let next = element(app, "up-next-card")
        let unavailable = element(app, "up-next-unavailable")
        XCTAssertTrue(next.exists || unavailable.exists)
        if next.exists {
            XCTAssertTrue(next.label.hasPrefix("Up next:"), next.label)
            XCTAssertTrue(next.label.hasSuffix("Pacific time"), next.label)
            XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "up-next-card").count, 1)
        }
        // Other scheduled shows stay reachable.
        XCTAssertTrue(app.staticTexts["FULL SCHEDULE"].exists)
        XCTAssertTrue(app.staticTexts["UP NEXT"].exists)
        XCTAssertTrue(app.staticTexts["MONDAY"].exists || app.staticTexts["SUNDAY"].exists
            || app.staticTexts["TUESDAY"].exists || app.staticTexts["WEDNESDAY"].exists
            || app.staticTexts["THURSDAY"].exists || app.staticTexts["FRIDAY"].exists
            || app.staticTexts["SATURDAY"].exists, "Day groups must remain")
    }

    // MARK: About layout

    @MainActor
    func test_about_intro_card_matches_content_width_and_actions_sit_side_by_side_when_wide() throws {
        try XCTSkipUnless(isPad, "iPad About layout")
        XCUIDevice.shared.orientation = .portrait
        let app = launchApp()
        defer { app.terminate() }

        tab(app, id: "about", title: "About").tap()
        XCTAssertTrue(app.scrollViews.staticTexts["About KXSF"].waitForExistence(timeout: 5))
        let intro = element(app, "about-intro-card")
        let visit = element(app, "about-visit-link")
        let support = element(app, "about-support-link")
        XCTAssertTrue(intro.waitForExistence(timeout: 5))
        XCTAssertTrue(visit.exists && support.exists)

        // Equal width: the two actions together span exactly the intro card's column.
        XCTAssertEqual(visit.frame.minX, intro.frame.minX, accuracy: 2)
        XCTAssertEqual(support.frame.maxX, intro.frame.maxX, accuracy: 2)
        XCTAssertEqual(visit.frame.minY, support.frame.minY, accuracy: 2, "Side by side when readable")
        XCTAssertLessThanOrEqual(visit.frame.maxX, support.frame.minX)

        XCTAssertTrue(visit.isHittable)
        XCTAssertTrue(support.isHittable)
        XCTAssertTrue(visit.isEnabled && support.isEnabled)
        XCTAssertTrue(visit.label.contains("Visit KXSF.FM"), visit.label)
        XCTAssertTrue(support.label.contains("Support KXSF"), support.label)
        attachScreenshot(named: "iPad About wide")
    }

    @MainActor
    func test_about_actions_stack_for_accessibility_text_and_stay_tappable() throws {
        try XCTSkipUnless(isPad, "iPad About layout")
        XCUIDevice.shared.orientation = .portrait
        let app = launchApp(arguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        defer { app.terminate() }

        tab(app, id: "about", title: "About").tap()
        XCTAssertTrue(app.scrollViews.staticTexts["About KXSF"].waitForExistence(timeout: 5))
        let intro = element(app, "about-intro-card")
        let visit = element(app, "about-visit-link")
        let support = element(app, "about-support-link")
        XCTAssertTrue(intro.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(support.frame.minY, visit.frame.maxY - 1, "Stacked at accessibility sizes")
        XCTAssertEqual(visit.frame.width, intro.frame.width, accuracy: 2)
        XCTAssertEqual(support.frame.width, intro.frame.width, accuracy: 2)
        XCTAssertTrue(visit.isEnabled && support.isEnabled)
        if !visit.isHittable { app.swipeUp() }
        XCTAssertTrue(visit.isHittable)
        attachScreenshot(named: "iPad About accessibility text")
    }

    // MARK: Continuity

    @MainActor
    func test_ipad_playback_continues_across_orientation_resize_without_restarting() throws {
        try XCTSkipUnless(isPad, "iPad resize continuity")
        XCUIDevice.shared.orientation = .portrait
        let app = launchApp()
        defer {
            app.terminate()
            XCUIDevice.shared.orientation = .portrait
        }

        let play = app.buttons["playback-control"]
        XCTAssertTrue(play.waitForExistence(timeout: 5))
        play.tap()
        guard waitForPlayLabel("Pause KXSF live stream", on: play) else {
            throw XCTSkip("Stream unreachable in this environment; continuity needs confirmed playback")
        }
        for orientation in [UIDeviceOrientation.landscapeRight, .portrait, .landscapeLeft, .portrait] {
            XCUIDevice.shared.orientation = orientation
            XCTAssertTrue(play.waitForExistence(timeout: 5))
            // Never drops to Play or the spinner: the same player keeps running through relayout.
            XCTAssertEqual(play.label, "Pause KXSF live stream", "Playback restarted or stopped on resize to \(orientation.rawValue)")
            XCTAssertEqual(play.value as? String, "Playing")
        }
    }

    @MainActor
    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
