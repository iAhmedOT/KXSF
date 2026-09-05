# KXSF

Native iOS app for **KXSF 102.5 FM — San Francisco Community Radio**.

KXSF V2 is a SwiftUI rebuild that preserves the production app identity (`com.KXSF.fm`) while replacing the inherited UIKit-era implementation with a focused listener experience: live playback, an official KXSF schedule, KXSF Live videos from the station’s official YouTube channel, WidgetKit, and Live Activities.

## Status

**2.0 submitted to App Store Connect — awaiting Apple review.**  
The public-Xcode archive (`Xcode 26.6` / `iphoneos26.5`) was accepted for review. **The 2.0 line is frozen.** Any further product work belongs on a **2.1** line only and must not be mixed into the submitted 2.0 package.

- App bundle ID: `com.KXSF.fm`
- Live Activity extension: `com.KXSF.fm.liveactivities`
- Version/build: `2.0 (1)`
- Deployment target: iOS 18.0+
- Signing organization: San Francisco Community Radio Inc (`Y7PURZ5849`)
- Local archive: `build/KXSF-2.0.xcarchive`
- Local IPA: `build/export/KXSF.ipa`
- App Store screenshots (6.5″ accepted size): `docs/screenshots/app-store/exports/` at **1284 × 2778 RGB**

## What is implemented

- **Listen** — live KXSF playback using `AVPlayer`, background-audio support, honest ready/connecting/playing/failed states, and a stable Now Playing card.
- **Shows** — current and upcoming schedule populated from KXSF’s official schedule pages.
- **Readable schedule data** — centralized HTML entity decoding, whitespace cleanup, and tested removal of website-added weekday/time suffixes.
- **Official host data** — host/byline information is extracted from official show-page metadata or member blocks when KXSF supplies it. The app does not invent missing credits.
- **KXSF Live** — latest official uploads from `youtube.com/@kxsfradio`, supporting desktop and mobile YouTube renderer variants, bounded retries, and a last-known-good local cache.
- **Widgets and Live Activities** — shared, confirmed playback/schedule state plus locally persisted revision-matched artwork through the App Group.
- **Artwork safety** — WidgetKit and ActivityKit receive center-cropped square show artwork when the source is non-square; missing or invalid artwork falls back to the official KXSF logo.
- **Deep link** — `kxsf://listen` opens the Listen destination.
- **Privacy and release metadata** — app and extension privacy manifests, App Group declarations, narrow ATS exception only for the verified KXSF HTTP stream, and `ITSAppUsesNonExemptEncryption = false`.

## Architecture

```text
Official KXSF website / official KXSF YouTube channel
                   ↓
            KXSFCore parsers
     (normalization + validation + retries)
                   ↓
            LiveShowStore
                   ↓
 SwiftUI app screens ─── KXSFAppCoordinator ─── AVPlayer
                   ↓                 ↓
     App Group snapshot + local artwork cache
                   ↓
           WidgetKit / ActivityKit
```

### Project layout

```text
App/
  Sources/              SwiftUI app, audio player, schedule/live-content store
  Shared/               app-group snapshot, design system, artwork bridge
  LiveActivity/         WidgetKit and ActivityKit extension
  UITests/              iOS UI regression coverage
Sources/KXSFCore/       parsers, schedule models, retry/cache/policy utilities
Tests/KXSFCoreTests/    deterministic core regression tests
project.yml             XcodeGen source of truth
Package.swift           Swift Package test entry point
```

`project.yml` is authoritative for the generated Xcode project, targets, bundle IDs, signing, capabilities, versions, and Info.plist metadata. Regenerate after changing it; do not hand-maintain generated `.xcodeproj` files.

## Official-content boundary

KXSF website and YouTube markup are external and can change without notice. The app therefore:

1. parses official content in `KXSFCore`, not inside SwiftUI views;
2. skips incomplete records rather than guessing data;
3. retries short-lived failures;
4. preserves a non-empty last-known-good official KXSF Live list; and
5. keeps an external link available when a remote source is unavailable.

Host names are deliberately not hard-coded. They are shown only when present in the official detail-page metadata or member markup.

## Local development

### Requirements

- macOS with Xcode/Xcode Beta that includes an iOS 18+ Simulator runtime
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) 2.46+
- An authorized Apple Developer account only for signed device/archive/TestFlight work

### Generate and open

```bash
xcodegen generate
open KXSF.xcodeproj
```

For an archive or device build, select the **San Francisco Community Radio Inc** team. Do not replace it with a personal team.

## Test and build

Run the deterministic core suite:

```bash
swift test
```

Build the iOS app and extension for an installed Simulator:

```bash
xcodebuild \
  -project KXSF.xcodeproj \
  -scheme KXSF \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=Pixel KXSF iPhone 17 Pro' \
  build
```

Run the iOS UI suite with a suitable installed simulator destination:

```bash
xcodebuild \
  -project KXSF.xcodeproj \
  -scheme KXSF \
  -destination 'platform=iOS Simulator,name=Pixel KXSF iPhone 17 Pro' \
  test
```

## Privacy, networking, and permissions

- KXSF does not declare tracking or collected-data categories in its privacy manifests.
- The app stores a small KXSF Live cache and shared widget/activity state in its App Group; the manifests declare the required UserDefaults reason (`CA92.1`).
- Network access is limited to KXSF’s official web content, official YouTube content, and the KXSF stream. The only non-HTTPS ATS exception is `stream.kxsf.fm`, because the verified audio endpoint uses HTTP.
- The app uses Apple-provided networking and media APIs and does not implement custom cryptography. `ITSAppUsesNonExemptEncryption` is set to `false` for the build metadata.

## Release checklist

Before TestFlight submission:

- Confirm the existing App Store Connect record uses `com.KXSF.fm`.
- Confirm `group.com.KXSF.fm` is provisioned for both the app and extension under San Francisco Community Radio Inc.
- Regenerate from `project.yml` and run the core + UI suites.
- Create a fresh signed archive, inspect the archived app and embedded extension metadata, then validate/upload through Xcode.
- Test live content, widgets, Live Activity, the logo fallback, and audio playback on physical hardware.

## History and attribution

The legacy V1 source/history is preserved separately at [iAhmedOT/KXSF-Legacy-V1](https://github.com/iAhmedOT/KXSF-Legacy-V1). This repository is the canonical V2 rebuild.

KXSF V2 application code is provided under the [MIT License](LICENSE) for this repository. KXSF station names, artwork, schedule information, and published videos remain the property of their respective owners and are retrieved only from official KXSF sources. See [docs/REPO-HISTORY.md](docs/REPO-HISTORY.md) for the clean-history note and legacy repo pointer.
