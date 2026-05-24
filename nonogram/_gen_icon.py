#!/usr/bin/env python3
"""40x40 launcher icon: pixel-art reveal (5x5 grid, half-filled)."""
from PIL import Image, ImageDraw

S = 40
img = Image.new('RGBA', (S, S), (5, 8, 15, 255))
d = ImageDraw.Draw(img)
d.ellipse((1, 1, S - 2, S - 2), fill=(10, 18, 30, 255))

# 5x5 reveal pattern: a small heart-like shape — fits the "reveal"
# theme of nonograms.
PAT = [
    [0, 1, 1, 0, 1],
    [1, 1, 1, 1, 1],
    [1, 1, 1, 1, 1],
    [0, 1, 1, 1, 0],
    [0, 0, 1, 0, 0],
]

# Grid geometry: 5 cells of 6 px, centered.
CS = 6
W = CS * 5
OX = (S - W) // 2
OY = (S - W) // 2

# Background frame for the grid.
d.rectangle((OX - 1, OY - 1, OX + W, OY + W), outline=(60, 90, 130, 255))

for r in range(5):
    for c in range(5):
        x = OX + c * CS
        y = OY + r * CS
        if PAT[r][c]:
            d.rectangle((x + 1, y + 1, x + CS - 2, y + CS - 2),
                        fill=(255, 200, 40, 255))
        else:
            d.rectangle((x + 1, y + 1, x + CS - 2, y + CS - 2),
                        fill=(20, 32, 50, 255),
                        outline=(40, 60, 90, 255))

img.save("/Users/kkorolczuk/work/garmin/nonogram/resources/launcher_icon.png", "PNG")
print("ok")
