#!/usr/bin/env python3
"""40x40 launcher icon: bulb on yellow cell over black wall checker."""
from PIL import Image, ImageDraw

S = 40
img = Image.new('RGBA', (S, S), (10, 8, 12, 255))
d = ImageDraw.Draw(img)
d.ellipse((1, 1, S - 2, S - 2), fill=(18, 14, 22, 255))

# Mini Akari grid: 3x3 with center yellow lit, surrounded by checker
# of black walls and cream cells.
CS = 8
W = CS * 3
OX = (S - W) // 2
OY = (S - W) // 2

PAT = [
    ['Y', 'B', 'L'],   # Y = yellow lit + bulb, B = black wall, L = lit white
    ['L', 'L', 'B'],
    ['B', 'L', 'Y'],
]

def cell_color(t):
    if t == 'B':   return (0, 0, 0, 255), (60, 60, 60, 255)
    if t == 'L':   return (255, 241, 160, 255), (60, 40, 0, 255)
    return (255, 241, 160, 255), (60, 40, 0, 255)  # 'Y'

for r in range(3):
    for c in range(3):
        x = OX + c * CS
        y = OY + r * CS
        fill, outline = cell_color(PAT[r][c])
        d.rectangle((x, y, x + CS - 1, y + CS - 1),
                    fill=fill, outline=outline)

# Bulb glyph in center cell.
cx = OX + CS + CS // 2
cy = OY + CS + CS // 2
d.ellipse((cx - 3, cy - 3, cx + 3, cy + 2),
          fill=(255, 220, 60, 255), outline=(80, 50, 0, 255))
d.rectangle((cx - 1, cy + 2, cx + 2, cy + 4),
            fill=(60, 50, 30, 255), outline=(20, 10, 0, 255))

img.save("/Users/kkorolczuk/work/garmin/akari/resources/launcher_icon.png", "PNG")
print("ok")
