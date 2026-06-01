#!/usr/bin/env python3
"""Generate a 40x40 isometric tile + ball launcher icon (RGBA PNG)."""
from PIL import Image, ImageDraw
import os

SIZE = 40
img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
d   = ImageDraw.Draw(img)

# Sky background — soft cyan-violet gradient.
for y in range(SIZE):
    t = y / float(SIZE - 1)
    r = int(28  + (110 - 28)  * t)
    g = int(54  + (160 - 54)  * t)
    b = int(120 + (220 - 120) * t)
    d.line((0, y, SIZE, y), fill=(r, g, b, 255))

cx, cy = SIZE // 2, SIZE // 2 + 4

# Isometric tile (diamond).
hw, hh = 16, 8
top    = (cx,      cy - hh)
right  = (cx + hw, cy)
bottom = (cx,      cy + hh)
left   = (cx - hw, cy)
d.polygon([top, right, bottom, left], fill=(245, 245, 235, 255))
# Side faces (thickness) — dark band underneath.
d.polygon([bottom, right, (cx + hw, cy + 4), (cx, cy + hh + 4)], fill=(120, 120, 110, 255))
d.polygon([bottom, left,  (cx - hw, cy + 4), (cx, cy + hh + 4)], fill=(90,  90,  80,  255))
# Tile top accent line.
d.line([top, right], fill=(200, 200, 180, 255))
d.line([top, left],  fill=(220, 220, 210, 255))

# Ball — light blue with highlight.
ball_cx, ball_cy = cx, cy - 4
br = 6
d.ellipse((ball_cx - br, ball_cy - br, ball_cx + br, ball_cy + br),
          fill=(220, 230, 250, 255), outline=(120, 150, 200, 255))
d.ellipse((ball_cx - 2, ball_cy - 3, ball_cx, ball_cy - 1),
          fill=(255, 255, 255, 255))
# Ball shadow on the tile.
d.ellipse((ball_cx - 5, cy + 1, ball_cx + 5, cy + 4),
          fill=(70, 80, 110, 180))

here = os.path.dirname(os.path.abspath(__file__))
img.save(os.path.join(here, "resources", "launcher_icon.png"))
print("Wrote", os.path.join(here, "resources", "launcher_icon.png"))
