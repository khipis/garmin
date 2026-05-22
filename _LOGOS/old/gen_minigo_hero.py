#!/usr/bin/env python3
"""Generate minigo_hero.png (1440×720)."""
from PIL import Image, ImageDraw, ImageFont
import os, math

W, H = 1440, 720
OUT  = os.path.join(os.path.dirname(__file__), "minigo_hero.png")
img  = Image.new("RGB", (W, H), (26, 18, 8))
draw = ImageDraw.Draw(img)

def font(size):
    for p in ["/System/Library/Fonts/Helvetica.ttc",
              "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
              "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"]:
        try: return ImageFont.truetype(p, size)
        except: pass
    return ImageFont.load_default()

# ── title banner ──────────────────────────────────────────────────────────────
TH = 90
draw.rectangle([0, 0, W, TH], fill=(20, 14, 5))
draw.rectangle([0, TH, W, TH+3], fill=(180, 130, 40))
draw.text((W//2, TH//2 - 12), "BITOCHI", font=font(26), fill=(100, 70, 20), anchor="mm")
draw.text((W//2, TH//2 + 20), "MINI GO 9×9", font=font(46), fill=(210, 170, 80), anchor="mm")
for i, col in enumerate([(180, 130, 40), (60, 60, 60), (200, 200, 200), (40, 160, 60)]):
    x0 = W//2 - 260 + i*140
    draw.rectangle([x0, TH-7, x0+120, TH-2], fill=col)

# ── centre: 9×9 board ─────────────────────────────────────────────────────────
CX, CY = W // 2, (H + TH) // 2 + 10
BOARD_SZ = 340; STEP = BOARD_SZ // 8
BX = CX - BOARD_SZ // 2; BY = CY - BOARD_SZ // 2

draw.rectangle([BX - STEP//2, BY - STEP//2,
                BX + BOARD_SZ + STEP//2, BY + BOARD_SZ + STEP//2],
               fill=(200, 160, 64))

for i in range(9):
    lx = BX + i * STEP; ly = BY + i * STEP
    draw.line([(lx, BY), (lx, BY + 8*STEP)], fill=(90, 60, 20), width=2)
    draw.line([(BX, ly), (BX + 8*STEP, ly)], fill=(90, 60, 20), width=2)

for hx in [2, 4, 6]:
    for hy in [2, 4, 6]:
        px = BX + hx*STEP; py = BY + hy*STEP
        draw.ellipse([px-4, py-4, px+4, py+4], fill=(70, 45, 15))

SR = STEP * 43 // 100

def stone(gx, gy, col):
    px = BX + gx*STEP; py = BY + gy*STEP
    if col == 'B':
        draw.ellipse([px-SR, py-SR, px+SR, py+SR], fill=(20, 20, 20))
        r2 = SR//3
        draw.ellipse([px-SR+r2, py-SR+r2, px-SR+r2+r2*2, py-SR+r2+r2*2], fill=(60,60,60))
    else:
        draw.ellipse([px-SR, py-SR, px+SR, py+SR], fill=(238, 238, 238))
        draw.ellipse([px-SR, py-SR, px+SR, py+SR], outline=(130,130,130), width=2)
        r2 = SR//3
        draw.ellipse([px-SR+r2, py-SR+r2, px-SR+r2+r2*2, py-SR+r2+r2*2], fill=(255,255,255))

layout = [
    (0,0,'B'),(2,0,'W'),(4,0,'B'),(7,0,'W'),(8,0,'B'),
    (1,1,'W'),(3,1,'B'),(5,1,'W'),(6,1,'B'),
    (0,2,'B'),(2,2,'W'),(4,2,'B'),(6,2,'W'),(8,2,'B'),
    (1,3,'W'),(3,3,'B'),(5,3,'W'),(7,3,'B'),
    (0,4,'B'),(2,4,'W'),(4,4,'W'),(6,4,'B'),(8,4,'W'),
    (1,5,'W'),(3,5,'B'),(5,5,'B'),(7,5,'W'),
    (0,6,'B'),(2,6,'W'),(4,6,'B'),(6,6,'W'),(8,6,'B'),
    (3,7,'W'),(5,7,'B'),
]
for (gx, gy, col) in layout:
    stone(gx, gy, col)

# Cursor
CPX = BX + 5*STEP; CPY = BY + 5*STEP
draw.rectangle([CPX-SR-3, CPY-SR-3, CPX+SR+3, CPY+SR+3], outline=(0, 220, 60), width=3)

# ── feature cards ─────────────────────────────────────────────────────────────
CARDS = [
    ("9×9 BOARD",    "Classic Go rules\non the perfect\ntravel board size.",
     (180, 140, 40), (30, 22, 8)),
    ("CAPTURE\nLOGIC",  "Full group capture\nwith liberty check,\nsuicide & ko rules.",
     (100, 100, 100), (20, 20, 20)),
    ("AI\nOPPONENT",  "Heuristic AI:\nprefers centre,\ncaptures & defends.",
     (60, 160, 70),   (8, 22, 10)),
    ("CONTROLS",     "D-pad: move cursor\nSELECT: place stone\nBACK: pass",
     (140, 140, 180), (18, 18, 30)),
]
NL = len(CARDS); MARGIN = 16; GAP = 10
CW = (W - 2*MARGIN - (NL-1)*GAP) // NL
CARD_Y = TH + 18; CARD_H = H - CARD_Y - 18

for i, (title, body, accent, bg) in enumerate(CARDS):
    cx_c = MARGIN + i * (CW + GAP)
    draw.rectangle([cx_c, CARD_Y, cx_c+CW, CARD_Y+CARD_H], fill=bg)
    draw.rectangle([cx_c, CARD_Y, cx_c+CW, CARD_Y+5], fill=accent)
    tf = font(24); ty = CARD_Y + 20
    for line in title.split("\n"):
        draw.text((cx_c + CW//2, ty), line, font=tf, fill=accent, anchor="mm"); ty += 30
    bf = font(17); by2 = ty + 8
    for line in body.split("\n"):
        draw.text((cx_c + CW//2, by2), line, font=bf, fill=(160, 150, 130), anchor="mm"); by2 += 24

img.save(OUT)
print(f"Saved → {OUT}")
