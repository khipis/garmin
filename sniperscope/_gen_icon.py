#!/usr/bin/env python3
"""Generate a 40x40 sniper-scope launcher icon (RGBA PNG)."""
from PIL import Image, ImageDraw
import os

SIZE = 40
img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
d = ImageDraw.Draw(img)

cx, cy = SIZE // 2, SIZE // 2
R_OUT = 18
R_IN  = 16

d.ellipse((cx - R_OUT, cy - R_OUT, cx + R_OUT, cy + R_OUT),
          fill=(8, 14, 8, 255), outline=(40, 60, 30, 255))
d.ellipse((cx - R_IN, cy - R_IN, cx + R_IN, cy + R_IN),
          fill=(18, 32, 18, 255), outline=(120, 170, 90, 255))

d.line((cx - R_IN + 2, cy, cx - 3, cy), fill=(220, 230, 200, 255), width=1)
d.line((cx + 3, cy, cx + R_IN - 2, cy), fill=(220, 230, 200, 255), width=1)
d.line((cx, cy - R_IN + 2, cx, cy - 3), fill=(220, 230, 200, 255), width=1)
d.line((cx, cy + 3, cx, cy + R_IN - 2), fill=(220, 230, 200, 255), width=1)

for k in range(1, 4):
    yy = cy + k * 3
    if yy < cy + R_IN - 2:
        d.line((cx - 2, yy, cx + 2, yy), fill=(180, 210, 160, 255), width=1)

d.ellipse((cx - 1, cy - 1, cx + 1, cy + 1), fill=(255, 100, 80, 255))

here = os.path.dirname(os.path.abspath(__file__))
img.save(os.path.join(here, "resources", "launcher_icon.png"))
print("Wrote", os.path.join(here, "resources", "launcher_icon.png"))
