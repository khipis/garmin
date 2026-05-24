#!/usr/bin/env python3
"""Crops + resizes the generated DiceRoyale hero to exactly 1440x720.

The generator returns ~1024x1024.  We center-crop to a 2:1 aspect and
then scale up to 1440x720 (preserves the watch-left / title-right layout).
"""

from PIL import Image
import os

SRC = "/Users/kkorolczuk/.cursor/projects/Users-kkorolczuk-work-garmin/assets/diceroyale_hero_raw.png"
DST = "/Users/kkorolczuk/work/garmin/_LOGOS/diceroyale_hero.png"

im = Image.open(SRC).convert("RGB")
w, h = im.size

# Crop to 2:1 aspect ratio.  Symmetric horizontal crop, slightly larger
# bottom crop so the "BY BITOCHI" text stays visible inside the frame.
target_aspect = 2.0
current_aspect = w / h
if current_aspect < target_aspect:
    new_h = int(w / target_aspect)
    top = max(0, (h - new_h) // 2 - 20)  # bias up — keep title visible
    box = (0, top, w, top + new_h)
else:
    new_w = int(h * target_aspect)
    left = max(0, (w - new_w) // 2)
    box = (left, 0, left + new_w, h)
im2 = im.crop(box)
im2 = im2.resize((1440, 720), Image.LANCZOS)

os.makedirs(os.path.dirname(DST), exist_ok=True)
im2.save(DST, "PNG", optimize=True)
print("saved", DST, im2.size)
