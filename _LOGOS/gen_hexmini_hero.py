#!/usr/bin/env python3
"""Generate hexmini_hero.png (1440×720) for Hex Mini."""
from PIL import Image, ImageDraw, ImageFont
import os, random, math

W, H = 1440, 720
OUT  = os.path.join(os.path.dirname(__file__), "hexmini_hero.png")

img  = Image.new("RGB", (W, H), (6, 6, 14))
draw = ImageDraw.Draw(img)

random.seed(13)
for _ in range(280):
    sx = random.randint(0, W); sy = random.randint(0, H)
    br = random.randint(22, 70)
    draw.point((sx, sy), fill=(br, br, br + 18))

try:
    tfont = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 72)
    sfont = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 26)
    cfont = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 20)
except:
    tfont = sfont = cfont = ImageFont.load_default()

# ── Title ────────────────────────────────────────────────────────────────
draw.text((W//2, 44), "BITOCHI  HEX MINI",
          font=tfont, fill=(255, 200, 0), anchor="mt")
draw.text((W//2, 124), "7×7 hex grid  ·  connect opposite sides  ·  no draws",
          font=sfont, fill=(100, 100, 140), anchor="mt")

# ── Watch face ────────────────────────────────────────────────────────────
WCX, WCY, WCR = 360, 430, 218
draw.ellipse([WCX-WCR, WCY-WCR, WCX+WCR, WCY+WCR], fill=(8, 8, 20), outline=(50, 50, 80), width=2)

N  = 7
DX = 42
DY = 37   # ≈ DX * sqrt(3)/2
RAD = 16
BOARD_X = WCX - (9 * DX) // 2
BOARD_Y = WCY - (N-1) * DY // 2 - 8

def cx(r, c): return BOARD_X + c * DX + r * (DX // 2)
def cy(r, c): return BOARD_Y + r * DY

# Grid lines
for r in range(N):
    for c in range(N):
        px, py = cx(r, c), cy(r, c)
        if c + 1 < N:
            draw.line([(px, py), (cx(r, c+1), cy(r, c+1))], fill=(42, 42, 68), width=1)
        if r + 1 < N and c - 1 >= 0:
            draw.line([(px, py), (cx(r+1, c-1), cy(r+1, c-1))], fill=(42, 42, 68), width=1)
        if r + 1 < N:
            draw.line([(px, py), (cx(r+1, c), cy(r+1, c))], fill=(42, 42, 68), width=1)

# Sample board (player Red connecting col 0 to 6)
PLAYER = (255, 34,  0)
AI     = (0,  153, 255)
EMPTY  = (26,  26, 46)

board = [
    [0, 0, 2, 0, 2, 0, 0],
    [0, 1, 2, 0, 0, 0, 0],
    [0, 1, 0, 2, 0, 0, 0],
    [1, 1, 1, 1, 1, 0, 0],  # Red connecting through middle
    [0, 0, 2, 0, 1, 0, 0],
    [0, 2, 0, 0, 1, 0, 0],
    [0, 0, 2, 0, 0, 1, 0],
]

for r in range(N):
    for c in range(N):
        px, py = cx(r, c), cy(r, c)
        mark = board[r][c]
        fill = PLAYER if mark == 1 else (AI if mark == 2 else EMPTY)
        draw.ellipse([px-RAD, py-RAD, px+RAD, py+RAD], fill=fill)

# Cursor
cpx, cpy = cx(2, 5), cy(2, 5)
draw.ellipse([cpx-RAD-3, cpy-RAD-3, cpx+RAD+3, cpy+RAD+3], outline=(255, 255, 0), width=2)

# Edge bands
for r in range(N):
    for bx2, by2 in [(cx(r,0)-RAD-6, cy(r,0)), (cx(r,N-1)+RAD+6, cy(r,N-1))]:
        draw.ellipse([bx2-3, by2-3, bx2+3, by2+3], fill=PLAYER)
for c in range(N):
    for bx2, by2 in [(cx(0,c), cy(0,c)-RAD-6), (cx(N-1,c), cy(N-1,c)+RAD+6)]:
        draw.ellipse([bx2-3, by2-3, bx2+3, by2+3], fill=AI)

# HUD
draw.text((WCX, BOARD_Y - 24), "YOUR TURN", font=cfont, fill=(68, 255, 68), anchor="mt")
draw.text((WCX - 60, BOARD_Y - 24), "YOU 2", font=cfont, fill=(255, 34, 0), anchor="mt")
draw.text((WCX + 60, BOARD_Y - 24), "1 AI", font=cfont, fill=(0, 153, 255), anchor="mt")

# Direction hints
draw.text((WCX - 80, BOARD_Y + (N-1)*DY + RAD + 10), "YOU<>", font=cfont, fill=(255, 51, 0))
draw.text((WCX + 80, BOARD_Y + (N-1)*DY + RAD + 10), "AI^v",  font=cfont, fill=(0, 153, 255), anchor="mt")

# Bezel ring
draw2 = ImageDraw.Draw(img)
draw2.ellipse([WCX-WCR, WCY-WCR, WCX+WCR, WCY+WCR], outline=(80, 80, 110), width=6)

# ── Feature cards ─────────────────────────────────────────────────────────
cards = [
    ("7×7 HEX GRID",      "Parallelogram board,\n6-direction adjacency"),
    ("CONNECT SIDES",     "Red: left → right\nBlue: top → bottom"),
    ("BFS WIN CHECK",     "Flood-fill path\ndetection, O(N²)"),
    ("NO DRAWS",          "Hex theorem:\none player always wins"),
]
card_w = 194; card_h = 148; cx0 = 730; cy0 = 200; gap = 12

for i, (title, desc) in enumerate(cards):
    col = i % 2; row = i // 2
    cx2 = cx0 + col * (card_w + gap)
    cy2 = cy0 + row * (card_h + gap)
    draw2.rounded_rectangle([cx2, cy2, cx2+card_w, cy2+card_h], radius=10,
                             fill=(10, 10, 24), outline=(38, 38, 68), width=1)
    tw = draw2.textlength(title, font=cfont)
    draw2.text((cx2 + card_w//2 - tw//2, cy2 + 12), title, font=cfont, fill=(255, 200, 0))
    lines = desc.split("\n")
    for li, ln in enumerate(lines):
        lw = draw2.textlength(ln, font=sfont)
        draw2.text((cx2 + card_w//2 - lw//2, cy2 + 46 + li * 28), ln,
                   font=sfont, fill=(140, 140, 170))

img.save(OUT)
print(f"Saved → {OUT}")
