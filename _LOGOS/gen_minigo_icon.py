#!/usr/bin/env python3
"""Generate launcher_icon.png (70×70) for Mini Go 9x9."""
from PIL import Image, ImageDraw, ImageFont
import os

SIZE = 70
OUT  = os.path.join(os.path.dirname(__file__),
                    "../mini_go_9x9/resources/launcher_icon.png")

img  = Image.new("RGBA", (SIZE, SIZE), (26, 18, 8, 255))
draw = ImageDraw.Draw(img)

# Board background (wood)
M = 6
draw.rectangle([M, M, SIZE-M, SIZE-M], fill=(200, 160, 64))

# Grid (4×4 mini for legibility)
CELLS = 4; STEP = (SIZE - 2*M) // CELLS; OX = M + STEP // 2; OY = M + STEP // 2
for i in range(CELLS):
    lx = OX + i * STEP; ly = OY + i * STEP
    draw.line([(lx, OY), (lx, OY + (CELLS-1)*STEP)], fill=(90, 60, 20), width=1)
    draw.line([(OX, ly), (OX + (CELLS-1)*STEP, ly)], fill=(90, 60, 20), width=1)

# Star centre
draw.ellipse([OX + STEP - 2, OY + STEP - 2, OX + STEP + 2, OY + STEP + 2],
             fill=(70, 45, 15))

# Stones
def stone(cx, cy, col):
    r = STEP // 2 - 2
    if col == 'B':
        draw.ellipse([cx-r, cy-r, cx+r, cy+r], fill=(20, 20, 20))
        draw.ellipse([cx-r+2, cy-r+2, cx-r+5, cy-r+5], fill=(70, 70, 70))
    else:
        draw.ellipse([cx-r, cy-r, cx+r, cy+r], fill=(230, 230, 230))
        draw.ellipse([cx-r, cy-r, cx+r, cy+r], outline=(130, 130, 130))
        draw.ellipse([cx-r+2, cy-r+2, cx-r+5, cy-r+5], fill=(255, 255, 255))

stone(OX,           OY,           'B')
stone(OX + STEP,    OY + STEP,    'W')
stone(OX + 2*STEP,  OY,           'W')
stone(OX + STEP,    OY + 2*STEP,  'B')
stone(OX + 3*STEP,  OY + STEP,    'B')
stone(OX + 2*STEP,  OY + 2*STEP,  'W')
stone(OX + 3*STEP,  OY + 3*STEP,  'B')

# Cursor hint
cx2 = OX + 3*STEP; cy2 = OY + 2*STEP
r2 = STEP // 2 - 1
draw.rectangle([cx2-r2, cy2-r2, cx2+r2, cy2+r2], outline=(0, 200, 60), width=1)

os.makedirs(os.path.dirname(OUT), exist_ok=True)
img.save(OUT)
print(f"Saved → {OUT}")
