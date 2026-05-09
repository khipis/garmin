#!/usr/bin/env python3
"""Generate launcher_icon.png (70×70) for Connect Four Lite."""
from PIL import Image, ImageDraw
import os

SIZE = 70
OUT  = os.path.join(os.path.dirname(__file__),
                    "../connect_four_lite/resources/launcher_icon.png")

img  = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# Dark circular background
draw.ellipse([0, 0, SIZE-1, SIZE-1], fill=(8, 8, 22, 255))

# 7×6 board (mini) — fit inside the circle
COLS, ROWS = 7, 6
M = 5          # margin
cw = (SIZE - 2*M) // COLS   # cell width ≈ 8 px
ch = (SIZE - 2*M) // ROWS   # cell height ≈ 10 px
bw = COLS * cw
bh = ROWS * ch
bx = (SIZE - bw) // 2
by = (SIZE - bh) // 2

# Board background
draw.rectangle([bx-1, by-1, bx+bw, by+bh], fill=(10, 24, 80))

# Discs — replicate a mid-game state
board = [
    [0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0],
    [0, 0, 1, 0, 0, 0, 0],
    [0, 0, 2, 1, 0, 0, 0],
    [0, 1, 2, 2, 1, 0, 0],
    [2, 2, 1, 2, 1, 2, 1],
]

PLAYER_COL = (255, 34,  0)
AI_COL     = (255, 204, 0)
EMPTY_COL  = (16,  16, 40)

for r in range(ROWS):
    for c in range(COLS):
        cx = bx + c * cw + cw // 2
        cy = by + r * ch + ch // 2
        rad = min(cw, ch) // 2 - 1
        mark = board[r][c]
        if   mark == 1: fill = PLAYER_COL
        elif mark == 2: fill = AI_COL
        else:           fill = EMPTY_COL
        draw.ellipse([cx-rad, cy-rad, cx+rad, cy+rad], fill=fill)

# Winning diagonal hint (bottom-left rising)
win_cells = [(5,0),(4,1),(3,2),(2,3)]
for (r,c) in win_cells:
    cx = bx + c * cw + cw // 2; cy = by + r * ch + ch // 2
    rad = min(cw, ch) // 2 - 1
    draw.ellipse([cx-rad-1, cy-rad-1, cx+rad+1, cy+rad+1], outline=(0, 255, 85), width=1)

# Circular clip
mask = Image.new("L", (SIZE, SIZE), 0)
ImageDraw.Draw(mask).ellipse([0, 0, SIZE-1, SIZE-1], fill=255)
result = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
result.paste(img, mask=mask)

os.makedirs(os.path.dirname(OUT), exist_ok=True)
result.save(OUT)
print(f"Saved → {OUT}")
