#!/usr/bin/env python3
"""Generate launcher_icon.png (70×70) for Morris Classic."""
from PIL import Image, ImageDraw
import os, math

SIZE = 70
OUT  = os.path.join(os.path.dirname(__file__),
                    "../morris_classic/resources/launcher_icon.png")

img  = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# Dark circular background
draw.ellipse([0, 0, SIZE-1, SIZE-1], fill=(6, 6, 14, 255))

# Board grid: step=10, offset=5  →  nodes at 5 + gx*10, 5 + gy*10
STEP = 10
OFF  = 5

# Node grid positions (gx, gy) for all 24 nodes
GX = [0,3,6, 1,3,5, 2,3,4, 0,1,2, 4,5,6, 2,3,4, 1,3,5, 0,3,6]
GY = [0,0,0, 1,1,1, 2,2,2, 3,3,3, 3,3,3, 4,4,4, 5,5,5, 6,6,6]

def nx(i): return OFF + GX[i] * STEP
def ny(i): return OFF + GY[i] * STEP

LINE_COL = (40, 40, 64)

# Draw board lines
edges = [
    (0,1),(1,2),(2,14),(14,23),(23,22),(22,21),(21,9),(9,0),      # outer
    (3,4),(4,5),(5,13),(13,20),(20,19),(19,18),(18,10),(10,3),    # middle
    (6,7),(7,8),(8,12),(12,17),(17,16),(16,15),(15,11),(11,6),    # inner
    (1,4),(4,7),(14,13),(13,12),(22,19),(19,16),(9,10),(10,11),   # cross
]
for a, b in edges:
    draw.line([(nx(a), ny(a)), (nx(b), ny(b))], fill=LINE_COL, width=1)

# Sample position — player has a vertical mill (0,9,21) on left column
PLAYER = (255, 34,   0)
AI     = (  0, 153, 255)
EMPTY  = ( 22,  22,  40)
RAD = 3

player_nodes = {0, 9, 21, 1, 10}     # mill on left + extras
ai_nodes     = {2, 14, 23, 4, 13}    # right column + centre
mill_nodes   = {0, 9, 21}            # player mill — glow orange

for i in range(24):
    px, py = nx(i), ny(i)
    if i in mill_nodes:
        fill = (255, 85, 0)          # bright mill highlight
    elif i in player_nodes:
        fill = PLAYER
    elif i in ai_nodes:
        fill = AI
    else:
        fill = EMPTY
    r = RAD + 1 if i in mill_nodes else RAD
    draw.ellipse([px-r, py-r, px+r, py+r], fill=fill)

# Mill glow ring on the left-column mill nodes
for i in mill_nodes:
    px, py = nx(i), ny(i)
    draw.ellipse([px-RAD-2, py-RAD-2, px+RAD+2, py+RAD+2],
                 outline=(255, 200, 0), width=1)

# Circular clip mask
mask = Image.new("L", (SIZE, SIZE), 0)
ImageDraw.Draw(mask).ellipse([0, 0, SIZE-1, SIZE-1], fill=255)
result = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
result.paste(img, mask=mask)

os.makedirs(os.path.dirname(OUT), exist_ok=True)
result.save(OUT)
print(f"Saved → {OUT}")
