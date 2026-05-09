#!/usr/bin/env python3
"""Generate launcher_icon.png (70×70) for Tic Tac Pro."""
from PIL import Image, ImageDraw
import os

SIZE = 70
OUT  = os.path.join(os.path.dirname(__file__),
                    "../tic_tac_pro/resources/launcher_icon.png")

img  = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# Circular dark background
draw.ellipse([0, 0, SIZE-1, SIZE-1], fill=(8, 8, 16, 255))

# 3×3 visible grid lines (5x5 grid, show inner portion)
M  = 8; GS = (SIZE - 2*M) // 5  # ~10-11px per cell
BW = 5 * GS

for i in range(6):
    lx = M + i*GS; ly = M + i*GS
    draw.line([(lx, M), (lx, M+BW)], fill=(60, 60, 90), width=1)
    draw.line([(M, ly), (M+BW, ly)], fill=(60, 60, 90), width=1)

# Draw X marks (blue)
def draw_x(gx, gy):
    cx = M + gx*GS + GS//2; cy = M + gy*GS + GS//2
    hc = GS * 33 // 100
    for d in [0, 1]:
        draw.line([(cx-hc+d, cy-hc), (cx+hc+d, cy+hc)], fill=(0, 170, 255), width=2)
        draw.line([(cx+hc+d, cy-hc), (cx-hc+d, cy+hc)], fill=(0, 170, 255), width=2)

# Draw O marks (red-orange)
def draw_o(gx, gy):
    cx = M + gx*GS + GS//2; cy = M + gy*GS + GS//2
    r = GS * 33 // 100
    draw.ellipse([cx-r, cy-r, cx+r, cy+r], outline=(255, 68, 34), width=2)

draw_x(0, 0); draw_x(2, 1); draw_x(1, 3); draw_x(3, 4)
draw_o(1, 0); draw_o(0, 2); draw_o(3, 1); draw_o(4, 3)

# Winning line highlight
for (gx, gy) in [(0,0),(1,1),(2,2),(3,3)]:
    cx = M + gx*GS + GS//2; cy = M + gy*GS + GS//2
    draw.ellipse([cx-3, cy-3, cx+3, cy+3], fill=(0, 255, 68, 180))

draw.line([(M + GS//2, M + GS//2), (M + 3*GS + GS//2, M + 3*GS + GS//2)],
          fill=(0, 255, 68, 200), width=2)

# Circular clip
mask = Image.new("L", (SIZE, SIZE), 0)
ImageDraw.Draw(mask).ellipse([0, 0, SIZE-1, SIZE-1], fill=255)
result = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
result.paste(img, mask=mask)

os.makedirs(os.path.dirname(OUT), exist_ok=True)
result.save(OUT)
print(f"Saved → {OUT}")
