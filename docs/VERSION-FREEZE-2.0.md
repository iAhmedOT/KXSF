# KXSF version freeze

## 2.0 — frozen (2026-09-05)

- **State:** Submitted to App Store Connect; awaiting Apple review.
- **Toolchain:** Public Xcode 26.6 (`17F113`), not Xcode 27 beta.
- **Version/build:** `2.0 (1)`
- **Bundle:** `com.KXSF.fm` / extension `com.KXSF.fm.liveactivities`
- **Team:** San Francisco Community Radio Inc (`Y7PURZ5849`)
- **Local tip at freeze:** `ebe04ae` (source polish + official-bezel screenshot set)
- **Do not** add features, copy changes, or packaging tweaks intended for the already-submitted binary into this line.

## 2.1 — open for future work

Anything requested after App Store submission (new features, non-critical polish, experiments) starts a **2.1** track:

1. Bump `MARKETING_VERSION` to `2.1` in `project.yml` (and regenerate if required).
2. Bump `CURRENT_PROJECT_VERSION` as needed for the new upload.
3. Keep 2.0 branch/tag history intact for the submitted package.

Until 2.1 is intentionally opened, default agent behavior is: **no KXSF feature work on the frozen 2.0 package.**
