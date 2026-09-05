# KXSF Midnight Glass — Simulator Verification Checkpoint

**Date:** 2026-08-27
**Branch:** `rebuild/midnight-glass`
**Target:** iPhone 17 Pro Simulator, iOS 27.0
**Visual artifact:** `docs/screenshots/kxsf-listen-iphone17pro-ios27.png`

## Verified outcome

The committed `ContentView` shell reproduces the Xcode Preview composition on a real iPhone 17 Pro Simulator. No additional Listen-screen layout offsets were needed.

The final screenshot verifies:

- the official KXSF logo is fully visible and retains its proportions;
- the Ready card is not clipped;
- the 108-point Play control is fully visible and separated from navigation;
- the four-tab floating navigation capsule is visible at the bottom;
- Listen, Shows, Calendar, and About labels remain legible;
- no content overlaps the navbar or screen edge.

`ListenView` remains the approved normal-flow composition:

```text
logo 280pt
24pt spacing
status card
24pt spacing
Play 108pt
```

Navigation geometry remains owned by `ContentView`.

## Defects fixed during verification

### UI-test target configuration

The generated UI-test target could not run because it had no Info.plist. `project.yml` now sets:

```yaml
GENERATE_INFOPLIST_FILE: YES
```

The Xcode project was regenerated with XcodeGen so the source configuration and checked-in project agree.

### Main-thread audio-session activation

The Play test exposed an AVFoundation warning that synchronous `AVAudioSession.setActive` could block the main thread. Audio-session category and activation now execute in a detached user-initiated task. Player creation and published state updates return to `AudioPlayerService` on the main actor.

### UI-test lifecycle

Each UI test now terminates its launched app with `defer`, preventing KXSF's background-audio mode from surviving an individual test case.

## Verification evidence

### Core tests

```text
swift test
Executed 8 tests, with 0 failures.
```

Coverage includes the verified KXSF endpoint, live-show parsing, and playback-state transitions.

### iOS UI tests

```text
xcodebuild ... -destination id=<iPhone 17 Pro Simulator> test
** TEST SUCCEEDED **
Executed 3 tests, with 0 failures.
```

The UI suite proves:

1. Play exists and is hittable.
2. Shows, Calendar, and About are reachable through the bottom navigation.
3. Tapping Play reaches the `Live on KXSF` accessibility state through the real stream.

The earlier main-thread AVAudioSession warning is absent after the audio-session change.

## Environment note

The iOS 27 Simulator runtime had been missing from both local Xcode installations. It was installed through Xcode before this verification. Xcode 27 beta still emits a duplicate WebCore/WebKit accessibility-loader warning from the Simulator runtime; it does not originate in KXSF source and did not fail the suite.

## Schedule and artwork enhancement — 2026-08-27

The Listen screen now reuses KXSF’s official `schedule-shows` page as a single source for current-show metadata and artwork. The new core parser produces structured weekday, show, time range, destination URL, official artwork URL, and `Now playing` state while deliberately skipping incomplete cards instead of inventing a schedule entry.

### Product behavior

- **Listen:** the existing status card now includes an official Now Playing artwork row when KXSF publishes an active show with artwork. Artwork is fetched remotely and never treated as required: slow, unavailable, or failed artwork renders a station-themed music-note fallback.
- **Shows:** displays the active show plus a short native weekly view; each entry opens its official KXSF detail page.
- **Calendar:** retains its standalone destination and displays the full native weekly schedule grouped by weekday; the original official station calendar and events links remain available.
- **Failure state:** if KXSF’s schedule page is unavailable or its markup no longer parses into usable records, both destinations communicate that honestly and preserve official fallbacks.

### Verification evidence

```text
swift test
Executed 12 tests, with 0 failures.

xcodebuild ... -destination id=<iPhone 17 Pro Simulator> test
Executed 3 tests, with 0 failures.
** TEST SUCCEEDED **
```

The core suite includes four schedule-parser tests covering weekday grouping, show/artwork metadata, the current-show record, and incomplete-card rejection. The iPhone 17 Pro UI suite verifies that the Play control is still hittable, the new native Shows and Calendar schedule surfaces are reachable, and the real stream still reaches `Live on KXSF`.

A fresh visual artifact, `docs/screenshots/kxsf-schedule-artwork-iphone17pro-ios27.png`, confirms official KXSF artwork rendered in the Now Playing card while the logo, card, 108-point Play control, floating navigation, and home-indicator clearance remained clean.


1. Validate the same Listen/navigation composition with larger Dynamic Type.
2. Verify background/foreground playback behavior in the Simulator and later on a physical iPhone.
3. Decide whether Shows and Calendar should stay official-site links or become native schedule views.
4. Add a real app icon before distribution work.
