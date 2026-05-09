#!/usr/bin/env python3
"""Generate connectfour_hero.png (1440×720) for Connect Four Lite."""
from PIL import Image, ImageDraw, ImageFont
import os, random

W, H = 1440, 720
OUT  = os.path.join(os.path.dirname(__file__), "connectfour_hero.png")

img  = Image.new("RGB", (W, H), (6, 6, 16))
draw = ImageDraw.Draw(img)

random.seed(7)
for _ in range(300):
    sx = random.randint(0, W); sy = random.randint(0, H)
    br = random.randint(25, 80)
    draw.point((sx, sy), fill=(br, br, br + 15))

try:
    tfont = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 72)
    sfont = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 26)
    cfont = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 20)
    mfont = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 38)
except:
    tfont = sfont = cfont = mfont = ImageFont.load_default()

# ── Title ────────────────────────────────────────────────────────────────
tx = W // 2; ty = 44
draw.text((tx, ty), "BITOCHI  CONNECT FOUR LITE",
          font=tfont, fill=(255, 204, 0), anchor="mt")
draw.text((tx, ty + 80), "7×6 board  ·  drop discs  ·  4 in a row wins",
          font=sfont, fill=(100, 100, 140), anchor="mt")

# ── Watch face ────────────────────────────────────────────────────────────
WCX, WCY, WCR = 360, 430, 220
draw.ellipse([WCX-WCR, WCY-WCR, WCX+WCR, WCY+WCR], fill=(8, 8, 20), outline=(50, 50, 80), width=2)

COLS, ROWS = 7, 6
CELL = 48
BSZ_W = COLS * CELL; BSZ_H = ROWS * CELL
bx = WCX - BSZ_W // 2; by = WCY - BSZ_H // 2 - 10

# Board frame
draw.rounded_rectangle([bx-4, by-4, bx+BSZ_W+3, by+BSZ_H+3], radius=5,
                        fill=(10, 24, 80), outline=(30, 50, 110), width=1)

board = [
    [0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 1, 0, 0, 0],
    [0, 0, 2, 2, 1, 0, 0],
    [0, 1, 2, 1, 2, 1, 0],
    [2, 2, 1, 2, 1, 2, 1],
]

PLAYER_COL = (255, 34,  0)
AI_COL     = (255, 204, 0)
EMPTY_COL  = (14,  14, 36)

for r in range(ROWS):
    for c in range(COLS):
        px = bx + c * CELL + CELL // 2
        py = by + r * CELL + CELL // 2
        rad = CELL // 2 - 3
        mark = board[r][c]
        if   mark == 1: fill = PLAYER_COL
        elif mark == 2: fill = AI_COL
        else:           fill = EMPTY_COL
        draw.ellipse([px-rad, py-rad, px+rad, py+rad], fill=fill)

# Win highlight on column 3 vertical (AI nearly wins)
win = [(2,3),(3,3),(4,3),(5,3)]
for (r, c) in win:
    px = bx + c * CELL + CELL // 2; py = by + r * CELL + CELL // 2
    rad = CELL // 2 - 3
    draw.ellipse([px-rad-2, py-rad-2, px+rad+2, py+rad+2], outline=(0, 255, 85), width=2)

# Selector arrow above column 3
sel_x = bx + 3 * CELL + CELL // 2; sel_y = by - 12
draw.ellipse([sel_x-5, sel_y-5, sel_x+5, sel_y+5], fill=(255, 34, 0))
draw.line([(sel_x-4, sel_y+5), (sel_x, sel_y+11)], fill=(255, 34, 0), width=2)
draw.line([(sel_x+4, sel_y+5), (sel_x, sel_y+11)], fill=(255, 34, 0), width=2)

# HUD
draw.text((WCX, by - 28), "YOUR TURN", font=cfont, fill=(68, 255, 68), anchor="mt")
draw.text((WCX - 55, by - 28), "YOU 1", font=cfont, fill=(255, 34, 0), anchor="mt")
draw.text((WCX + 55, by - 28), "2 AI", font=cfont, fill=(255, 204, 0), anchor="mt")

# Bezel ring
draw2 = ImageDraw.Draw(img)
draw2.ellipse([WCX-WCR, WCY-WCR, WCX+WCR, WCY+WCR], outline=(80, 80, 110), width=6)

# ── Feature cards ─────────────────────────────────────────────────────────
cards = [
    ("7×6 GRID",         "Classic board,\nfull strategic depth"),
    ("DROP DISCS",       "Gravity-based\ndisc placement"),
    ("SMART AI",         "Win → Block →\ncentre heuristic"),
    ("4 IN A ROW",       "Horizontal, vertical\n& diagonal wins"),
]
card_w = 192; card_h = 145; cx0 = 730; cy0 = 205; gap = 12

for i, (title, desc) in enumerate(cards):
    col = i % 2; row = i // 2
    cx2 = cx0 + col * (card_w + gap)
    cy2 = cy0 + row * (card_h + gap)
    draw2.rounded_rectangle([cx2, cy2, cx2+card_w, cy2+card_h], radius=10,
                             fill=(12, 12, 26), outline=(38, 38, 68), width=1)
    tw = draw2.textlength(title, font=cfont)
    draw2.text((cx2 + card_w//2 - tw//2, cy2 + 12), title, font=cfont, fill=(255, 204, 0))
    lines = desc.split("\n")
    for li2, ln in enumerate(lines):
        lw = draw2.textlength(ln, font=sfont)
        draw2.text((cx2 + card_w//2 - lw//2, cy2 + 44 + li2 * 28), ln,
                   font=sfont, fill=(140, 140, 170))

img.save(OUT)
print(f"Saved → {OUT}")
