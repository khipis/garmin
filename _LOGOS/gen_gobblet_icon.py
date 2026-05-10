#!/usr/bin/env python3
"""Generate launcher_icon.png (70×70) for Gobblet Mini."""
from PIL import Image, ImageDraw
import os

SIZE = 70
OUT  = os.path.join(os.path.dirname(__file__),
                    "../gobblet_mini/resources/launcher_icon.png")

img  = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# Dark circular background
draw.ellipse([0, 0, SIZE-1, SIZE-1], fill=(6, 6, 14, 255))

# 4×4 grid: step=14px, offset=7px
STEP = 14; OFF = 7
PLAYER = (255,  34,   0)
AI     = (  0, 153, 255)
BG     = (  6,   6,  14)

def cx(c): return OFF + c * STEP + STEP // 2
def cy(r): return OFF + r * STEP + STEP // 2

# Faint grid lines
GRID = (30, 30, 50)
for r in range(5):
    draw.line([(OFF, OFF+r*STEP), (OFF+4*STEP, OFF+r*STEP)], fill=GRID, width=1)
    draw.line([(OFF+r*STEP, OFF), (OFF+r*STEP, OFF+4*STEP)], fill=GRID, width=1)

# Sample board state: show nested pieces visually
# (size-3 AI gobbles player size-2 at (0,0))
def piece(r, c, col, rad, inner=False):
    x, y = cx(c), cy(r)
    draw.ellipse([x-rad-1, y-rad-1, x+rad+1, y+rad+1], fill=BG)
    draw.ellipse([x-rad, y-rad, x+rad, y+rad], fill=col)
    if inner and rad > 3:
        ir = rad * 38 // 100
        draw.ellipse([x-ir, y-ir, x+ir, y+ir], fill=BG)

# AI large piece covering player piece at (0,0)
piece(0, 0, AI,     6, inner=True)   # size-4 AI
piece(0, 1, PLAYER, 5, inner=True)   # size-3 player
piece(0, 2, AI,     4, inner=True)   # size-2 AI
piece(0, 3, PLAYER, 3)               # size-1 player

piece(1, 0, PLAYER, 5, inner=True)
piece(1, 1, AI,     4, inner=True)
piece(1, 2, PLAYER, 3)
piece(1, 3, AI,     6, inner=True)   # large AI top-right area

piece(2, 0, AI,     3)
piece(2, 1, PLAYER, 4, inner=True)
piece(2, 2, AI,     5, inner=True)
piece(2, 3, PLAYER, 4, inner=True)

piece(3, 1, AI,     3)
piece(3, 2, PLAYER, 5, inner=True)

# Yellow cursor ring on (1, 3)
x, y = cx(3), cy(1)
draw.rectangle([OFF+3*STEP+1, OFF+1*STEP+1, OFF+4*STEP-1, OFF+2*STEP-1],
               outline=(255, 221, 0), width=1)

# Circular mask
mask = Image.new("L", (SIZE, SIZE), 0)
ImageDraw.Draw(mask).ellipse([0, 0, SIZE-1, SIZE-1], fill=255)
result = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
result.paste(img, mask=mask)

os.makedirs(os.path.dirname(OUT), exist_ok=True)
result.save(OUT)
print(f"Saved → {OUT}")
