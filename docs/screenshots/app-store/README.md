# KXSF App Store screenshots

This pipeline places real app captures inside official Apple iPhone 17 Pro bezels and renders the marketing images used for the 2.0 submission.

## Export format

The 2.0 screenshot set uses a **1284 × 2778** portrait canvas for the 6.5-inch slot. Exports are PNG files in **RGB with no alpha**. Native iPhone 17 Pro source captures are `1206 × 2622`.

The recorded submission requirements also allowed `1242 × 2688` portrait images and landscape versions of either size. Check App Store Connect's requirements before preparing a future set rather than assuming the same slot rules still apply.

## Files

```text
docs/screenshots/
  app-store/
    sources/                   RGB app captures
    frames/apple-official/     Apple bezel assets and license
    template/
      compose_screenshots.py   Primary renderer
    exports/
      01-listen-live.png
      02-shows-schedule.png
      03-kxsf-live.png
      04-keep-close.png
      manifest.json
```

## Screens in the set

1. **Listen live:** `sources/listen-now-playing.png`
2. **Know what's on:** `sources/shows-schedule.png`
3. **Watch KXSF Live:** `sources/kxsf-live.png`
4. **Keep KXSF close:** `sources/home-widgets-live.png`

Two additional captures are available in `sources/`: `about-kxsf.png` and `lock-screen-live-activity.png`.

## Render

From the repository root:

```bash
cd docs/screenshots/app-store/template
python3 compose_screenshots.py
```

Review the exports before upload. Make sure the app capture fits the device's screen cutout, the copy matches the submitted build, and the files retain the required dimensions and color mode.

## Apple frame assets

The original Apple pack is available at:

<https://devimages-cdn.apple.com/design/resources/download/Bezel-iPhone-17.dmg>

The default frame is `frames/apple-official/iphone-17-pro-deep-blue-portrait.png`. Its measured screen cutout is `1206 × 2622`.

Follow Apple's Design Resources and marketing guidelines. The included `frames/apple-official/Apple-Design-Resources-License.rtf` governs use of the bezel artwork; this README does not grant additional redistribution rights.
