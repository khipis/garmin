#!/usr/bin/env python3
"""
Generate launcher_icon.png (70×70) for Edge Survivor.
Concept: dark circle with a bright white dot on its rim, enemy threats
         (red bullet, yellow laser line, blue ring) converging from centre.
"""
from PIL import Image, ImageDraw
import math, os

SIZE = 70
OUT  = os.path.join(os.path.dirname(__file__),
                    "../edgesurvivor/resources/launcher_icon.png")

img  = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 255))
draw = ImageDraw.Draw(img)

cx, cy = SIZE // 2, SIZE // 2
ER = 28  # edge radius

# ── outer glow ────────────────────────────────────────────────────────────────
for r in range(ER + 6, ER - 1, -1):
    alpha = max(0, 60 - (r - ER + 1) * 18)
    draw.ellipse([cx-r, cy-r, cx+r, cy+r], outline=(30, 60, 200, alpha))

# ── edge ring ─────────────────────────────────────────────────────────────────
draw.ellipse([cx-ER, cy-ER, cx+ER, cy+ER], outline=(26, 42, 90, 255), width=2)

# ── laser (yellow line from centre to edge) ───────────────────────────────────
la = math.radians(45)
lx, ly = int(cx + math.cos(la) * ER), int(cy + math.sin(la) * ER)
draw.line([(cx, cy), (lx, ly)], fill=(255, 200, 0, 220), width=2)

# ── expanding ring fragments (blue arcs via dots) ────────────────────────────
ring_r = 14
for a_deg in range(0, 310, 8):
    a = math.radians(a_deg)
    rx = int(cx + math.cos(a) * ring_r)
    ry = int(cy + math.sin(a) * ring_r)
    draw.ellipse([rx-2, ry-2, rx+2, ry+2], fill=(20, 100, 255, 180))

# ── bullets (red dots at various distances) ───────────────────────────────────
for ang_deg, dist in [(170, 8), (230, 18), (300, 24)]:
    a  = math.radians(ang_deg)
    bx = int(cx + math.cos(a) * dist)
    by = int(cy + math.sin(a) * dist)
    draw.ellipse([bx-3, by-3, bx+3, by+3], fill=(255, 30, 30, 220))

# ── player dot (white) on edge at top ────────────────────────────────────────
pa = math.radians(270)
px, py = int(cx + math.cos(pa) * ER), int(cy + math.sin(pa) * ER)
draw.ellipse([px-5, py-5, px+5, py+5], fill=(255, 255, 255, 255))
draw.ellipse([px-2, py-2, px+2, py+2], fill=(100, 140, 255, 255))

# ── centre dot ────────────────────────────────────────────────────────────────
draw.ellipse([cx-2, cy-2, cx+2, cy+2], fill=(30, 30, 60, 255))

os.makedirs(os.path.dirname(OUT), exist_ok=True)
img.save(OUT)
print(f"Saved → {OUT}")
