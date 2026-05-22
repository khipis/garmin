#!/usr/bin/env python3
"""Generate tictacpro_hero.png (1440×720) for Tic Tac Pro."""
from PIL import Image, ImageDraw, ImageFont
import os, math

W, H = 1440, 720
OUT  = os.path.join(os.path.dirname(__file__), "tictacpro_hero.png")

img  = Image.new("RGB", (W, H), (8, 8, 16))
draw = ImageDraw.Draw(img)

# ── Background gradient/stars ────────────────────────────────────────────
import random; random.seed(42)
for _ in range(260):
    sx = random.randint(0, W); sy = random.randint(0, H)
    br = random.randint(30, 90)
    draw.point((sx, sy), fill=(br, br, br+20))

# ── Title ────────────────────────────────────────────────────────────────
title_x = W // 2; title_y = 42
try:
    tfont = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 76)
    sfont = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 28)
    cfont = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 22)
    mfont = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 42)
except:
    tfont = sfont = cfont = mfont = ImageFont.load_default()

draw.text((title_x, title_y), "BITOCHI  TIC TAC PRO",
          font=tfont, fill=(0, 170, 255), anchor="mt")
draw.text((title_x, title_y + 84), "5×5 grid  ·  4 in a row  ·  smart AI",
          font=sfont, fill=(100, 100, 140), anchor="mt")

# ── Simulated watch face ──────────────────────────────────────────────────
WCX, WCY, WCR = 360, 420, 230
draw.ellipse([WCX-WCR, WCY-WCR, WCX+WCR, WCY+WCR], fill=(10, 10, 20), outline=(50, 50, 80), width=2)
draw.ellipse([WCX-WCR+8, WCY-WCR+8, WCX+WCR-8, WCY+WCR-8], outline=(30, 30, 60), width=1)

# Grid on watch (5×5)
ROWS = 5; CELL = 62; BSZ = ROWS * CELL
bx = WCX - BSZ//2; by = WCY - BSZ//2 - 10

for i in range(ROWS+1):
    lx = bx + i*CELL; ly = by + i*CELL
    draw.line([(lx, by), (lx, by+BSZ)], fill=(55, 55, 80), width=1)
    draw.line([(bx, ly), (bx+BSZ, ly)], fill=(55, 55, 80), width=1)

# Board position: X marks blue, O marks orange
board = [
    [0,2,0,0,0],
    [0,0,1,0,0],
    [0,1,2,1,0],
    [0,0,1,2,0],
    [0,0,0,0,2],
]
for r in range(ROWS):
    for c in range(ROWS):
        px = bx + c*CELL + CELL//2; py = by + r*CELL + CELL//2
        mark = board[r][c]
        if mark == 1:
            hc = CELL * 33 // 100
            for d in [0, 1, 2]:
                draw.line([(px-hc+d, py-hc), (px+hc+d, py+hc)], fill=(0, 170, 255), width=3)
                draw.line([(px+hc+d, py-hc), (px-hc+d, py+hc)], fill=(0, 170, 255), width=3)
        elif mark == 2:
            r2 = CELL * 33 // 100
            for th in range(3):
                draw.ellipse([px-r2+th, py-r2+th, px+r2-th, py+r2-th],
                             outline=(255, 68, 34), width=2)

# Cursor on (2,2)
cursor_cx = bx + 2*CELL; cursor_cy = by + 2*CELL
draw.rectangle([cursor_cx+3, cursor_cy+3, cursor_cx+CELL-3, cursor_cy+CELL-3],
               outline=(255, 255, 0), width=2)

# HUD text
draw.text((WCX, by - 22), "YOUR TURN", font=cfont, fill=(68, 255, 68), anchor="mt")
draw.text((WCX - 60, by - 22), "X 2", font=cfont, fill=(0, 170, 255), anchor="mt")
draw.text((WCX + 60, by - 22), "1 O", font=cfont, fill=(255, 68, 34), anchor="mt")

# Watch bezel clip
mask = Image.new("L", (W, H), 0)
ImageDraw.Draw(mask).ellipse([WCX-WCR, WCY-WCR, WCX+WCR, WCY+WCR], fill=255)
watch_layer = Image.new("RGB", (W, H), (8, 8, 16))
watch_layer.paste(img.crop([WCX-WCR, WCY-WCR, WCX+WCR, WCY+WCR]),
                  (WCX-WCR, WCY-WCR))
img_clipped = img.copy()
img_clipped.paste(watch_layer, mask=mask)
# Re-draw bezel ring on top
draw2 = ImageDraw.Draw(img_clipped)
draw2.ellipse([WCX-WCR, WCY-WCR, WCX+WCR, WCY+WCR], outline=(80, 80, 110), width=6)

# ── Feature cards ─────────────────────────────────────────────────────────
cards = [
    ("5×5 GRID",          "Classic look,\nbigger strategy"),
    ("4 IN A ROW",        "Win condition:\n4 connected marks"),
    ("SMART AI",          "Win→Block→\nPositional heuristic"),
    ("FAST PLAY",         "Best on round\nGarmin watches"),
]
card_w = 195; card_h = 148; cx0 = 730; cy0 = 200; gap = 12

for i, (title, desc) in enumerate(cards):
    col = i % 2; row = i // 2
    cx = cx0 + col * (card_w + gap)
    cy = cy0 + row * (card_h + gap)
    draw2.rounded_rectangle([cx, cy, cx+card_w, cy+card_h], radius=10,
                             fill=(14, 14, 28), outline=(40, 40, 70), width=1)
    tw = draw2.textlength(title, font=cfont)
    draw2.text((cx + card_w//2 - tw//2, cy + 14), title, font=cfont, fill=(0, 170, 255))
    lines = desc.split("\n")
    for li2, ln in enumerate(lines):
        lw = draw2.textlength(ln, font=sfont)
        draw2.text((cx + card_w//2 - lw//2, cy + 46 + li2 * 28), ln,
                   font=sfont, fill=(140, 140, 170))

img_clipped.save(OUT)
print(f"Saved → {OUT}")
