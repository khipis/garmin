#!/usr/bin/env python3
"""Generate launcher_icon.png (70×70) for Dots & Boxes."""
from PIL import Image, ImageDraw
import os

SIZE = 70
OUT  = os.path.join(os.path.dirname(__file__),
                    "../dots_boxes/resources/launcher_icon.png")

img  = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# Dark circular background
draw.ellipse([0, 0, SIZE-1, SIZE-1], fill=(6, 6, 14, 255))

# Board: 4×4 grid of boxes (5×5 dots), step=12px, offset=7px
STEP  = 12
OFF   = 7
DOTS  = 5
DR    = 3     # dot radius
LW    = 2     # line width for drawn edges

def px(c): return OFF + c * STEP
def py(r): return OFF + r * STEP

# Sample board state (mid-game)
# Horizontal edges: h[r][c] = owner (0=open, 1=player, 2=AI)
H = [
    [1, 1, 0, 0],   # row 0
    [0, 1, 2, 0],   # row 1
    [1, 0, 2, 1],   # row 2
    [0, 2, 0, 0],   # row 3
    [0, 0, 2, 0],   # row 4
]
# Vertical edges: v[r][c] = owner
V = [
    [1, 0, 2, 0, 0],  # row 0
    [0, 1, 2, 0, 0],  # row 1
    [1, 1, 0, 2, 0],  # row 2
    [0, 0, 2, 0, 0],  # row 3
]
# Boxes (computed from H/V above — box(br,bc) complete if all 4 sides drawn)
# top=H[br][bc], bottom=H[br+1][bc], left=V[br][bc], right=V[br][bc+1]
BOXES_OWNER = [[0]*4 for _ in range(4)]
for br in range(4):
    for bc in range(4):
        if H[br][bc] and H[br+1][bc] and V[br][bc] and V[br][bc+1]:
            BOXES_OWNER[br][bc] = 1  # player

# Override a few boxes for visual variety
BOXES_OWNER[0][0] = 1   # player box top-left
BOXES_OWNER[1][1] = 1   # player box middle
BOXES_OWNER[2][2] = 2   # AI box
BOXES_OWNER[0][2] = 2   # AI box top-right area

PLAYER = (255,  34,   0)
AI     = (  0, 153, 255)
OPEN   = ( 27,  27,  43)

# Box fills
for br in range(4):
    for bc in range(4):
        owner = BOXES_OWNER[br][bc]
        if owner:
            fill = (34, 5, 0) if owner == 1 else (0, 21, 32)
            draw.rectangle([px(bc)+1, py(br)+1, px(bc+1)-1, py(br+1)-1], fill=fill)
            # Centre dot
            cx2 = (px(bc) + px(bc+1)) // 2
            cy2 = (py(br) + py(br+1)) // 2
            col = PLAYER if owner == 1 else AI
            draw.ellipse([cx2-3, cy2-3, cx2+3, cy2+3], fill=col)

# Guide lines (faint)
GUIDE = (28, 28, 44)
for r in range(DOTS):
    for c in range(4):
        draw.line([(px(c), py(r)), (px(c+1), py(r))], fill=GUIDE, width=1)
for r in range(4):
    for c in range(DOTS):
        draw.line([(px(c), py(r)), (px(c), py(r+1))], fill=GUIDE, width=1)

# Drawn edges
for r in range(DOTS):
    for c in range(4):
        owner = H[r][c]
        if owner:
            col = PLAYER if owner == 1 else AI
            draw.line([(px(c), py(r)), (px(c+1), py(r))], fill=col, width=LW)
for r in range(4):
    for c in range(DOTS):
        owner = V[r][c]
        if owner:
            col = PLAYER if owner == 1 else AI
            draw.line([(px(c), py(r)), (px(c), py(r+1))], fill=col, width=LW)

# Cursor highlight on h(2, 0) — open edge
draw.line([(px(0), py(2)-1), (px(1), py(2)-1)], fill=(255,255,0), width=1)
draw.line([(px(0), py(2)),   (px(1), py(2))  ], fill=(255,255,0), width=1)
draw.line([(px(0), py(2)+1), (px(1), py(2)+1)], fill=(255,255,0), width=1)

# Dots
for r in range(DOTS):
    for c in range(DOTS):
        draw.ellipse([px(c)-DR, py(r)-DR, px(c)+DR, py(r)+DR], fill=(90, 90, 122))

# Circular clip mask
mask = Image.new("L", (SIZE, SIZE), 0)
ImageDraw.Draw(mask).ellipse([0, 0, SIZE-1, SIZE-1], fill=255)
result = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
result.paste(img, mask=mask)

os.makedirs(os.path.dirname(OUT), exist_ok=True)
result.save(OUT)
print(f"Saved → {OUT}")
