# KXSF Midnight Glass — Navigation Checkpoint

> **Superseded on 2026-08-27:** the current shell was verified clean on an iPhone 17 Pro/iOS 27 Simulator. See `CHECKPOINT-2026-08-27-SIMULATOR-VERIFIED.md` and `screenshots/kxsf-listen-iphone17pro-ios27.png`.

**Date:** 2026-08-22  
**Branch:** `rebuild/midnight-glass`  
**Checkpoint intent:** preserve the current work and stop visual iteration safely.

## What is working

- The canonical KXSF stream remains verified: `http://stream.kxsf.fm:8000/sfcr`.
- The app shell contains four destinations:
  - Listen
  - Shows
  - Calendar
  - About
- Shows, Calendar, and About are implemented as station-content destinations.
- About includes official external links for `https://kxsf.fm/` and `https://kxsf.fm/support/`.
- Live-show support is isolated behind `LiveShowStore` and `KXSFLiveShowParser`; it falls back honestly to **Live on KXSF** if official schedule parsing is unavailable.
- The official KXSF logo asset remains unchanged.

## Last approved visual reference

Ahmed approved the **Larger Listen V3** composition:

```text
/tmp/kxsf-listen-larger-v3.png
```

Its design intent:

```text
large official logo
24pt vertical rhythm
Ready to listen card
24pt vertical rhythm
large Play control
```

Do **not** treat `V7`, `V8`, or `V9` larger-listen screenshots as approved baselines. They are layout experiments with overlap/clipping defects.

## Current source state

`App/Sources/ListenView.swift` has been restored to the V3-style simple vertical layout:

```swift
VStack(spacing: 24) {
    logo // 280 × 280
    statusPanel
    playbackControl // 108 × 108
}
```

It intentionally has **no**:

- `layoutOffset`
- `navigationTop`
- manual Listen-page `.position(...)`
- geometry-driven status-card height guesses

`App/Sources/ContentView.swift` currently owns the separate floating navigation capsule. Its integration with the Listen content rectangle is unfinished: the most recent restore render still lets the capsule overlap the lower Listen content.

## Current visual artifact

```text
/tmp/kxsf-listen-restored-v3.png
```

This is **not approved**. It shows the restored simple Listen stack but still has the floating nav covering the lower part of the status-card/player region.

## Resume safely

1. Keep `ListenView` as the simple V3 `VStack`; do not reintroduce manual offsets or local absolute positioning.
2. Treat `/tmp/kxsf-listen-larger-v3.png` as the visual reference to reproduce.
3. Solve navigation in `ContentView` only. The nav must reserve or overlay space without changing the internal coordinates of logo/card/player.
4. Capture a screenshot after every structural navigation change.
5. Do not name a new version “approved” until the screenshot is visibly clean and Play remains tappable.
6. Rerun simulator UI tests after the visual layout is clean; the prior navigation changes need regression verification.

## Important honesty notes

- The worktree includes uncommitted navigation/content additions and generated Xcode project changes.
- The build that produced `/tmp/kxsf-listen-restored-v3.png` succeeded.
- The restored screen is not visually accepted yet; no claim of completed navbar integration should be made.
