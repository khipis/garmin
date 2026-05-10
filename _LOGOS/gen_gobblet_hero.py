#!/usr/bin/env python3
"""Generate gobblet_hero.png (1440×720) for Gobblet Mini."""
from PIL import Image, ImageDraw, ImageFont
import os, random

W, H = 1440, 720
OUT  = os.path.join(os.path.dirname(__file__), "gobblet_hero.png")

img  = Image.new("RGB", (W, H), (6, 6, 14))
draw = ImageDraw.Draw(img)

random.seed(11)
for _ in range(260):
    sx = random.randint(0, W); sy = random.randint(0, H)
    br = random.randint(18, 60)
    draw.point((sx, sy), fill=(br, br, br + 12))

try:
    tfont = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 72)
    sfont = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 26)
    cfont = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 20)
    mfont = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 18)
except:
    tfont = sfont = cfont = mfont = ImageFont.load_default()

draw.text((W//2, 44), "BITOCHI  GOBBLET MINI",
          font=tfont, fill=(255, 200, 0), anchor="mt")
draw.text((W//2, 124), "4×4 grid  ·  4 piece sizes  ·  larger piece gobbles smaller",
          font=sfont, fill=(100, 100, 140), anchor="mt")

# Watch bezel
WCX, WCY, WCR = 360, 430, 218
draw.ellipse([WCX-WCR, WCY-WCR, WCX+WCR, WCY+WCR],
             fill=(8, 8, 20), outline=(50, 50, 80), width=2)

# Board inside watch
GM  = 4; STEP = 78
OFF_X = WCX - 2 * STEP
OFF_Y = WCY - 2 * STEP + 6
PLAYER = (255,  34,   0)
AI     = (  0, 153, 255)
BG     = (  6,   6,  14)

def bx(c): return OFF_X + c * STEP + STEP // 2
def by2(r): return OFF_Y + r * STEP + STEP // 2

# Grid lines
GRID_C = (40, 40, 62)
for i in range(5):
    draw.line([(OFF_X, OFF_Y+i*STEP), (OFF_X+4*STEP, OFF_Y+i*STEP)], fill=GRID_C, width=1)
    draw.line([(OFF_X+i*STEP, OFF_Y), (OFF_X+i*STEP, OFF_Y+4*STEP)], fill=GRID_C, width=1)

# Piece radii (proportional): sz1=8, sz2=15, sz3=22, sz4=29
RADII = [8, 15, 22, 29]

def piece_draw(r, c, col, sz_idx):
    x, y = bx(c), by2(r)
    rad = RADII[sz_idx]
    draw.ellipse([x-rad-2, y-rad-2, x+rad+2, y+rad+2], fill=BG)
    draw.ellipse([x-rad, y-rad, x+rad, y+rad], fill=col)
    if sz_idx >= 1:
        ir = rad * 38 // 100
        draw.ellipse([x-ir, y-ir, x+ir, y+ir], fill=BG)

# Sample mid-game board
piece_draw(0, 0, AI,     3)   # big AI
piece_draw(0, 1, PLAYER, 2)
piece_draw(0, 2, AI,     1)
piece_draw(0, 3, PLAYER, 3)
piece_draw(1, 0, PLAYER, 2)
piece_draw(1, 1, AI,     3)
piece_draw(1, 2, PLAYER, 1)
piece_draw(1, 3, AI,     2)
piece_draw(2, 0, AI,     1)
piece_draw(2, 1, PLAYER, 3)
piece_draw(2, 2, AI,     2)
piece_draw(2, 3, PLAYER, 2)
piece_draw(3, 0, PLAYER, 3)
piece_draw(3, 2, AI,     1)
piece_draw(3, 3, PLAYER, 1)

# Cursor on (3, 1) — valid destination (green)
x1 = OFF_X + 1 * STEP + 2; y1 = OFF_Y + 3 * STEP + 2
draw.rectangle([x1, y1, x1+STEP-4, y1+STEP-4], outline=(68, 255, 68), width=2)

# Stack depth "2" indicator on cell (1,1)
draw.text((bx(1)-RADII[3], by2(1)-RADII[3]), "2", font=mfont, fill=(200, 200, 200))

# HUD text
hud_y = OFF_Y - 22
draw.text((WCX - 60, hud_y), "W:3", font=mfont, fill=(255, 34, 0),   anchor="mt")
draw.text((WCX,      hud_y), "YOUR TURN", font=mfont, fill=(68, 255, 68), anchor="mt")
draw.text((WCX + 60, hud_y), "2:W", font=mfont, fill=(0, 153, 255), anchor="mt")

# Hand strips (player above, AI below)
H_RADII = [3, 5, 7, 10]
py_strip = OFF_Y - 12
for s in range(4):
    cx2 = OFF_X + s * STEP // 1 + 20
    r = H_RADII[s]
    draw.ellipse([cx2-r, py_strip-r, cx2+r, py_strip+r], fill=PLAYER)
    draw.text((cx2, py_strip+r+1), "3", font=mfont, fill=(255,255,255), anchor="mt")
ai_strip = OFF_Y + 4 * STEP + 12
for s in range(4):
    cx2 = OFF_X + s * STEP // 1 + 20
    r = H_RADII[s]
    draw.ellipse([cx2-r, ai_strip-r, cx2+r, ai_strip+r], fill=AI)
    draw.text((cx2, ai_strip+r+1), "2", font=mfont, fill=(255,255,255), anchor="mt")

# Bezel ring
draw.ellipse([WCX-WCR, WCY-WCR, WCX+WCR, WCY+WCR],
             outline=(80, 80, 110), width=6)

# Feature cards
cards = [
    ("STACKING",      "4 sizes: small → large\nBig gobbles any smaller"),
    ("WIN CONDITION", "4 top-visible pieces\nin a row — any direction"),
    ("AI STRATEGY",   "Win check → block check\n→ positional scoring"),
    ("HIDDEN PIECES", "Stacked depth shown\nGobble to reveal!"),
]
CW, CH = 194, 148; cx0 = 730; cy0 = 200; GAP = 12

for i, (title, desc) in enumerate(cards):
    col_i = i % 2; row_i = i // 2
    cx3 = cx0 + col_i * (CW + GAP)
    cy3 = cy0 + row_i * (CH + GAP)
    draw.rounded_rectangle([cx3, cy3, cx3+CW, cy3+CH], radius=10,
                           fill=(10, 10, 24), outline=(38, 38, 68), width=1)
    tw = draw.textlength(title, font=cfont)
    draw.text((cx3 + CW//2 - tw//2, cy3 + 12), title, font=cfont, fill=(255, 200, 0))
    lines = desc.split("\n")
    for li, ln in enumerate(lines):
        lw = draw.textlength(ln, font=sfont)
        draw.text((cx3 + CW//2 - lw//2, cy3 + 48 + li * 28), ln,
                  font=sfont, fill=(140, 140, 170))

img.save(OUT)
print(f"Saved → {OUT}")
