# Checkpoint — KXSF Midnight Glass feedback build

**Date:** 2026-08-27
**Repository:** `/Users/ahmedalotaibi/Dev/KXSF`
**Branch:** `rebuild/midnight-glass`
**Commit baseline:** `913a74f` (`feat: add native KXSF schedule and show artwork`)
**State:** Ahmed visually accepted the feedback build on 2026-08-28; approved for commit and push.

## Included feedback work

- Reworked the root destination shell to reserve the top safe area and bottom floating-navigation area.
- Listen now renders connection state before confirmed playback, then an artwork-led Now Playing card with title, official host metadata when available, and time.
- Shows removes the programming eyebrow, starts at listener-local weekday, uses day accordions with every show visible when open, separates times from titles, and avoids generic host placeholders.
- KXSF Live remains backed by the official YouTube Atom feed; upload dates are removed.
- Station links route through the in-app Safari presentation.
- Live Activity receives current-show artwork/title/playback state and uses artwork-led presentation.
- Home Screen widget uses current-show artwork, title/time, and a distinct play/pause symbol backed by the app’s actual playback-state snapshot through its App Group. The icon updates after the app publishes a real player-state transition.

## Verified evidence

- `swift test`: **18 tests passed**.
- Regenerated from `MidnightGlass/project.yml` with `xcodegen generate`.
- Simulator Debug build: **BUILD SUCCEEDED**.
- Embedded WidgetKit extension Info.plist inspected: `NSExtensionPointIdentifier = com.apple.widgetkit-extension`.
- Installed and launched `com.KXSF.fm` on Pixel KXSF iPhone 17 Pro / iOS 27 Simulator.
- Captured and visually inspected `docs/screenshots/kxsf-feedback-listen-iphone17pro-ios27.png`: Listen screen has no visible top clipping; logo, status card, control, and navigation fit within safe areas.
- UI test `test_bottom_navigation_reaches_station_destinations`: **TEST SUCCEEDED**.
- UI test `test_launch_exposes_the_play_control`: **TEST SUCCEEDED**.

## Acceptance result

Ahmed completed the visual/product pass and approved the build for commit and push on 2026-08-28. The Listen, Shows, KXSF Live, Home Screen widget, Live Activity, and Dynamic Island presentation now clear the feedback-build acceptance gate.

## Next step

Commit and push the accepted feedback build, then begin release-readiness work: real-device verification, accessibility and resilience checks, App Store metadata/privacy review, and TestFlight preparation.
