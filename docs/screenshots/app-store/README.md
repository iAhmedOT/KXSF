# KXSF App Store Screenshots

Marketing screenshot pipeline for App Store Connect using **official Apple iPhone 17 Pro bezels**.

## Target slot

App Store Connect currently expects one of these **6.5″** sizes when no 6.9″ set is provided:

- **1284 × 2778** (portrait) ← this pipeline’s default
- **1242 × 2688** (portrait)
- landscape swaps of either

Format: PNG, **RGB, no alpha**.

Source captures remain native iPhone 17 Pro (`1206 × 2622`) and are placed inside Apple’s official product bezel, then composed onto the 6.5″ marketing canvas.

## Folder layout

```text
docs/screenshots/
  raw/                         # original Simulator dumps
  app-store/
    sources/                   # clean RGB copies of latest captures
    frames/apple-official/     # official Apple Design Resources bezels (local only)
    template/
      compose_screenshots.py   # primary renderer
    exports/
      01-listen-live.png
      02-shows-schedule.png
      03-kxsf-live.png
      04-keep-close.png
      manifest.json
```

## Shot list

1. **Listen live** → `listen-now-playing.png`
2. **Know what's on** → `shows-schedule.png`
3. **Watch KXSF Live** → `kxsf-live.png`
4. **Keep KXSF close** → `home-widgets-live.png`

Spares staged in sources:

- `about-kxsf.png`
- `lock-screen-live-activity.png`

## Render

```bash
cd docs/screenshots/app-store/template
python3 compose_screenshots.py
```

## Frame source

Official Apple pack:

`https://devimages-cdn.apple.com/design/resources/download/Bezel-iPhone-17.dmg`

Default hardware art:

- `frames/apple-official/iphone-17-pro-deep-blue-portrait.png`
- screen cutout measured at `1206 × 2622` inside the bezel

Follow Apple’s Design Resources / marketing guidelines for bezel usage. Do not redistribute the official bezel art outside local project use.
