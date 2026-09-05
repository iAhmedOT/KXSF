# KXSF Midnight Glass — Phase 1 Listen First

## Goal

Ship the smallest trustworthy vertical slice of the rebuilt KXSF app:

```text
launch → tap Play → hear KXSF → continue in background
```

Shows, schedules, calendars, and other website content are intentionally deferred until live playback is verified.

## Product constraints

- Minimum deployment target: iOS 18
- Native Liquid Glass where available on iOS 26+
- Deliberate Midnight Glass material fallback on iOS 18–25
- iPhone-first layouts that remain adaptable for a later iPad experience
- Preserve the approved KXSF logo and App Store identity
- No account, analytics, advertising, or user-data collection in this slice

## Verified stream

Canonical legacy endpoint:

```text
http://stream.kxsf.fm:8000/sfcr
```

Live probe results:

- HTTP response: `200 OK`
- Content type: `audio/mpeg`
- Codec: MP3
- Sample rate: 44.1 kHz
- Channels: stereo
- Bitrate: 128 kbps

The endpoint does not currently provide a working HTTPS route. KXSF's official Listen page also documents that its source stream is unencrypted.

## Transport decision

Use a domain-scoped App Transport Security exception for `stream.kxsf.fm`. Do not enable unrestricted arbitrary loads.

The exception exists only to receive KXSF's public audio broadcast. No credentials, user data, or privileged API traffic may use the insecure route. Recommend that KXSF add HTTPS; remove the exception when a verified secure source is available.

## Architecture boundary

Playback receives its endpoint through an interface rather than hardcoding it across the app:

```swift
protocol StreamEndpointProviding: Sendable {
    var liveStreamURL: URL { get }
}
```

Initial implementation:

```swift
struct DirectKXSFEndpoint: StreamEndpointProviding {
    let liveStreamURL = URL(string: "http://stream.kxsf.fm:8000/sfcr")!
}
```

A future HTTPS station endpoint or managed proxy should replace only this provider. Playback state, UI, tests, and remote controls should not need to change.

## Smallest system model

```text
Play button
    ↓
Playback model/state
    ↓
Audio player service
    ↓
Endpoint provider
    ↓
KXSF MP3 stream
```

The UI observes state but does not own `AVPlayer`, configure the audio session, or know transport details.

## Playback states

```swift
enum PlaybackState: Equatable {
    case idle
    case loading
    case playing
    case paused
    case failed(PlaybackFailure)
}
```

The implementation must not present indefinite loading as success. Failures need a visible retry path and useful diagnostics during development.

## Acceptance criteria

### Foreground

- App launches into the Listen screen without requiring network access to render
- Tapping Play enters loading and then playing state
- Audible KXSF audio is produced on a real device
- Tapping Pause stops playback and updates the interface
- A failed or unavailable stream produces a retryable error state
- Repeated Play taps do not create duplicate players or overlapping streams

### Background and system integration

- Playback continues after locking the device
- Playback continues when the app enters the background
- Control Center and lock-screen Play/Pause commands work
- Now Playing identifies KXSF without inventing unavailable track metadata
- Audio interruptions and route changes do not leave false playing state

### Quality

- Unit tests cover playback state transitions without requiring the real stream
- One integration check validates the configured endpoint shape and transport policy
- VoiceOver labels the primary playback control clearly
- Touch targets meet platform guidance
- Reduced Motion removes nonessential animation
- No unrestricted ATS exception is present
- Debug logs contain no secrets or personal data

## Explicitly deferred

- Shows catalog
- Weekly schedule and calendar
- Current-show API integration
- Show artwork and descriptions
- Favorites, notifications, accounts, analytics, and donations
- HTTPS proxy infrastructure
- iPad-specific layouts

## Collaboration checkpoint

Before substantial implementation, Ahmed should be able to explain why the endpoint provider is separate from the audio service: transport can change without forcing playback and UI rewrites.
