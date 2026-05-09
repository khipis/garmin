#!/usr/bin/env python3
"""Generate launcher_icon.png (70×70) for Hex Mini."""
from PIL import Image, ImageDraw
import os, math

SIZE = 70
OUT  = os.path.join(os.path.dirname(__file__),
                    "../hex_mini/resources/launcher_icon.png")

img  = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# Dark circular background
draw.ellipse([0, 0, SIZE-1, SIZE-1], fill=(6, 6, 14, 255))

# Draw a 5×5 hex grid (offset parallelogram layout) inside the circle
N  = 5
DX = 11   # horizontal spacing
DY = 10   # vertical spacing  (≈ DX * sqrt(3)/2)
RAD = 4

# Centre the board: bounding box width = (N-1)*DX + (N-1)*(DX//2) = 4*11+4*5 = 64 → boardX=3
BOARD_X = (SIZE - (N-1)*DX - (N-1)*(DX//2)) // 2
BOARD_Y = (SIZE - (N-1)*DY) // 2

def cx(r, c): return BOARD_X + c * DX + r * (DX // 2)
def cy(r, c): return BOARD_Y + r * DY

# Draw grid lines
for r in range(N):
    for c in range(N):
        px, py = cx(r, c), cy(r, c)
        if c + 1 < N:
            draw.line([(px, py), (cx(r, c+1), cy(r, c+1))], fill=(42, 42, 68), width=1)
        if r + 1 < N and c - 1 >= 0:
            draw.line([(px, py), (cx(r+1, c-1), cy(r+1, c-1))], fill=(42, 42, 68), width=1)
        if r + 1 < N:
            draw.line([(px, py), (cx(r+1, c), cy(r+1, c))], fill=(42, 42, 68), width=1)

# Sample mid-game board: player (Red) has a left-right connection attempt
PLAYER = (255, 34,  0)
AI     = (0,  153, 255)
EMPTY  = (26,  26, 46)

board = [
    [0, 0, 0, 2, 0],
    [0, 1, 0, 2, 0],
    [1, 1, 1, 1, 1],   # player connecting
    [0, 0, 2, 0, 0],
    [0, 2, 0, 0, 0],
]

for r in range(N):
    for c in range(N):
        px, py = cx(r, c), cy(r, c)
        mark = board[r][c]
        fill = PLAYER if mark == 1 else (AI if mark == 2 else EMPTY)
        draw.ellipse([px-RAD, py-RAD, px+RAD, py+RAD], fill=fill)

# Highlight the winning Red connection row 2
for c in range(N):
    px, py = cx(2, c), cy(2, c)
    draw.ellipse([px-RAD-1, py-RAD-1, px+RAD+1, py+RAD+1], outline=(0, 255, 85), width=1)

# Edge bands
for r in range(N):
    draw.ellipse([cx(r,0)-RAD-4-2, cy(r,0)-2, cx(r,0)-RAD-4+2, cy(r,0)+2], fill=PLAYER)
    draw.ellipse([cx(r,N-1)+RAD+4-2, cy(r,N-1)-2, cx(r,N-1)+RAD+4+2, cy(r,N-1)+2], fill=PLAYER)
for c in range(N):
    draw.ellipse([cx(0,c)-2, cy(0,c)-RAD-4-2, cx(0,c)+2, cy(0,c)-RAD-4+2], fill=AI)
    draw.ellipse([cx(N-1,c)-2, cy(N-1,c)+RAD+4-2, cx(N-1,c)+2, cy(N-1,c)+RAD+4+2], fill=AI)

# Circular clip
mask = Image.new("L", (SIZE, SIZE), 0)
ImageDraw.Draw(mask).ellipse([0, 0, SIZE-1, SIZE-1], fill=255)
result = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
result.paste(img, mask=mask)

os.makedirs(os.path.dirname(OUT), exist_ok=True)
result.save(OUT)
print(f"Saved → {OUT}")
