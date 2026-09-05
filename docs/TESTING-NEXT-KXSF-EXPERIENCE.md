# KXSF Midnight Glass — Ahmed’s acceptance checklist

## Build provided

**Device:** Pixel KXSF iPhone 17 Pro / iOS 27 Simulator
**Status:** Installed and launched after a regenerated XcodeGen build.
**Automated evidence:** 18/18 core tests, Listen launch/control UI test, and navigation UI test passed.

This is an acceptance pass. Please send screenshots for any visual issue—especially safe-area, Live Activity, or widget behavior.

## 1. Listen

1. Launch **KXSF**.
2. Confirm the logo has comfortable top spacing.
3. Tap Play and watch the status surface:
   - During startup: **CONNECTING** / “Connecting to KXSF…”
   - Once playback is real: **NOW PLAYING**, official artwork, show title, host/DJ when KXSF provides it, and time.
4. Pause and confirm the control/state do not still claim playback.

## 2. Shows

1. Open **Shows**.
2. Confirm nothing begins under the clock/Dynamic Island.
3. Confirm the local current weekday is expanded first; open another weekday and confirm every show appears.
4. Confirm time is a separate line, and host/DJ appears only when KXSF’s official detail page supplies it—never a generic “KXSF host.”
5. Open a show/archive link. It should remain in the in-app Safari sheet; dismiss it and return to the app.

## 3. KXSF Live

1. Open **KXSF Live** (the former Calendar tab).
2. Confirm top-safe-area clearance.
3. Confirm cards have no upload-date subtitle.
4. Open a video and confirm it uses the in-app Safari sheet.

## 4. Live Activity

1. Start playback, leave the app, and view the Live Activity/Dynamic Island.
2. Confirm it is artwork-led and shows the current program.
3. Pause/resume from the control; confirm the glyph and audio state agree.

## 5. Home Screen widget

1. Add **KXSF Now Playing** in both small and medium sizes.
2. Confirm the artwork-led card, show title, time, and single state-specific control are legible.
3. Start/pause playback and wait briefly for WidgetKit refresh.
4. Confirm the icon changes **play ↔ pause** only after the app’s actual player state changes.

## Reply format

```text
Listen: [good / change]
Shows: [good / change]
KXSF Live: [good / change]
Live Activity: [worked / change]
Widget: [small / medium / both], [worked / change]
```
