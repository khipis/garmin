#!/usr/bin/env python3
"""Generate morris_hero.png (1440×720) for Morris Classic."""
from PIL import Image, ImageDraw, ImageFont
import os, random, math

W, H = 1440, 720
OUT  = os.path.join(os.path.dirname(__file__), "morris_hero.png")

img  = Image.new("RGB", (W, H), (6, 6, 14))
draw = ImageDraw.Draw(img)

# Star field
random.seed(42)
for _ in range(300):
    sx = random.randint(0, W); sy = random.randint(0, H)
    br = random.randint(20, 65)
    draw.point((sx, sy), fill=(br, br, br + 16))

try:
    tfont = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 72)
    sfont = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 26)
    cfont = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 20)
    mfont = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 18)
except:
    tfont = sfont = cfont = mfont = ImageFont.load_default()

# Title
draw.text((W//2, 44), "BITOCHI  MORRIS CLASSIC",
          font=tfont, fill=(255, 200, 0), anchor="mt")
draw.text((W//2, 124), "Nine Men's Morris  ·  3 phases  ·  16 mills  ·  no draws",
          font=sfont, fill=(100, 100, 140), anchor="mt")

# Watch bezel
WCX, WCY, WCR = 360, 430, 218
draw.ellipse([WCX-WCR, WCY-WCR, WCX+WCR, WCY+WCR],
             fill=(8, 8, 20), outline=(50, 50, 80), width=2)

# Morris board inside watch
STEP = 46
OFF_X = WCX - 3 * STEP   # left edge at grid x=0
OFF_Y = WCY - 3 * STEP + 12

GX = [0,3,6, 1,3,5, 2,3,4, 0,1,2, 4,5,6, 2,3,4, 1,3,5, 0,3,6]
GY = [0,0,0, 1,1,1, 2,2,2, 3,3,3, 3,3,3, 4,4,4, 5,5,5, 6,6,6]

def nx(i): return OFF_X + GX[i] * STEP
def ny(i): return OFF_Y + GY[i] * STEP

LINE_COL = (42, 42, 68)
edges = [
    (0,1),(1,2),(2,14),(14,23),(23,22),(22,21),(21,9),(9,0),
    (3,4),(4,5),(5,13),(13,20),(20,19),(19,18),(18,10),(10,3),
    (6,7),(7,8),(8,12),(12,17),(17,16),(16,15),(15,11),(11,6),
    (1,4),(4,7),(14,13),(13,12),(22,19),(19,16),(9,10),(10,11),
]
for a, b in edges:
    draw.line([(nx(a), ny(a)), (nx(b), ny(b))], fill=LINE_COL, width=2)

# Sample game state — player forming a mill (0,9,21) + extras; AI active
PLAYER = (255, 34,   0)
AI     = (  0, 153, 255)
EMPTY  = ( 26,  26,  46)
RAD = 14

player_nodes = {0, 9, 21, 1, 3, 10}
ai_nodes     = {4, 7, 16, 5, 13, 20}
mill_nodes   = {0, 9, 21}   # player left-column mill

for i in range(24):
    px, py = nx(i), ny(i)
    if i in mill_nodes:
        fill = (255, 100, 0)
    elif i in player_nodes:
        fill = PLAYER
    elif i in ai_nodes:
        fill = AI
    else:
        fill = EMPTY
    draw.ellipse([px-RAD, py-RAD, px+RAD, py+RAD], fill=fill)

# Mill glow rings
for i in mill_nodes:
    px, py = nx(i), ny(i)
    draw.ellipse([px-RAD-4, py-RAD-4, px+RAD+4, py+RAD+4],
                 outline=(255, 210, 0), width=2)

# Cursor on node 4
cpx, cpy = nx(4), ny(4)
draw.ellipse([cpx-RAD-4, cpy-RAD-4, cpx+RAD+4, cpy+RAD+4],
             outline=(255, 255, 0), width=2)

# HUD text inside watch
hud_y = OFF_Y - 28
draw.text((WCX - 60, hud_y), "YOU 2", font=mfont, fill=(255, 34, 0), anchor="mt")
draw.text((WCX,      hud_y), "TAKE!", font=mfont, fill=(255, 221, 0), anchor="mt")
draw.text((WCX + 60, hud_y), "2 AI",  font=mfont, fill=(0, 153, 255), anchor="mt")

# Bezel ring
draw.ellipse([WCX-WCR, WCY-WCR, WCX+WCR, WCY+WCR],
             outline=(80, 80, 110), width=6)

# Feature cards (right side)
cards = [
    ("3 PHASES",      "Place → Move → Fly\n9 pieces each"),
    ("MILL = REMOVE", "3 in a row takes\none opponent piece"),
    ("16 MILLS",      "Horizontal & vertical\ntriples on 3 squares"),
    ("AI STRATEGY",   "Mill first, block second,\nposition & noise"),
]
CW, CH = 194, 148; cx0 = 730; cy0 = 200; GAP = 12

for i, (title, desc) in enumerate(cards):
    col = i % 2; row = i // 2
    cx2 = cx0 + col * (CW + GAP)
    cy2 = cy0 + row * (CH + GAP)
    draw.rounded_rectangle([cx2, cy2, cx2+CW, cy2+CH], radius=10,
                           fill=(10, 10, 24), outline=(38, 38, 68), width=1)
    tw = draw.textlength(title, font=cfont)
    draw.text((cx2 + CW//2 - tw//2, cy2 + 12), title, font=cfont, fill=(255, 200, 0))
    lines = desc.split("\n")
    for li, ln in enumerate(lines):
        lw = draw.textlength(ln, font=sfont)
        draw.text((cx2 + CW//2 - lw//2, cy2 + 48 + li * 28), ln,
                  font=sfont, fill=(140, 140, 170))

img.save(OUT)
print(f"Saved → {OUT}")
