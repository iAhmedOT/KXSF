# KXSF Midnight Glass — Phase 0 Baseline

## Purpose

Preserve the shipped KXSF application as a verified reference before building the new Midnight Glass application. The rebuild will retain the product identity and validated radio behavior without inheriting the legacy UIKit/storyboard architecture by default.

## Source of truth

- Repository: `https://github.com/iAhmedOT/Swift-Radio-Pro`
- App Store baseline commit: `8e5a6edad710eb59a165fad01a91a2ae84624169`
- Durable baseline tag: `app-store-submission-2022-11-11`
- Rebuild branch: `rebuild/midnight-glass`
- Local workspace: `~/Dev/KXSF`

The commit message identifies `8e5a6ed` as the copy submitted to the App Store. Repository evidence supports that conclusion; App Store Connect build metadata has not yet been independently compared.

## Verified production identity

- Bundle identifier: `com.KXSF.fm`
- Display name: `KXSF 102.5FM`
- Configured station: `KXSF 102.5 FM`
- Current legacy stream source: `stream.kxsf.fm`

Secrets, signing credentials, and provisioning material must not be committed.

## Repository cleanup

The obsolete `iAhmedOT/KXSFApp` repository was permanently deleted at Ahmed's direction. It ended at shared commit `a78c259` and contained the generic Swift Radio sample identity and demo stations rather than the customized KXSF release history.

The three pre-rebuild uncommitted Xcode/storyboard changes were discarded at Ahmed's direction. The working tree was verified clean before this rebuild branch was created.

## Migration boundary

### Preserve or revalidate

- Approved KXSF logo and brand assets
- Bundle identifier and App Store identity
- Live stream endpoint and transport requirements
- Background audio behavior
- Lock-screen and Control Center controls
- Stream metadata behavior
- Audio interruption and route-change behavior
- Schedule/show data contracts once the current website source is inspected

### Rebuild rather than port by default

- UIKit view-controller hierarchy
- `Main.storyboard` navigation and layout
- Source-vendored `Spring` animation library
- Source-vendored `FRadioPlayer` integration
- Delegate-heavy shared UI/playback state
- Callback-style networking where modern structured concurrency is appropriate

Any legacy code reused later must earn its place through an explicit review and focused tests.

## Collaboration mode

Ahmed owns product direction, visual selection, architecture decisions, acceptance testing, and any hands-on work he chooses to perform. Pixel provides implementation, technical teaching, verification, and explicit attribution. Major decisions pause for Ahmed; reversible implementation details do not require unnecessary approval.

## Model-routing strategy

- **Terra:** default collaboration model for Phase 1 planning, routine SwiftUI implementation, tests, documentation, and ordinary debugging.
- **Sol:** escalation model for architecture decisions, difficult playback/concurrency failures, security/privacy review, App Store migration, and final release review.
- **Local Gemma 4 12B:** bounded worker for inventories, log summaries, draft documentation, repetitive transformations, and other low-risk tasks whose output is independently checked. Do not make it the global delegation default or allow it to perform destructive/publication actions without stronger-model review and real tests.

LM Studio is serving `google/gemma-4-12b` locally at `http://127.0.0.1:1234/v1`. Tool-calling reliability still needs a bounded read-only validation before Gemma receives repository work.

Hermes's installed pricing table lists Terra at half Sol's per-token API rates. The active provider is ChatGPT/Codex OAuth, whose weekly subscription-quota weighting is not documented by Hermes; switching to Terra should not be represented as a guaranteed 50% quota reduction.

## Phase 0 exit criteria

- [x] Identify the App Store source repository and baseline commit
- [x] Remove the confusing generic GitHub repository
- [x] Restore a clean local baseline
- [x] Push a durable App Store baseline tag
- [x] Create an isolated rebuild branch
- [x] Record preservation and migration boundaries
- [x] Decide the model-routing strategy for Sol, Terra, and local Gemma
- [x] Confirm Phase 1 product and platform constraints collaboratively
