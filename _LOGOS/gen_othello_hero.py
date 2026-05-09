#!/usr/bin/env python3
"""Generate othello_hero.png (1440×720)."""
from PIL import Image, ImageDraw, ImageFont
import os

W, H = 1440, 720
OUT  = os.path.join(os.path.dirname(__file__), "othello_hero.png")
img  = Image.new("RGB", (W, H), (10, 18, 10))
draw = ImageDraw.Draw(img)

def font(size):
    for p in ["/System/Library/Fonts/Helvetica.ttc",
              "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
              "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"]:
        try: return ImageFont.truetype(p, size)
        except: pass
    return ImageFont.load_default()

# ── Title banner ──────────────────────────────────────────────────────────────
TH = 88
draw.rectangle([0, 0, W, TH], fill=(8, 14, 8))
draw.rectangle([0, TH, W, TH+3], fill=(26, 160, 26))
draw.text((W//2, TH//2 - 14), "BITOCHI", font=font(24), fill=(30, 100, 30), anchor="mm")
draw.text((W//2, TH//2 + 16), "OTHELLO BLITZ", font=font(46), fill=(44, 220, 44), anchor="mm")
for i, col in enumerate([(44, 220, 44), (100, 100, 100), (200, 200, 200), (26, 120, 26)]):
    x0 = W//2 - 250 + i*130
    draw.rectangle([x0, TH-6, x0+110, TH-1], fill=col)

# ── Centre: 8×8 Othello board ─────────────────────────────────────────────────
CX, CY = W // 2, (H + TH) // 2 + 10
STEP = 40; BOARD = STEP * 8
BX = CX - BOARD // 2; BY = CY - BOARD // 2

draw.rectangle([BX, BY, BX+BOARD, BY+BOARD], fill=(26, 122, 26))
for i in range(9):
    lx = BX + i*STEP; ly = BY + i*STEP
    draw.line([(lx, BY), (lx, BY+BOARD)], fill=(13, 90, 13), width=2)
    draw.line([(BX, ly), (BX+BOARD, ly)], fill=(13, 90, 13), width=2)

DR = 17

def stone(gx, gy, col):
    px = BX + gx*STEP + STEP//2
    py = BY + gy*STEP + STEP//2
    if col == 'B':
        draw.ellipse([px-DR, py-DR, px+DR, py+DR], fill=(15, 15, 15))
        draw.ellipse([px-DR+3, py-DR+3, px-DR+9, py-DR+9], fill=(55, 55, 55))
    else:
        draw.ellipse([px-DR, py-DR, px+DR, py+DR], fill=(220, 220, 220))
        draw.ellipse([px-DR, py-DR, px+DR, py+DR], outline=(150, 150, 150), width=2)
        draw.ellipse([px-DR+3, py-DR+3, px-DR+9, py-DR+9], fill=(255, 255, 255))

# A game in progress
board_layout = [
    (0,0,'B'),(1,0,'B'),(2,0,'W'),(3,0,'B'),(4,0,'W'),(5,0,'W'),(6,0,'B'),(7,0,'W'),
    (0,1,'W'),(1,1,'B'),(2,1,'B'),(3,1,'W'),(4,1,'W'),(5,1,'B'),(6,1,'B'),(7,1,'W'),
    (0,2,'B'),(1,2,'W'),(2,2,'B'),(3,2,'B'),(4,2,'W'),(5,2,'B'),(6,2,'W'),(7,2,'B'),
    (0,3,'W'),(1,3,'B'),(2,3,'W'),(3,3,'W'),(4,3,'B'),(5,3,'W'),(6,3,'B'),
              (1,4,'W'),(2,4,'B'),(3,4,'B'),(4,4,'W'),(5,4,'B'),          (7,4,'W'),
    (0,5,'B'),(1,5,'W'),(2,5,'W'),(3,5,'B'),(4,5,'W'),(5,5,'B'),(6,5,'B'),
    (0,6,'W'),(1,6,'B'),          (3,6,'W'),(4,6,'B'),(5,6,'W'),
]
for (gx, gy, col) in board_layout:
    stone(gx, gy, col)

# Cursor on (6,6)
cpx = BX + 6*STEP; cpy = BY + 6*STEP
draw.rectangle([cpx, cpy, cpx+STEP, cpy+STEP], outline=(255, 255, 0), width=3)
draw.rectangle([cpx+2, cpy+2, cpx+STEP-2, cpy+STEP-2], outline=(255, 200, 0), width=2)

# Valid-move dot on (6,7) and (7,5)
for (gx, gy) in [(6,7),(7,5),(2,6)]:
    vx = BX + gx*STEP + STEP//2; vy = BY + gy*STEP + STEP//2
    draw.ellipse([vx-5, vy-5, vx+5, vy+5], fill=(44, 220, 44))

# ── Feature cards ─────────────────────────────────────────────────────────────
CARDS = [
    ("FLIP\nMECHANIC",  "Capture opponent discs\nby sandwiching them\nin a straight line.",
     (44, 220, 44),  (8, 22, 8)),
    ("DISC\nANIMATION", "Watch discs flip with\na smooth squish\nanimation (300 ms).",
     (100, 200, 100), (10, 20, 10)),
    ("AI\nOPPONENT",   "Corner-first AI using\nclassic position\nweight table.",
     (160, 200, 160), (16, 22, 16)),
    ("CONTROLS",       "D-pad: move cursor\nSELECT: place disc\nBACK: exit",
     (120, 180, 120), (12, 20, 12)),
]
NL = len(CARDS); MG = 14; GAP = 8
CW = (W - 2*MG - (NL-1)*GAP) // NL
CARD_Y = TH + 16; CARD_H = H - CARD_Y - 16

for i, (title, body, accent, bg) in enumerate(CARDS):
    cx_c = MG + i * (CW + GAP)
    draw.rectangle([cx_c, CARD_Y, cx_c+CW, CARD_Y+CARD_H], fill=bg)
    draw.rectangle([cx_c, CARD_Y, cx_c+CW, CARD_Y+4], fill=accent)
    tf = font(22); ty = CARD_Y + 18
    for line in title.split("\n"):
        draw.text((cx_c + CW//2, ty), line, font=tf, fill=accent, anchor="mm"); ty += 28
    bf = font(16); by2 = ty + 8
    for line in body.split("\n"):
        draw.text((cx_c + CW//2, by2), line, font=bf, fill=(120, 160, 120), anchor="mm"); by2 += 22

img.save(OUT)
print(f"Saved → {OUT}")
