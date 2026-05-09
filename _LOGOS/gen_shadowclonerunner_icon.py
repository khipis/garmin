#!/usr/bin/env python3
"""
Generate launcher_icon.png (70×70) for Shadow Clone Runner.
Dark background, a white runner with two coloured ghost silhouettes behind it.
"""
from PIL import Image, ImageDraw, ImageFont
import math, os

SIZE   = 70
OUT    = os.path.join(os.path.dirname(__file__),
                      "../shadowclonerunner/resources/launcher_icon.png")

img  = Image.new("RGBA", (SIZE, SIZE), (5, 5, 16, 255))
draw = ImageDraw.Draw(img)

# ── background glow ring ──────────────────────────────────────────────────────
for r in range(33, 28, -1):
    alpha = int(40 * (r - 28) / 5)
    draw.ellipse([SIZE//2 - r, SIZE//2 - r, SIZE//2 + r, SIZE//2 + r],
                 outline=(30, 60, 180, alpha))

# ── helper: draw runner silhouette ───────────────────────────────────────────
def draw_runner(cx, by, scale, color, outline_only=False):
    """cx = centre-x, by = bottom y, scale = size factor"""
    head_r = int(6 * scale)
    headcx = cx
    headcy = by - int(28 * scale) + head_r
    # head
    if outline_only:
        draw.ellipse([headcx-head_r, headcy-head_r, headcx+head_r, headcy+head_r],
                     outline=color, width=1)
    else:
        draw.ellipse([headcx-head_r, headcy-head_r, headcx+head_r, headcy+head_r],
                     fill=color)

    # body
    bw = int(10 * scale)
    bh = int(12 * scale)
    bx = cx - bw // 2
    by2 = headcy + head_r + 1
    if outline_only:
        draw.rectangle([bx, by2, bx+bw, by2+bh], outline=color)
    else:
        draw.rectangle([bx, by2, bx+bw, by2+bh], fill=color)

    # legs (alternating)
    lw  = int(3 * scale)
    lh1 = int(9 * scale)
    lh2 = int(5 * scale)
    ly  = by2 + bh
    if outline_only:
        draw.rectangle([bx,      ly, bx+lw,      ly+lh1], outline=color)
        draw.rectangle([bx+bw-lw, ly, bx+bw, ly+lh2], outline=color)
    else:
        draw.rectangle([bx,      ly, bx+lw,      ly+lh1], fill=color)
        draw.rectangle([bx+bw-lw, ly, bx+bw, ly+lh2], fill=color)

    # headband (player only)
    if not outline_only:
        draw.rectangle([headcx-head_r, headcy-1, headcx+head_r, headcy+1],
                       fill=(220, 30, 10, 255))

GRD_Y = 54

# ghost 2 (green, furthest back)
draw_runner(35, GRD_Y, 0.88, (20, 100, 60, 160), outline_only=True)
# ghost 1 (purple)
draw_runner(32, GRD_Y, 0.94, (120, 40, 160, 180), outline_only=True)
# player (white, front)
draw_runner(29, GRD_Y, 1.0, (220, 220, 220, 255), outline_only=False)

# ── ground line ───────────────────────────────────────────────────────────────
draw.line([(6, GRD_Y), (SIZE-6, GRD_Y)], fill=(40, 40, 100, 255), width=2)

# ── "SCR" label ───────────────────────────────────────────────────────────────
try:
    font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 8)
except Exception:
    font = ImageFont.load_default()
draw.text((SIZE//2, SIZE-7), "SCR", font=font, fill=(80, 80, 140, 255), anchor="mm")

os.makedirs(os.path.dirname(OUT), exist_ok=True)
img.save(OUT)
print(f"Saved → {OUT}")
