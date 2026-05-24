#!/usr/bin/env python3
"""40x40 launcher icon: mini Kakuro grid w/ clue + digits."""
from PIL import Image, ImageDraw

S = 40
img = Image.new('RGBA', (S, S), (8, 12, 28, 255))
d = ImageDraw.Draw(img)
d.ellipse((1, 1, S - 2, S - 2), fill=(14, 22, 40, 255))

# 3x3 mini grid with one clue cell at top-left.
GS = 4                  # 4x4 grid
cell = 7
pad  = (S - cell * GS) // 2

def cell_xy(r, c):
    return pad + c * cell, pad + r * cell

# Black/clue cells: row 0 + col 0
for r in range(GS):
    for c in range(GS):
        x, y = cell_xy(r, c)
        if r == 0 or c == 0:
            d.rectangle((x, y, x + cell, y + cell), fill=(20, 28, 44, 255), outline=(80, 100, 130, 255))
            # diagonal clue marker on (0,1)/(0,2)/(0,3) and (1,0)/(2,0)/(3,0)
            if r == 0 and c > 0:
                d.line((x, y, x + cell, y + cell), fill=(120, 160, 200, 255))
            if c == 0 and r > 0:
                d.line((x, y, x + cell, y + cell), fill=(120, 160, 200, 255))
        else:
            d.rectangle((x, y, x + cell, y + cell), fill=(240, 240, 240, 255), outline=(50, 50, 50, 255))

# Highlight one cell.
hx, hy = cell_xy(2, 2)
d.rectangle((hx, hy, hx + cell, hy + cell), fill=(255, 230, 100, 255), outline=(180, 130, 0, 255))

img.save("/Users/kkorolczuk/work/garmin/kakuro/resources/launcher_icon.png", "PNG")
print("ok")
