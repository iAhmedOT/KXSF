# Listen Screen — Midnight Glass

## Intent

A live radio player should feel immediate at a glance in a dark room: the official KXSF mark is the visual anchor, while playback status and the Play/Pause control remain unmistakable.

## Composition

1. **Top signal chip:** small live indicator plus `San Francisco`—not a second logo.
2. **Hero mark:** official square KXSF Community Radio logo at a stable, generous size. Never recolor, crop, or put text over the mark.
3. **Status panel:** one dark glass surface. It communicates state first, then a concise supporting sentence.
4. **Primary control:** a 96 pt Play/Pause control. On iOS 26 it uses the native Glass button treatment; on iOS 18–25 it uses the accessible fallback.
5. **Ambient field:** near-black charcoal ground with restrained radial red/yellow illumination behind—not on—the official asset.

## Tokens

- `canvas`: `#050505`
- `surface`: white at 10–14% opacity over a dark material
- `primary text`: `#F7F7F2`
- `secondary text`: white at 66% opacity
- `signal red`: `#B51C24`
- `signal yellow`: `#F2C51A`
- `border`: white at 14% opacity
- radii: 28 pt surfaces, 48 pt play control
- spacing: 8 / 16 / 24 / 32 / 48 pt

## Motion

- A single slow ambient gradient shift is permitted only while playback is active.
- Motion must be disabled or static when Reduce Motion is enabled.
- No bouncing, looping logo animation, or layout-shifting press effect.

## Anti-patterns

- Do not use generic `KXSF` text in place of the actual mark.
- Do not spread glass cards across the whole screen.
- Do not render orange/indigo branding from generic recommendations.
- Do not claim a specific song or host until real metadata is available.
- Do not use the wide station image as the hero; its aspect/content is unsuitable here.
