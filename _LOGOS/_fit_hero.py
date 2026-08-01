#!/usr/bin/env python3
"""Fit generated key art to the 1440x720 (2:1) store hero.

The image models top out at 16:9, so something has to give. Growing the sides
looks like a panel glued onto the art — the fill duplicates recognisable
features and the brightness step shows. Fitting to the full width and trimming
the height costs only 11% off a 16:9 frame, and these layouts put nothing
critical in the top and bottom slivers.

Usage:
  _fit_hero.py <slug> <keyart.png> [--bias 0.5]   ->  _LOGOS/<slug>_hero.png

--bias picks which part of the excess height to drop: 0.0 keeps the top of the
frame, 1.0 keeps the bottom, 0.5 trims evenly.
"""
from __future__ import annotations

import argparse
import os

from PIL import Image

W, H = 1440, 720
LOGOS = os.path.dirname(os.path.abspath(__file__))


def fit(src_path: str, bias: float) -> Image.Image:
    src = Image.open(src_path).convert("RGB")
    scaled_h = int(round(src.height * W / src.width))
    if scaled_h >= H:
        img = src.resize((W, scaled_h), Image.LANCZOS)
        top = int((scaled_h - H) * bias)
        return img.crop((0, top, W, top + H))

    # Wider than 2:1 — fit the height and trim the sides instead.
    scaled_w = int(round(src.width * H / src.height))
    img = src.resize((scaled_w, H), Image.LANCZOS)
    left = (scaled_w - W) // 2
    return img.crop((left, 0, left + W, H))


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("slug")
    p.add_argument("art")
    p.add_argument("--bias", type=float, default=0.5)
    a = p.parse_args()
    out = os.path.join(LOGOS, f"{a.slug}_hero.png")
    fit(a.art, a.bias).save(out, "PNG")
    print("wrote", out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
