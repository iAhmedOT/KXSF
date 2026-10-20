# KXSF

The native iOS app for **KXSF 102.5 FM, San Francisco Community Radio**.

Listen live, check the station's schedule, and browse videos from its official YouTube channel. KXSF V2 is a SwiftUI rebuild of the earlier UIKit app. It keeps the existing app identity, `com.KXSF.fm`, and adds widgets and Live Activities for playback and show information.

## Release status

This repository's `main` branch contains the 2.0 application source. The recorded 2.0 submission used Xcode 26.6 with the `iphoneos26.5` SDK and was accepted for review. That submission record does not establish Apple's current review status.

**The submitted 2.0 app is frozen.** Product changes belong on the 2.1 development line. Documentation updates do not change the submitted binary. See [the version freeze](docs/VERSION-FREEZE-2.0.md).

- App: `com.KXSF.fm`
- Live Activity extension: `com.KXSF.fm.liveactivities`
- Version and build: `2.0 (1)`
- Minimum deployment target: iOS 18.0
- Signing team: San Francisco Community Radio Inc (`Y7PURZ5849`)
- Local release artifacts: `build/KXSF-2.0.xcarchive` and `build/export/KXSF.ipa`
- Screenshot exports: [docs/screenshots/app-store/exports](docs/screenshots/app-store/exports), 1284 × 2778 RGB

## In the app

- **Listen:** Live radio through `AVPlayer`, with background audio and separate ready, connecting, playing, and failed states.
- **Shows:** Current and upcoming programming from the official KXSF schedule pages. Host credits appear when the station supplies them.
- **KXSF Live:** Recent uploads from [the station's YouTube channel](https://www.youtube.com/@kxsfradio/videos), with bounded retries and a last-known-good local cache.
- **Widgets and Live Activities:** Shared playback and schedule state, with locally cached show artwork. Non-square artwork is center-cropped; missing or invalid artwork falls back to the KXSF logo.

The deep link `kxsf://listen` opens Listen.

## How it works

```text
Official KXSF website and YouTube channel
                   ↓
            KXSFCore parsers
                   ↓
            LiveShowStore
                   ↓
 SwiftUI screens + KXSFAppCoordinator + AVPlayer
                   ↓
     App Group snapshot and artwork cache
                   ↓
           WidgetKit / ActivityKit
```

The schedule and video lists come from parsing the official website and YouTube page markup, not a dedicated station content API. `KXSFCore` handles HTML entity decoding, whitespace cleanup, schedule suffix removal, and parsing of supported YouTube renderer variants.

Those pages can change. Parsers skip incomplete records, retry temporary failures, and retain a non-empty cached KXSF Live list when a refresh fails. Host names are read from official show metadata or member blocks rather than hard-coded. External links let listeners open the original content.

### Source layout

```text
App/
  Sources/              SwiftUI screens, player, coordinator, content store
  Shared/               App Group state, design system, artwork bridge
  LiveActivity/         WidgetKit and ActivityKit extension
  UITests/              iOS UI regression tests
Sources/KXSFCore/        Parsers, models, retries, cache and artwork policies
Tests/KXSFCoreTests/     Core regression tests
project.yml             XcodeGen configuration
Package.swift           Swift Package test entry point
```

`project.yml` defines targets, bundle IDs, signing, capabilities, versions, and Info.plist metadata. Regenerate the Xcode project after changing it rather than editing the generated project by hand.

## Build and test

You need macOS, Xcode with a compatible iOS Simulator runtime, and [XcodeGen](https://github.com/yonaskolb/XcodeGen) 2.46 or later. Signed device builds and distribution also require an authorized Apple Developer account.

```bash
xcodegen generate
open KXSF.xcodeproj
```

Run the core tests:

```bash
swift test
```

List the available destinations:

```bash
xcodebuild -project KXSF.xcodeproj -scheme KXSF -showdestinations
```

Set `SIMULATOR_ID` to an available iOS Simulator UUID from that output, then build or run the UI tests:

```bash
xcodebuild \
  -project KXSF.xcodeproj \
  -scheme KXSF \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=${SIMULATOR_ID:?Set SIMULATOR_ID first}" \
  build

xcodebuild \
  -project KXSF.xcodeproj \
  -scheme KXSF \
  -destination "platform=iOS Simulator,id=${SIMULATOR_ID:?Set SIMULATOR_ID first}" \
  test
```

For signed device builds or archives, use the **San Francisco Community Radio Inc** team, not a personal team.

## Privacy and networking

The app and extension include privacy manifests. They do not declare tracking or collected-data categories. The manifests include the UserDefaults reason `CA92.1` for local state storage.

The app fetches station web content, official YouTube content, and the live stream. Its only non-HTTPS ATS exception is `stream.kxsf.fm`, because the audio endpoint uses HTTP. It uses Apple's networking and media APIs without custom cryptography; the build metadata sets `ITSAppUsesNonExemptEncryption` to `false`.

## Before a release

- Keep the existing App Store Connect identity, `com.KXSF.fm`.
- Check that `group.com.KXSF.fm` is provisioned for the app and extension under the station's signing team.
- Regenerate the project and run the core and UI tests.
- Create a signed archive, inspect the app and embedded extension metadata, then validate and upload through Xcode.
- Test playback, live content, widgets, Live Activities, and artwork fallback on physical hardware.

## History and attribution

[iAhmedOT/KXSF](https://github.com/iAhmedOT/KXSF) is the canonical V2 repository. The V1 source and history remain separate at [KXSF-Legacy-V1](https://github.com/iAhmedOT/KXSF-Legacy-V1). See [the repository history note](docs/REPO-HISTORY.md) for context.

The V2 application code is available under the [MIT License](LICENSE). Station names, artwork, schedule information, and videos belong to their respective owners. The app retrieves that content from official KXSF sources.
