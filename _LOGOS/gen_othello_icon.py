#!/usr/bin/env python3
"""Generate launcher_icon.png (70×70) for Othello Blitz."""
from PIL import Image, ImageDraw, ImageFont
import os

SIZE = 70
OUT  = os.path.join(os.path.dirname(__file__),
                    "../othello_blitz/resources/launcher_icon.png")

img  = Image.new("RGBA", (SIZE, SIZE), (10, 18, 10, 255))
draw = ImageDraw.Draw(img)

# Circular mask
from PIL import ImageFilter
mask = Image.new("L", (SIZE, SIZE), 0)
ImageDraw.Draw(mask).ellipse([0, 0, SIZE-1, SIZE-1], fill=255)

# Green board background (circle)
draw.ellipse([0, 0, SIZE-1, SIZE-1], fill=(26, 122, 26))

# 8×8 grid lines (4×4 visible area in centre)
M  = 8      # board margin
GS = (SIZE - 2*M) // 8   # grid step ≈ 6.75 → 6

# Draw 9 vertical + 9 horizontal lines
for i in range(9):
    x = M + i * GS; y = M + i * GS
    draw.line([(x, M), (x, M + 8*GS)], fill=(13, 90, 13), width=1)
    draw.line([(M, y), (M + 8*GS, y)], fill=(13, 90, 13), width=1)

# Discs in classic starting position + a few more for visual interest
DR = GS // 2 - 1  # disc radius

def disc(gx, gy, col):
    cx = M + gx * GS + GS // 2
    cy = M + gy * GS + GS // 2
    if col == 'B':
        draw.ellipse([cx-DR, cy-DR, cx+DR, cy+DR], fill=(15, 15, 15))
        draw.ellipse([cx-DR+1, cy-DR+1, cx-DR+3, cy-DR+3], fill=(55, 55, 55))
    else:
        draw.ellipse([cx-DR, cy-DR, cx+DR, cy+DR], fill=(220, 220, 220))
        draw.ellipse([cx-DR, cy-DR, cx+DR, cy+DR], outline=(130, 130, 130))
        draw.ellipse([cx-DR+1, cy-DR+1, cx-DR+3, cy-DR+3], fill=(255, 255, 255))

# Starting 4 discs
disc(3, 3, 'W'); disc(4, 3, 'B'); disc(3, 4, 'B'); disc(4, 4, 'W')
# A few more for a game-in-progress look
disc(2, 3, 'B'); disc(5, 3, 'W'); disc(3, 2, 'W'); disc(4, 5, 'B')
disc(5, 4, 'B'); disc(2, 4, 'W')

# Apply circular clip
result = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
result.paste(img, mask=mask)

os.makedirs(os.path.dirname(OUT), exist_ok=True)
result.save(OUT)
print(f"Saved → {OUT}")
