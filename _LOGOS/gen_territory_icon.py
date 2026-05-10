#!/usr/bin/env python3
"""Generate Territory Clash launcher icon (70x70)."""
from PIL import Image, ImageDraw
import os, shutil

SIZE = 70
img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
d   = ImageDraw.Draw(img)

# Rounded-square background (dark green)
def rr(draw, xy, r, fill):
    x0, y0, x1, y1 = xy
    draw.rectangle([x0+r, y0, x1-r, y1], fill=fill)
    draw.rectangle([x0, y0+r, x1, y1-r], fill=fill)
    draw.ellipse([x0, y0, x0+2*r, y0+2*r], fill=fill)
    draw.ellipse([x1-2*r, y0, x1, y0+2*r], fill=fill)
    draw.ellipse([x0, y1-2*r, x0+2*r, y1], fill=fill)
    draw.ellipse([x1-2*r, y1-2*r, x1, y1], fill=fill)

rr(d, (0, 0, 69, 69), 10, (10, 30, 10, 255))

# Wood-colour board area
rr(d, (8, 8, 61, 61), 4, (200, 144, 76, 255))

# 4x4 sub-grid (representing 9x9 look)
N = 4
step = 53 // (N - 1)
ox, oy = 8, 8
for i in range(N):
    d.line([(ox + i*step, oy), (ox + i*step, oy + 53)], fill=(100, 60, 15), width=1)
    d.line([(ox, oy + i*step), (ox + 53, oy + i*step)], fill=(100, 60, 15), width=1)

# Stones
stones = [
    (ox + 0*step, oy + 0*step, "B"),
    (ox + 1*step, oy + 1*step, "W"),
    (ox + 0*step, oy + 1*step, "B"),
    (ox + 1*step, oy + 0*step, "W"),
    (ox + 2*step, oy + 2*step, "B"),
    (ox + 3*step, oy + 1*step, "B"),
    (ox + 2*step, oy + 3*step, "W"),
    (ox + 3*step, oy + 3*step, "W"),
]
r = 9
for (sx, sy, col) in stones:
    if col == "B":
        d.ellipse([sx-r, sy-r, sx+r, sy+r], fill=(20, 20, 20, 230))
    else:
        d.ellipse([sx-r, sy-r, sx+r, sy+r], fill=(240, 240, 240, 230),
                  outline=(80, 80, 80, 200))

out_dir = os.path.dirname(__file__)
icon_src = os.path.join(out_dir, "territory_icon.png")
img.save(icon_src)
print(f"Saved {icon_src}")

res_dir = os.path.join(out_dir, "..", "territory_clash", "resources")
os.makedirs(res_dir, exist_ok=True)
dst = os.path.join(res_dir, "launcher_icon.png")
shutil.copy(icon_src, dst)
print(f"Copied to {dst}")
