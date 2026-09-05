#!/usr/bin/env python3
"""Prepare the KXSF launch poster asset catalog imageset."""

from pathlib import Path

from PIL import Image, ImageOps

SRC = Path("/Users/ahmedalotaibi/.hermes/profiles/pixel/cache/images/img_449d6c8251d7.jpg")
OUT_DIR = Path("/Users/ahmedalotaibi/Dev/KXSF/App/Assets.xcassets/LaunchPoster.imageset")
DOCS = Path("/Users/ahmedalotaibi/Dev/KXSF/docs/assets")


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    DOCS.mkdir(parents=True, exist_ok=True)

    for stale in OUT_DIR.glob("LaunchPoster*"):
        if stale.suffix.lower() in {".jpg", ".jpeg", ".png"}:
            stale.unlink()

    poster = ImageOps.exif_transpose(Image.open(SRC)).convert("RGB")
    print(f"source {poster.size}")

    # Keep natural poster aspect. The in-app splash uses scaledToFit.
    scales = {
        "LaunchPoster.jpg": 714,
        "LaunchPoster@2x.jpg": 1428,
        "LaunchPoster@3x.jpg": 2142,
    }
    for name, width in scales.items():
        ratio = width / poster.width
        height = int(round(poster.height * ratio))
        resized = poster.resize((width, height), Image.Resampling.LANCZOS)
        path = OUT_DIR / name
        resized.save(path, format="JPEG", quality=92, optimize=True, progressive=True)
        print(f"{name} {resized.size} {path.stat().st_size}")

    canonical = DOCS / "kxsf-8th-anniversary-fundraiser-launch-poster.jpg"
    if not canonical.exists() or canonical.stat().st_size != SRC.stat().st_size:
        canonical.write_bytes(SRC.read_bytes())
    print(f"canonical {canonical}")


if __name__ == "__main__":
    main()
