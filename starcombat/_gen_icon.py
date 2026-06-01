#!/usr/bin/env python3
"""40x40 icon: targeting reticle + crosshair, dark space."""
from PIL import Image, ImageDraw
import math

S = 40
img = Image.new('RGBA', (S, S), (2, 8, 16, 255))
d = ImageDraw.Draw(img)

# Dark circle background
d.ellipse((1, 1, S-2, S-2), fill=(4, 12, 24, 255))

cx = cy = S // 2

# Stars
stars = [(6,8),(32,10),(10,28),(35,30),(14,15),(28,25),(8,20),(30,8)]
for sx, sy in stars:
    d.point((sx, sy), fill=(140, 160, 180, 200))

# Outer scope circle (cyan)
d.ellipse((cx-15, cy-15, cx+15, cy+15), outline=(0, 200, 220, 255), width=1)

# Crosshair lines (inside circle)
gap = 5
d.line([(cx-14, cy), (cx-gap, cy)], fill=(0, 200, 220, 255), width=1)
d.line([(cx+gap, cy), (cx+14, cy)], fill=(0, 200, 220, 255), width=1)
d.line([(cx, cy-14), (cx, cy-gap)], fill=(0, 200, 220, 255), width=1)
d.line([(cx, cy+gap), (cx, cy+14)], fill=(0, 200, 220, 255), width=1)

# Aim indicator arrow (pointing top-right at 45°)
ang = -math.pi / 4
ext = 19
ax = int(cx + math.cos(ang) * ext)
ay = int(cy + math.sin(ang) * ext)
d.line([(cx, cy), (ax, ay)], fill=(0, 255, 220, 255), width=1)
# Arrowhead
for da in [-0.5, 0.5]:
    bx = int(cx + math.cos(ang) * (ext - 5))
    by = int(cy + math.sin(ang) * (ext - 5))
    px = int(bx + math.cos(ang + math.pi/2 + da) * 3)
    py = int(by + math.sin(ang + math.pi/2 + da) * 3)
    d.polygon([(ax, ay), (px, py), (bx, by)], fill=(0, 255, 220, 255))

# Enemy triangle (small red target at top-left inside scope)
ea = math.pi * 1.1
ed = 9
ex = int(cx + math.cos(ea) * ed)
ey = int(cy + math.sin(ea) * ed)
pts = [
    (int(ex - math.cos(ea)*4), int(ey - math.sin(ea)*4)),
    (int(ex + math.sin(ea)*3), int(ey - math.cos(ea)*3)),
    (int(ex - math.sin(ea)*3), int(ey + math.cos(ea)*3)),
]
d.polygon(pts, fill=(220, 50, 30, 255))

# Centre dot
d.ellipse((cx-2, cy-2, cx+2, cy+2), fill=(0, 255, 200, 255))

img.save("/Users/kkorolczuk/work/garmin/starcombat/resources/launcher_icon.png", "PNG")
print("ok")
