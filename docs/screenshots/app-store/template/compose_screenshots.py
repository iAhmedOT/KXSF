#!/usr/bin/env python3
"""Compose KXSF App Store marketing screenshots using official Apple iPhone 17 Pro bezels."""

from __future__ import annotations

import argparse
import json
import math
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Union

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[3]  # docs/
SCREENSHOTS_DIR = Path(__file__).resolve().parents[2]  # docs/screenshots
APP_STORE_DIR = Path(__file__).resolve().parents[1]
OUT_DIR = APP_STORE_DIR / "exports"
FRAME_DIR = APP_STORE_DIR / "frames" / "apple-official"
FRAME_META_PATH = FRAME_DIR / "frame-meta.json"
DEFAULT_FRAME = FRAME_DIR / "iphone-17-pro-deep-blue-portrait.png"

# App Store Connect 6.5" display class (required when no 6.9" set is provided).
# Accepted portrait sizes: 1284×2778 or 1242×2688.
CANVAS_W = 1284
CANVAS_H = 2778

SIGNAL_RED = (181, 28, 36, 255)
SIGNAL_YELLOW = (242, 196, 26, 255)
WHITE = (255, 255, 255, 255)


@dataclass(frozen=True)
class Shot:
    id: str
    source: str
    eyebrow: str
    title: str
    subtitle: str


# Sources live in docs/screenshots/app-store/sources/ (clean RGB copies of
# Ahmed's latest iPhone 17 Pro captures).
SHOTS = [
    Shot(
        id="01-listen-live",
        source="listen-now-playing.png",
        eyebrow="KXSF 102.5 FM",
        title="Listen live",
        subtitle="Your San Francisco community radio, rebuilt.",
    ),
    Shot(
        id="02-shows-schedule",
        source="shows-schedule.png",
        eyebrow="OFFICIAL SCHEDULE",
        title="Know what's on",
        subtitle="Browse KXSF shows and the hosts behind them.",
    ),
    Shot(
        id="03-kxsf-live",
        source="kxsf-live.png",
        eyebrow="FROM THE STATION",
        title="Watch KXSF Live",
        subtitle="Latest sessions from the official KXSF channel.",
    ),
    Shot(
        id="04-keep-close",
        source="home-widgets-live.png",
        eyebrow="ALWAYS NEARBY",
        title="Keep KXSF close",
        subtitle="Now Playing on Home Screen and Lock Screen.",
    ),
]


def load_font(size: int, weight: str = "bold") -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = []
    if weight == "heavy":
        candidates += [
            "/System/Library/Fonts/Supplemental/Arial Black.ttf",
            "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
            "/System/Library/Fonts/Helvetica.ttc",
        ]
    if weight == "bold":
        candidates += [
            "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
            "/System/Library/Fonts/Supplemental/Helvetica Neue.ttc",
            "/System/Library/Fonts/Helvetica.ttc",
            "/Library/Fonts/Arial Bold.ttf",
        ]
    else:
        candidates += [
            "/System/Library/Fonts/Supplemental/Arial.ttf",
            "/System/Library/Fonts/Supplemental/Helvetica Neue.ttc",
            "/System/Library/Fonts/Helvetica.ttc",
            "/Library/Fonts/Arial.ttf",
        ]

    for path in candidates:
        p = Path(path)
        if not p.exists():
            continue
        try:
            if p.suffix.lower() == ".ttc":
                for index in (1, 0, 4, 2):
                    try:
                        return ImageFont.truetype(str(p), size=size, index=index)
                    except OSError:
                        continue
            return ImageFont.truetype(str(p), size=size)
        except OSError:
            continue
    return ImageFont.load_default()


def vertical_gradient(size: tuple[int, int], top: tuple[int, int, int], bottom: tuple[int, int, int]) -> Image.Image:
    w, h = size
    base = Image.new("RGB", size, top)
    top_r, top_g, top_b = top
    bot_r, bot_g, bot_b = bottom
    px = base.load()
    assert px is not None
    for y in range(h):
        t = y / max(h - 1, 1)
        r = int(top_r + (bot_r - top_r) * t)
        g = int(top_g + (bot_g - top_g) * t)
        b = int(top_b + (bot_b - top_b) * t)
        for x in range(w):
            px[x, y] = (r, g, b)
    return base.convert("RGBA")


def radial_glow(
    size: tuple[int, int],
    color: tuple[int, int, int],
    center: tuple[float, float],
    radius: float,
    alpha: int,
) -> Image.Image:
    w, h = size
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    cx, cy = center
    r, g, b = color
    px = layer.load()
    assert px is not None
    rad2 = radius * radius
    for y in range(h):
        dy = y - cy
        for x in range(w):
            dx = x - cx
            d2 = dx * dx + dy * dy
            if d2 > rad2:
                continue
            t = 1.0 - math.sqrt(d2) / radius
            t = t * t * (3 - 2 * t)
            a = int(alpha * t)
            if a > 0:
                px[x, y] = (r, g, b, a)
    return layer


def soft_noise(size: tuple[int, int], opacity: float = 0.05) -> Image.Image:
    seed = Image.effect_noise((size[0] // 3, size[1] // 3), 28).convert("L")
    seed = seed.resize(size, Image.Resampling.BILINEAR)
    alpha = int(255 * opacity)
    noise = Image.new("RGBA", size, (255, 255, 255, 0))
    px = noise.load()
    sp = seed.load()
    assert px is not None and sp is not None
    for y in range(size[1]):
        for x in range(size[0]):
            v = int(sp[x, y])
            if v > 140:
                px[x, y] = (255, 255, 255, alpha)
            elif v < 90:
                px[x, y] = (0, 0, 0, alpha // 2)
    return noise


FontLike = Union[ImageFont.ImageFont, ImageFont.FreeTypeFont]


def wrap_text(draw: ImageDraw.ImageDraw, text: str, font: FontLike, max_width: int) -> list[str]:
    words = text.split()
    if not words:
        return [""]
    lines: list[str] = []
    current = words[0]
    for word in words[1:]:
        trial = f"{current} {word}"
        if draw.textlength(trial, font=font) <= max_width:
            current = trial
        else:
            lines.append(current)
            current = word
    lines.append(current)
    return lines


def font_line_height(font: FontLike, sample: str = "Ag") -> int:
    try:
        ascent, descent = font.getmetrics()  # type: ignore[attr-defined]
        measured = int(ascent + abs(descent))
        if measured >= 8:
            return measured
    except Exception:
        pass
    try:
        bbox = font.getbbox(sample)  # type: ignore[attr-defined]
        measured = int(bbox[3] - bbox[1])
        if measured >= 8:
            return measured
    except Exception:
        pass
    bbox = ImageDraw.Draw(Image.new("RGB", (8, 8))).textbbox((0, 0), sample, font=font)
    return max(int(bbox[3] - bbox[1]), 12)


def text_block(
    draw: ImageDraw.ImageDraw,
    text: str,
    font: FontLike,
    fill: tuple[int, int, int, int],
    center_x: int,
    top: int,
    max_width: int,
    line_gap: int,
) -> int:
    lines = wrap_text(draw, text, font, max_width)
    y = top
    line_height = font_line_height(font)
    for line in lines:
        width = float(draw.textlength(line, font=font))
        x = int(center_x - width / 2)
        draw.text((x, y + 2), line, font=font, fill=(0, 0, 0, 140))
        draw.text((x, y), line, font=font, fill=fill)
        y += line_height + line_gap
    return int(y)


def load_frame_assets() -> tuple[Image.Image, tuple[int, int, int, int], dict]:
    if not DEFAULT_FRAME.exists():
        raise FileNotFoundError(
            f"Official Apple frame missing: {DEFAULT_FRAME}\n"
            "Download Bezel-iPhone-17.dmg from Apple Design Resources and extract the "
            "iPhone 17 Pro Deep Blue Portrait PNG into frames/apple-official/."
        )
    meta = {}
    if FRAME_META_PATH.exists():
        meta = json.loads(FRAME_META_PATH.read_text(encoding="utf-8"))
    frame = Image.open(DEFAULT_FRAME).convert("RGBA")
    if meta.get("screenBBox"):
        sx, sy, ex, ey = meta["screenBBox"]
        screen_box = (int(sx), int(sy), int(ex), int(ey))
    else:
        # Fallback measure: transparent center flood bounds already known for this asset.
        screen_box = (72, 69, 1277, 2690)
    return frame, screen_box, meta


def resolve_source(shot: Shot) -> Path:
    candidates = [
        APP_STORE_DIR / "sources" / shot.source,
        SCREENSHOTS_DIR / shot.source,
        SCREENSHOTS_DIR / "raw" / shot.source,
    ]
    for path in candidates:
        if path.exists():
            return path
    raise FileNotFoundError(
        f"Missing source for {shot.id}: {shot.source} (checked sources/ and screenshots/)"
    )


def screen_hole_mask(frame: Image.Image, screen_box: tuple[int, int, int, int]) -> Image.Image:
    """Opaque mask for the true screen cutout only (not exterior transparent pixels)."""
    from collections import deque

    w, h = frame.size
    alpha = frame.getchannel("A")
    a = alpha.load()
    assert a is not None

    sx, sy, ex, ey = screen_box
    # Seed from the known screen center — exterior transparency must not be included.
    seed_x = (sx + ex) // 2
    seed_y = (sy + ey) // 2
    if a[seed_x, seed_y] != 0:
        # Fallback: first transparent pixel inside the measured screen box.
        seed = None
        for y in range(sy, ey + 1, 2):
            for x in range(sx, ex + 1, 2):
                if a[x, y] == 0:
                    seed = (x, y)
                    break
            if seed:
                break
        if seed is None:
            # Last resort: filled rect of the measured screen box.
            mask = Image.new("L", (w, h), 0)
            draw = ImageDraw.Draw(mask)
            draw.rectangle((sx, sy, ex, ey), fill=255)
            return mask
        seed_x, seed_y = seed

    visited = set()
    q = deque([(seed_x, seed_y)])
    visited.add((seed_x, seed_y))
    while q:
        x, y = q.popleft()
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if nx < 0 or ny < 0 or nx >= w or ny >= h:
                continue
            if (nx, ny) in visited:
                continue
            if a[nx, ny] != 0:
                continue
            visited.add((nx, ny))
            q.append((nx, ny))

    mask = Image.new("L", (w, h), 0)
    mp = mask.load()
    assert mp is not None
    for x, y in visited:
        mp[x, y] = 255
    return mask


def make_official_device(screen: Image.Image, frame: Image.Image, screen_box: tuple[int, int, int, int]) -> Image.Image:
    """Composite capture into Apple's transparent screen cutout, then overlay the official bezel."""
    sx, sy, ex, ey = screen_box
    screen_w = ex - sx + 1
    screen_h = ey - sy + 1

    capture = screen.convert("RGBA")
    if capture.size != (screen_w, screen_h):
        capture = capture.resize((screen_w, screen_h), Image.Resampling.LANCZOS)

    # Soft shadow under the official hardware silhouette only.
    shadow = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    alpha = frame.getchannel("A")
    shadow_mask = alpha.point([0 if i <= 8 else 180 for i in range(256)])
    shadow_body = Image.new("RGBA", frame.size, (0, 0, 0, 255))
    shadow.paste(shadow_body, (0, 0), shadow_mask)
    shadow = shadow.filter(ImageFilter.GaussianBlur(34))

    canvas = Image.new("RGBA", (frame.width + 48, frame.height + 70), (0, 0, 0, 0))
    canvas.alpha_composite(shadow, (24, 42))

    # Paste capture full-frame, then keep ONLY the true screen hole.
    # (A raw rectangle bleeds wallpaper through transparent pixels outside the rounded phone.)
    capture_layer = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    capture_layer.paste(capture, (sx, sy))
    hole = screen_hole_mask(frame, screen_box)
    masked_capture = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    masked_capture.paste(capture_layer, (0, 0), hole)

    # Official Apple bezel on top — hardware chrome, Dynamic Island, materials.
    device = Image.alpha_composite(masked_capture, frame)
    canvas.alpha_composite(device, (24, 12))
    return canvas


def compose(shot: Shot, frame: Image.Image, screen_box: tuple[int, int, int, int]) -> Image.Image:
    source_path = resolve_source(shot)
    raw = Image.open(source_path).convert("RGB")

    # Background — Midnight Glass, titles above the official device.
    bg = vertical_gradient((CANVAS_W, CANVAS_H), (10, 10, 10), (2, 2, 2))
    glow_scale = 3
    glow_size = (CANVAS_W // glow_scale, CANVAS_H // glow_scale)
    red = radial_glow(glow_size, (181, 28, 36), (glow_size[0] * 0.18, glow_size[1] * 0.14), glow_size[0] * 0.55, 120)
    yellow = radial_glow(glow_size, (242, 196, 26), (glow_size[0] * 0.88, glow_size[1] * 0.16), glow_size[0] * 0.42, 70)
    orange = radial_glow(glow_size, (255, 120, 31), (glow_size[0] * 0.72, glow_size[1] * 0.92), glow_size[0] * 0.50, 48)
    for layer in (red, yellow, orange):
        layer = layer.resize((CANVAS_W, CANVAS_H), Image.Resampling.LANCZOS)
        bg = Image.alpha_composite(bg, layer)

    grain = soft_noise((CANVAS_W // 2, CANVAS_H // 2), opacity=0.045).resize(
        (CANVAS_W, CANVAS_H), Image.Resampling.BILINEAR
    )
    bg = Image.alpha_composite(bg, grain)

    vignette = Image.new("RGBA", (CANVAS_W, CANVAS_H), (0, 0, 0, 0))
    vdraw = ImageDraw.Draw(vignette)
    for i in range(90):
        a = int(90 * (i / 90) ** 1.6)
        vdraw.rectangle((i, i, CANVAS_W - 1 - i, CANVAS_H - 1 - i), outline=(0, 0, 0, a))
    bg = Image.alpha_composite(bg, vignette)

    draw = ImageDraw.Draw(bg)
    center_x = CANVAS_W // 2

    eyebrow_font = load_font(26, weight="bold")
    title_font = load_font(78, weight="heavy")
    subtitle_font = load_font(30, weight="regular")
    footer_font = load_font(20, weight="bold")

    y = 96
    y = text_block(draw, shot.eyebrow.upper(), eyebrow_font, SIGNAL_YELLOW, center_x, y, 980, 10)
    y += 16
    y = text_block(draw, shot.title, title_font, WHITE, center_x, y, 980, 8)
    y += 14
    y = text_block(draw, shot.subtitle, subtitle_font, (255, 255, 255, 190), center_x, y, 900, 8)

    framed = make_official_device(raw, frame, screen_box)

    # Fit official hardware fully under the copy block.
    top_limit = y + 34
    bottom_limit = CANVAS_H - 78
    max_h = max(bottom_limit - top_limit, 400)
    max_w = CANVAS_W - 48
    scale = min(max_w / framed.width, max_h / framed.height)
    new_size = (
        max(1, int(framed.width * scale)),
        max(1, int(framed.height * scale)),
    )
    framed = framed.resize(new_size, Image.Resampling.LANCZOS)

    device_x = (CANVAS_W - framed.width) // 2
    device_y = top_limit + max(0, (max_h - framed.height) // 8)
    # Prefer keeping the full phone visible; nudge up only if needed.
    if device_y + framed.height > bottom_limit:
        device_y = bottom_limit - framed.height
    bg.alpha_composite(framed, (device_x, max(device_y, 0)))

    footer = "SAN FRANCISCO COMMUNITY RADIO"
    fw = draw.textlength(footer, font=footer_font)
    draw.text(((CANVAS_W - fw) / 2, CANVAS_H - 56), footer, font=footer_font, fill=(255, 255, 255, 80))

    flattened = bg.convert("RGB")
    flattened = ImageEnhance.Contrast(flattened).enhance(1.03)
    flattened = ImageEnhance.Color(flattened).enhance(1.04)
    return flattened


def main() -> None:
    parser = argparse.ArgumentParser(description="Render KXSF iPhone 17 Pro App Store screenshots")
    parser.add_argument("--only", help="Filter by id/title/source substring")
    args = parser.parse_args()

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    frame, screen_box, frame_meta = load_frame_assets()

    selected = []
    for shot in SHOTS:
        if not args.only:
            selected.append(shot)
            continue
        key = args.only.lower()
        if key in shot.id.lower() or key in shot.title.lower() or key in shot.source.lower():
            selected.append(shot)
    if not selected:
        raise SystemExit(f"No shots matched --only {args.only}")

    results = []
    for shot in selected:
        print(f"Rendering {shot.id} with official Apple iPhone 17 Pro bezel...")
        image = compose(shot, frame, screen_box)
        out_path = OUT_DIR / f"{shot.id}.png"
        image.save(out_path, format="PNG", optimize=True)
        assert image.size == (CANVAS_W, CANVAS_H), image.size
        assert image.mode == "RGB", image.mode
        print(f"  -> {out_path} ({image.size[0]}x{image.size[1]}, {out_path.stat().st_size} bytes)")
        results.append(
            {
                "id": shot.id,
                "file": str(out_path.relative_to(ROOT)),
                "title": shot.title,
                "subtitle": shot.subtitle,
                "source": shot.source,
                "frame": frame_meta.get("frameFile", DEFAULT_FRAME.name),
                "width": image.size[0],
                "height": image.size[1],
            }
        )

    manifest = {
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "canvas": {"width": CANVAS_W, "height": CANVAS_H},
        "device": "iPhone 17 Pro hardware frame on 6.5-inch App Store slot",
        "displayClass": "6.5-inch",
        "acceptedSizes": ["1284x2778", "1242x2688"],
        "frameSource": "Apple Design Resources — Bezel-iPhone-17.dmg",
        "frameColor": frame_meta.get("color", "Deep Blue"),
        "template": "docs/screenshots/app-store/template/compose_screenshots.py",
        "notes": [
            "Official Apple iPhone 17 Pro product bezel (not custom drawn).",
            "Export targets App Store Connect 6.5-inch accepted size 1284×2778 RGB.",
            "Title sits above the device frame.",
            "Final PNG is flattened RGB with no alpha channel.",
            "KXSF Midnight Glass canvas + accents retained around official hardware.",
        ],
        "shots": results,
    }
    manifest_path = OUT_DIR / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {manifest_path}")


if __name__ == "__main__":
    main()
