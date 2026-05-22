#!/usr/bin/env python3
"""Generate launcher_icon.png (70×70) for Dino Run."""

from PIL import Image, ImageDraw
import os, math

SZ = 70
OUT = os.path.join(os.path.dirname(__file__), "../dinosaur/resources/launcher_icon.png")

img = Image.new("RGBA", (SZ, SZ), (0, 0, 0, 255))
d   = ImageDraw.Draw(img)

# ── background gradient (dark grey → near black) ─────────────────────────────
for y in range(SZ):
    v = int(8 + (SZ - y) * 0.18)
    d.line([(0, y), (SZ, y)], fill=(v, v, v, 255))

# subtle scanlines
for y in range(0, SZ, 3):
    d.line([(0, y), (SZ, y)], fill=(0, 0, 0, 40))

# ── ground line ───────────────────────────────────────────────────────────────
GRD = 52
d.rectangle([0, GRD, SZ, GRD + 1], fill=(70, 70, 70, 255))
d.rectangle([0, GRD + 3, SZ, GRD + 3], fill=(45, 45, 45, 255))

# ── cactus (right side, green) ───────────────────────────────────────────────
GREEN  = (46, 170, 68)
DGREEN = (28, 110, 44)

cx, cw, ch = 50, 7, 22
cy = GRD - ch
# stem
d.rectangle([cx + cw//4, cy, cx + cw*3//4, GRD], fill=GREEN)
# left arm
d.rectangle([cx - 2, cy + 5, cx + cw//4 + 1, cy + 9], fill=DGREEN)
# right arm
d.rectangle([cx + cw*3//4 - 1, cy + 9, cx + cw + 2, cy + 13], fill=DGREEN)
# stem top cap
d.rectangle([cx + cw//4 - 1, cy - 2, cx + cw*3//4 + 1, cy + 2], fill=GREEN)

# ── dino (left side, light grey) ─────────────────────────────────────────────
DINO  = (220, 220, 220)
DINO2 = (160, 160, 160)

# dino dimensions: 20w × 28h, left edge at x=8
DX, DY, DW, DH = 8, GRD - 28, 20, 28

# body
d.rounded_rectangle([DX, DY + DH*36//100, DX + DW*76//100, DY + DH], radius=3, fill=DINO)
# head
d.rounded_rectangle([DX + DW*36//100, DY + DH*4//100, DX + DW, DY + DH*42//100], radius=3, fill=DINO)
# tail
d.rounded_rectangle([DX - DW*10//100, DY + DH*40//100,
                      DX + DW*8//100,  DY + DH*58//100], radius=2, fill=DINO2)
# eye
d.rectangle([DX + DW*84//100, DY + DH*11//100,
             DX + DW*84//100 + 2, DY + DH*11//100 + 2], fill=(10, 10, 10, 255))
# legs (frame 0 — running)
d.rectangle([DX + DW*22//100, DY + DH*74//100, DX + DW*38//100, DY + DH], fill=DINO2)
d.rectangle([DX + DW*50//100, DY + DH*80//100, DX + DW*66//100, DY + DH], fill=DINO2)

# ── tiny score text ───────────────────────────────────────────────────────────
try:
    from PIL import ImageFont
    font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Courier New Bold.ttf", 7)
except Exception:
    font = None

if font:
    d.text((36, 3), "00000", font=font, fill=(80, 80, 80, 255))

# ── neon green glow ring ──────────────────────────────────────────────────────
for r in [34, 33, 32]:
    alpha = 30 if r == 34 else (55 if r == 33 else 80)
    d.ellipse([SZ//2 - r, SZ//2 - r, SZ//2 + r, SZ//2 + r],
              outline=(46, 170, 68, alpha), width=1)

os.makedirs(os.path.dirname(OUT), exist_ok=True)
img.save(OUT)
print(f"Saved {OUT}")
