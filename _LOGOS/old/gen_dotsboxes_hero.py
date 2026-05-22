#!/usr/bin/env python3
"""Generate dotsboxes_hero.png (1440×720) for Dots & Boxes."""
from PIL import Image, ImageDraw, ImageFont
import os, random

W, H = 1440, 720
OUT  = os.path.join(os.path.dirname(__file__), "dotsboxes_hero.png")

img  = Image.new("RGB", (W, H), (6, 6, 14))
draw = ImageDraw.Draw(img)

# Star field
random.seed(7)
for _ in range(280):
    sx = random.randint(0, W); sy = random.randint(0, H)
    br = random.randint(20, 64)
    draw.point((sx, sy), fill=(br, br, br + 15))

try:
    tfont = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 72)
    sfont = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 26)
    cfont = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 20)
    mfont = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 18)
except:
    tfont = sfont = cfont = mfont = ImageFont.load_default()

# Title
draw.text((W//2, 44), "BITOCHI  DOTS & BOXES",
          font=tfont, fill=(255, 200, 0), anchor="mt")
draw.text((W//2, 124), "5×5 dot grid  ·  16 boxes  ·  draw lines, claim boxes",
          font=sfont, fill=(100, 100, 140), anchor="mt")

# Watch bezel
WCX, WCY, WCR = 360, 430, 218
draw.ellipse([WCX-WCR, WCY-WCR, WCX+WCR, WCY+WCR],
             fill=(8, 8, 20), outline=(50, 50, 80), width=2)

# Dots & Boxes grid inside watch
DOTS = 5; STEP = 68; DR = 5; LW = 3
OFF_X = WCX - 2 * STEP   # centre the 4-unit-wide board
OFF_Y = WCY - 2 * STEP + 8

def px(c): return OFF_X + c * STEP
def py(r): return OFF_Y + r * STEP

# Sample mid-game state
H = [
    [1, 1, 2, 0],
    [2, 1, 0, 1],
    [1, 2, 1, 0],
    [0, 1, 2, 1],
    [1, 0, 0, 2],
]
V = [
    [1, 2, 0, 1, 0],
    [2, 1, 1, 0, 1],
    [0, 1, 2, 1, 0],
    [1, 0, 1, 2, 1],
]
PLAYER = (255, 34,   0)
AI     = (  0, 153, 255)
GUIDE  = (42,  42,  60)

# Box fills
for br in range(4):
    for bc in range(4):
        top  = H[br][bc]; bot = H[br+1][bc]
        lft  = V[br][bc]; rgt = V[br][bc+1]
        if top and bot and lft and rgt:
            owner = top  # approximate
            fill  = (40, 5, 0) if owner == 1 else (0, 24, 40)
            draw.rectangle([px(bc)+1, py(br)+1, px(bc+1)-2, py(br+1)-2], fill=fill)
            cx2 = (px(bc) + px(bc+1)) // 2
            cy2 = (py(br) + py(br+1)) // 2
            col = PLAYER if owner == 1 else AI
            draw.ellipse([cx2-8, cy2-8, cx2+8, cy2+8], fill=col)

# Guide lines
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

# Cursor highlight on h(1, 2) — open edge
draw.line([(px(2), py(1)-2), (px(3), py(1)-2)], fill=(255,255,0), width=1)
draw.line([(px(2), py(1)),   (px(3), py(1))  ], fill=(255,255,0), width=2)
draw.line([(px(2), py(1)+2), (px(3), py(1)+2)], fill=(255,255,0), width=1)

# Dots
for r in range(DOTS):
    for c in range(DOTS):
        draw.ellipse([px(c)-DR, py(r)-DR, px(c)+DR, py(r)+DR], fill=(90, 90, 122))

# HUD text inside watch
hud_y = OFF_Y - 26
draw.text((WCX - 65, hud_y), "YOU 5", font=mfont, fill=(255, 34, 0),  anchor="mt")
draw.text((WCX,      hud_y), "YOUR TURN", font=mfont, fill=(68, 255, 68), anchor="mt")
draw.text((WCX + 65, hud_y), "4 AI",  font=mfont, fill=(0, 153, 255), anchor="mt")

# Bezel ring
draw.ellipse([WCX-WCR, WCY-WCR, WCX+WCR, WCY+WCR],
             outline=(80, 80, 110), width=6)

# Feature cards
cards = [
    ("5×5 GRID",      "25 dots, 40 edges\n16 boxes to claim"),
    ("CLAIM BOXES",   "Close the 4th side\nto score + go again"),
    ("3-PHASE AI",    "Take box → safe edge\n→ sacrifice minimum"),
    ("NO DRAWS",      "16 boxes to share;\ntiebreaker possible"),
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
