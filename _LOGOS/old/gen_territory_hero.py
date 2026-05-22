#!/usr/bin/env python3
"""Generate Territory Clash store hero image (1440x720)."""
from PIL import Image, ImageDraw, ImageFont
import os

W, H = 1440, 720
img = Image.new("RGB", (W, H), (10, 26, 10))
d   = ImageDraw.Draw(img)

# Subtle radial glow
for r in range(0, 300, 10):
    v = int(14 * (1 - r / 300))
    col = (10 + v, 26 + v, 10 + v)
    d.ellipse([W//2 - r*2, H//2 - r, W//2 + r*2, H//2 + r], outline=col)

# ── Go board (right side) ──────────────────────────────────────────────────
BX, BY = 680, 60
N, STEP = 9, 70
BW = STEP * (N - 1)

# Wood background
d.rounded_rectangle([BX - 20, BY - 20, BX + BW + 20, BY + BW + 20],
                    radius=8, fill=(200, 144, 76))

# Grid
for i in range(N):
    d.line([(BX + i*STEP, BY), (BX + i*STEP, BY + BW)], fill=(100, 60, 15), width=2)
    d.line([(BX, BY + i*STEP), (BX + BW, BY + i*STEP)], fill=(100, 60, 15), width=2)

# Star points
for (gx, gy) in [(2,2),(6,2),(4,4),(2,6),(6,6)]:
    sx, sy = BX + gx*STEP, BY + gy*STEP
    d.ellipse([sx-5, sy-5, sx+5, sy+5], fill=(100, 60, 15))

# Stones
black_stones = [(2,3),(3,2),(4,3),(3,4),(5,5),(6,4),(7,3),(4,6),(3,7),(6,7)]
white_stones = [(1,2),(2,4),(3,3),(5,3),(6,3),(7,5),(5,6),(4,7),(7,7),(5,8)]
sr = 28
for (gx, gy) in black_stones:
    sx, sy = BX + gx*STEP, BY + gy*STEP
    d.ellipse([sx-sr, sy-sr, sx+sr, sy+sr], fill=(20, 20, 20))
    d.ellipse([sx-sr//2, sy-sr//2, sx-sr//6, sy-sr//6], fill=(50, 50, 50))
for (gx, gy) in white_stones:
    sx, sy = BX + gx*STEP, BY + gy*STEP
    d.ellipse([sx-sr, sy-sr, sx+sr, sy+sr], fill=(240, 240, 240), outline=(100, 100, 100))
    d.ellipse([sx+sr//4, sy+sr//4, sx+sr//2, sy+sr//2], fill=(210, 210, 210))

# Territory markers (small squares)
black_terr = [(0,0),(1,0),(2,0),(0,1),(1,1),(0,2)]
white_terr = [(7,8),(8,8),(8,7),(8,6),(8,5),(7,5)]
tq = 14
for (gx, gy) in black_terr:
    sx, sy = BX + gx*STEP, BY + gy*STEP
    d.rectangle([sx-tq, sy-tq, sx+tq, sy+tq], fill=(20, 20, 20, 200))
for (gx, gy) in white_terr:
    sx, sy = BX + gx*STEP, BY + gy*STEP
    d.rectangle([sx-tq, sy-tq, sx+tq, sy+tq], fill=(240, 240, 240, 200))

# ── Title (left side) ─────────────────────────────────────────────────────
try:
    tf = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 88)
    sf = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 38)
    sm = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 28)
except:
    tf = sf = sm = ImageFont.load_default()

d.text((60, 140), "TERRITORY", fill=(60, 180, 60), font=tf)
d.text((60, 236), "CLASH",     fill=(40, 130, 40), font=tf)
d.text((65, 348), "Simplified Go for your wrist", fill=(120, 170, 120), font=sf)

tags = [
    "9×9 board · Place & capture",
    "BFS group capture rule",
    "Territory + capture scoring",
    "AI: centre + atari heuristic",
]
for i, t in enumerate(tags):
    y = 420 + i * 50
    d.rounded_rectangle([60, y, 60 + 390, y + 38], radius=5,
                         fill=(18, 45, 18), outline=(45, 110, 45))
    d.text((70, y + 9), t, fill=(150, 210, 150), font=sm)

out = os.path.join(os.path.dirname(__file__), "territory_hero.png")
img.save(out)
print(f"Saved {out}")
