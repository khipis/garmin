#!/usr/bin/env python3
"""
Generate edgesurvivor_hero.png (1440×720) — marketing hero image.
"""
from PIL import Image, ImageDraw, ImageFont
import math, os

W, H = 1440, 720
OUT  = os.path.join(os.path.dirname(__file__), "edgesurvivor_hero.png")

img  = Image.new("RGB", (W, H), (0, 0, 0))
draw = ImageDraw.Draw(img)

def font(size):
    for p in ["/System/Library/Fonts/Helvetica.ttc",
              "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
              "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"]:
        try: return ImageFont.truetype(p, size)
        except: pass
    return ImageFont.load_default()

# ── background star field ─────────────────────────────────────────────────────
import random
random.seed(42)
for _ in range(200):
    sx, sy = random.randint(0, W), random.randint(0, H)
    br = random.randint(15, 60)
    draw.rectangle([sx, sy, sx+1, sy+1], fill=(br, br, br + 20))

# ── centre game scene ─────────────────────────────────────────────────────────
CX, CY = W // 2, H // 2 + 30
ER     = 230

# depth rings
for r in [ER // 4, ER // 2, ER * 3 // 4]:
    draw.ellipse([CX-r, CY-r, CX+r, CY+r], outline=(14, 14, 30), width=1)

# glow halo around edge
for dr in range(12, 0, -2):
    alpha = dr * 12
    col   = (int(26 * alpha / 144), int(42 * alpha / 144), int(90 * alpha / 144))
    draw.ellipse([CX-(ER+dr), CY-(ER+dr), CX+(ER+dr), CY+(ER+dr)], outline=col, width=2)

# edge ring
draw.ellipse([CX-ER, CY-ER, CX+ER, CY+ER], outline=(26, 50, 160), width=3)

# ── enemies ───────────────────────────────────────────────────────────────────
# arc wall (red arcs with gap at top)
GAP_C, GAP_H = 270, 38
for a_deg in range(0, 360, 4):
    adiff = abs(a_deg - GAP_C)
    if adiff > 180: adiff = 360 - adiff
    if adiff >= GAP_H:
        a = math.radians(a_deg)
        rx = int(CX + math.cos(a) * ER * 0.7)
        ry = int(CY + math.sin(a) * ER * 0.7)
        draw.ellipse([rx-4, ry-4, rx+4, ry+4], fill=(220, 30, 30))

# expanding ring (blue)
for a_deg in range(0, 310, 5):
    a = math.radians(a_deg)
    rr = int(ER * 0.4)
    rx = int(CX + math.cos(a) * rr)
    ry = int(CY + math.sin(a) * rr)
    draw.ellipse([rx-4, ry-4, rx+4, ry+4], fill=(20, 100, 255))

# lasers (yellow lines)
for la_deg in [35, 155]:
    la = math.radians(la_deg)
    draw.line([(CX, CY), (int(CX + math.cos(la)*ER), int(CY + math.sin(la)*ER))],
              fill=(255, 200, 0), width=3)

# bullets (red dots)
for (ang_d, dist) in [(110, 0.55), (210, 0.75), (330, 0.88)]:
    a  = math.radians(ang_d)
    bx = int(CX + math.cos(a) * ER * dist)
    by = int(CY + math.sin(a) * ER * dist)
    draw.ellipse([bx-7, by-7, bx+7, by+7], fill=(255, 60, 20))
    draw.ellipse([bx-3, by-3, bx+3, by+3], fill=(255, 160, 80))

# player trail + dot at top
for i, ang_d in enumerate([280, 276, 272, 268]):
    a = math.radians(ang_d)
    tx = int(CX + math.cos(a) * ER)
    ty = int(CY + math.sin(a) * ER)
    r  = 6 - i
    draw.ellipse([tx-r, ty-r, tx+r, ty+r], fill=(20, 50, 130))
pa  = math.radians(270)
px  = int(CX + math.cos(pa) * ER)
py  = int(CY + math.sin(pa) * ER)
draw.ellipse([px-9, py-9, px+9, py+9], fill=(255, 255, 255))
draw.ellipse([px-4, py-4, px+4, py+4], fill=(110, 150, 255))

# centre dot
draw.ellipse([CX-4, CY-4, CX+4, CY+4], fill=(30, 30, 60))

# ── title banner ─────────────────────────────────────────────────────────────
TH = 90
draw.rectangle([0, 0, W, TH], fill=(5, 5, 18))
draw.rectangle([0, TH, W, TH + 3], fill=(20, 40, 180))

draw.text((W//2, TH//2 - 12), "BITOCHI", font=font(26), fill=(55, 55, 110), anchor="mm")
draw.text((W//2, TH//2 + 20), "EDGE SURVIVOR", font=font(46), fill=(160, 190, 255), anchor="mm")

# colour bars under title
for i, col in enumerate([(40, 70, 220), (200, 30, 30), (255, 200, 0), (20, 100, 255)]):
    x0 = W//2 - 280 + i * 150
    draw.rectangle([x0, TH - 7, x0 + 130, TH - 2], fill=col)

# ── feature cards ─────────────────────────────────────────────────────────────
CARDS = [
    ("RADIAL\nBULLETS",  "Red projectiles from\nthe centre — dodge\nor get hit.",
     (200, 30, 30),  (18, 5, 5)),
    ("ARC WALLS",        "Expanding ring walls\nwith a gap — align\nyour position!",
     (200, 30, 30),  (18, 5, 5)),
    ("SPIN LASER",       "Yellow beam rotates\naround centre.\nDon't cross it!",
     (200, 160, 0),  (20, 16, 2)),
    ("BLUE RINGS",       "Expanding rings with\na safe gap — stand\nin the green zone.",
     (20, 100, 220), (5,  10, 20)),
    ("DASH",             "SELECT to dash\nalong the edge.\n~1.5 s cooldown.",
     (60, 160, 255), (8,  12, 22)),
]
NL     = len(CARDS)
MARGIN = 18
GAP    = 10
CW     = (W - 2*MARGIN - (NL-1)*GAP) // NL
CARD_Y = TH + 18
CARD_H = H - CARD_Y - 18

for i, (title, body, accent, bg) in enumerate(CARDS):
    cx_c = MARGIN + i * (CW + GAP)
    draw.rectangle([cx_c, CARD_Y, cx_c+CW, CARD_Y+CARD_H], fill=bg)
    draw.rectangle([cx_c, CARD_Y, cx_c+CW, CARD_Y+5], fill=accent)
    tf = font(24); ty = CARD_Y + 20
    for line in title.split("\n"):
        draw.text((cx_c + CW//2, ty), line, font=tf, fill=accent, anchor="mm"); ty += 30
    bf = font(17); by = ty + 8
    for line in body.split("\n"):
        draw.text((cx_c + CW//2, by), line, font=bf, fill=(150, 150, 200), anchor="mm"); by += 24

img.save(OUT)
print(f"Saved → {OUT}")
