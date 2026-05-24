#!/usr/bin/env python3
"""Resize Kakuro hero to 1440x720."""
from PIL import Image
import os

SRC = "/Users/kkorolczuk/.cursor/projects/Users-kkorolczuk-work-garmin/assets/kakuro_hero_raw.png"
DST = "/Users/kkorolczuk/work/garmin/_LOGOS/kakuro_hero.png"

im = Image.open(SRC).convert("RGB")
w, h = im.size

target_aspect = 2.0
current_aspect = w / h
if current_aspect < target_aspect:
    new_h = int(w / target_aspect)
    top = max(0, (h - new_h) // 2)
    box = (0, top, w, top + new_h)
else:
    new_w = int(h * target_aspect)
    left = max(0, (w - new_w) // 2)
    box = (left, 0, left + new_w, h)
im2 = im.crop(box).resize((1440, 720), Image.LANCZOS)
os.makedirs(os.path.dirname(DST), exist_ok=True)
im2.save(DST, "PNG", optimize=True)
print("saved", DST, im2.size)
