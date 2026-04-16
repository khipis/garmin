#!/usr/bin/env python3
"""
Boat Mode Dive Planner — icon & hero generator
Launcher icon: 40x40 RGBA
  - Dark navy background
  - Bright green GO circle (boat/safe symbol)
  - Horizontal wave lines (ocean / boat deck feel)
  - Anchor silhouette top-right (tiny)
Hero image: 1440x720 RGB
  - Split: dark ocean left / bright sun glare right
  - Left: QUICK PLAN, Safety Check, Gas Check labels
  - Right: GO verdict in huge bright green text
  - App title at bottom
"""

from PIL import Image, ImageDraw, ImageFont
import math, os

# ── Launcher icon 40x40 ──────────────────────────────────────────────────────

ico = Image.new("RGBA", (40, 40), (0, 0, 0, 0))
d   = ImageDraw.Draw(ico)

# Background — very dark navy
d.ellipse([0, 0, 39, 39], fill=(3, 6, 12, 255))

# Ocean wave lines
for i, y in enumerate([25, 29, 33]):
    amp   = 2
    alpha = 90 - i * 20
    pts   = []
    for x in range(0, 40):
        pts.append((x, y + amp * math.sin(x * 0.5 + i)))
    for j in range(len(pts) - 1):
        x1, y1 = int(pts[j][0]),   int(pts[j][1])
        x2, y2 = int(pts[j+1][0]), int(pts[j+1][1])
        d.line([x1, y1, x2, y2], fill=(0, 120, 200, alpha), width=1)

# GO circle
d.ellipse([6, 4, 30, 22], outline=(0, 238, 68, 220), width=2)

# "GO" text inside circle
try:
    fnt = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 9)
except Exception:
    fnt = ImageFont.load_default()
d.text((18, 11), "GO", fill=(0, 238, 68, 255), font=fnt, anchor="mm")

# Tiny anchor symbol (top right)
ax, ay = 33, 7
d.line([ax, ay-3, ax, ay+3],        fill=(0, 150, 220, 200), width=1)
d.arc([ax-3, ay-3, ax+3, ay+3],  0, 180, fill=(0, 150, 220, 200), width=1)
d.line([ax-3, ay+2, ax-3+2, ay+4], fill=(0, 150, 220, 200), width=1)
d.line([ax+3, ay+2, ax+3-2, ay+4], fill=(0, 150, 220, 200), width=1)

out_ico = os.path.join(os.path.dirname(__file__), "../../boatmodediveplanner/resources/launcher_icon.png")
os.makedirs(os.path.dirname(out_ico), exist_ok=True)
ico.save(out_ico)
print("Saved launcher_icon.png")

# ── Hero image 1440x720 ──────────────────────────────────────────────────────

W, H = 1440, 720
hero = Image.new("RGB", (W, H), (3, 6, 12))
d2   = ImageDraw.Draw(hero)

# Left half — deep ocean dark
d2.rectangle([0, 0, W//2, H], fill=(3, 6, 18))
# Right half — slightly brighter sky
d2.rectangle([W//2, 0, W, H], fill=(4, 10, 22))

# Ocean gradient bands (left side)
for i in range(0, H, 4):
    alpha = int(30 + 20 * math.sin(i * 0.04))
    shade = (0, max(0, 30 + alpha // 2), max(0, 50 + alpha))
    d2.line([0, i, W//2, i], fill=shade)

# Vertical divider
d2.line([W//2, 40, W//2, H-40], fill=(20, 50, 70), width=2)

# Title background bar
d2.rectangle([0, 0, W, 60], fill=(0, 0, 0))
try:
    f_title = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 28)
    f_large = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 56)
    f_med   = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 36)
    f_small = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 22)
    f_tiny  = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 18)
    f_huge  = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 120)
except Exception:
    f_title = f_large = f_med = f_small = f_tiny = f_huge = ImageFont.load_default()

d2.text((W//2, 30), "BOAT MODE DIVE PLANNER", fill=(255,255,255), font=f_title, anchor="mm")

# LEFT: Mode list panel
panel_y = 80
d2.text((40, panel_y), "MODE SELECT", fill=(68, 136, 200), font=f_small)

modes = [
    ("QUICK PLAN",   "gas · depth · time → GO / NO GO",    (0, 238, 68)),
    ("SAFETY CHECK", "gas · depth → PO2 verdict",           (255, 170, 0)),
    ("GAS CHECK",    "fill · tank · depth → ENOUGH / SHORT",(0, 200, 255)),
]
y_off = panel_y + 50
for label, sub, col in modes:
    d2.rectangle([40, y_off, W//2 - 40, y_off + 80], fill=(8, 20, 35))
    d2.rectangle([40, y_off, 46, y_off + 80], fill=col)
    d2.text((60, y_off + 14), label, fill=col, font=f_med)
    d2.text((60, y_off + 52), sub,   fill=(100, 140, 170), font=f_tiny)
    y_off += 100

# LEFT bottom: formula reminder
y2 = 500
d2.text((40, y2), "All calculations:", fill=(60, 100, 140), font=f_tiny)
d2.text((40, y2+24), "PO2 = FO2 × (d/10+1)  |  MOD = (1.4/FO2−1)×10", fill=(60, 100, 140), font=f_tiny)
d2.text((40, y2+48), "NDL interpolated PADI table  |  Gas = (fill−50bar)×tank÷SAC÷amb", fill=(60, 100, 140), font=f_tiny)

# RIGHT: large GO verdict
rx = W//2 + (W//2)//2
# Safety — PO2 value mock
d2.text((rx, 110), "SAFETY CHECK", fill=(68, 136, 200), font=f_small, anchor="mm")
d2.rectangle([W//2+60, 130, W-60, 330], fill=(5, 15, 28))
d2.text((rx, 160), "PO2", fill=(100, 140, 170), font=f_small, anchor="mm")
d2.text((rx, 250), "1.12", fill=(0, 238, 68), font=f_huge, anchor="mm")

# Verdict box
d2.rectangle([W//2+80, 340, W-80, 420], fill=(0, 238, 68))
d2.text((rx, 378), "SAFE", fill=(0, 0, 0), font=f_large, anchor="mm")

d2.text((rx, 450), "MOD 33m   NDL 29min", fill=(200,200,200), font=f_small, anchor="mm")

# Bottom bar
d2.rectangle([0, H-50, W, H], fill=(0, 0, 0))
d2.text((W//2, H-25),
        "Boat Mode Dive Planner  ·  Outdoor-optimised  ·  3 modes  ·  2–3 taps to verdict",
        fill=(80, 120, 160), font=f_tiny, anchor="mm")

out_hero = os.path.join(os.path.dirname(__file__), "boatmodediveplanner_hero.png")
hero.save(out_hero)
print("Saved boatmodediveplanner_hero.png")
