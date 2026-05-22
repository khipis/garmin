#!/usr/bin/env python3
"""
Generate shadowclonerunner_hero.png (1440×720) — marketing hero image.
"""
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os, math

W, H   = 1440, 720
BG     = (5, 5, 16)
OUT    = os.path.join(os.path.dirname(__file__), "shadowclonerunner_hero.png")

img  = Image.new("RGB", (W, H), BG)
draw = ImageDraw.Draw(img)

# ── helpers ────────────────────────────────────────────────────────────────────
def font(size):
    for path in [
        "/System/Library/Fonts/Helvetica.ttc",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
    ]:
        try: return ImageFont.truetype(path, size)
        except: pass
    return ImageFont.load_default()

def runner(draw, cx, by, scale, color, outline_only=False, lw_ratio=2, flip=0):
    head_r = int(22 * scale)
    hcx    = cx
    hcy    = by - int(90 * scale) + head_r
    if outline_only:
        draw.ellipse([hcx-head_r, hcy-head_r, hcx+head_r, hcy+head_r], outline=color, width=lw_ratio)
    else:
        draw.ellipse([hcx-head_r, hcy-head_r, hcx+head_r, hcy+head_r], fill=color)
    bw = int(36 * scale); bh = int(40 * scale)
    bx = cx - bw//2; by2 = hcy + head_r + 3
    if outline_only:
        draw.rectangle([bx, by2, bx+bw, by2+bh], outline=color, width=lw_ratio)
    else:
        draw.rectangle([bx, by2, bx+bw, by2+bh], fill=color)
    lw_val = int(11 * scale); lh1 = int(32 * scale); lh2 = int(18 * scale)
    ly = by2 + bh
    if not outline_only:
        draw.rectangle([bx,         ly, bx+lw_val,      ly+lh1], fill=color)
        draw.rectangle([bx+bw-lw_val, ly, bx+bw,        ly+lh2], fill=color)
        draw.rectangle([hcx-head_r, hcy-2, hcx+head_r, hcy+3], fill=(220, 30, 10))
    else:
        draw.rectangle([bx,         ly, bx+lw_val,      ly+lh1], outline=color, width=lw_ratio)
        draw.rectangle([bx+bw-lw_val, ly, bx+bw,        ly+lh2], outline=color, width=lw_ratio)

def cactus(draw, cx, by, h, color=(180, 60, 20)):
    w = max(12, h // 4)
    draw.rectangle([cx-w//2, by-h, cx+w//2, by], fill=color)
    # tip
    draw.rectangle([cx-w//2-1, by-h, cx+w//2+1, by-h+8], fill=color)
    if h > 40:
        draw.rectangle([cx-w*2, by-h*5//8, cx-w//2, by-h*4//8], fill=color)
        draw.rectangle([cx+w//2, by-h*6//8, cx+w*2, by-h*5//8], fill=color)

# ── dark city skyline ──────────────────────────────────────────────────────────
sky_cols = [
    (0, 160, 80, 120), (0, 200, 130, 160), (0, 150, 200, 100),
]
for x, bh, bw, col in [
    (120, 200, 70, (20, 20, 50)), (220, 160, 50, (18, 18, 45)),
    (340, 240, 80, (22, 22, 55)), (500, 180, 60, (15, 15, 40)),
    (1100, 220, 75, (20, 20, 52)), (1200, 150, 55, (18, 18, 46)),
    (1310, 200, 65, (22, 22, 56)), (1380, 130, 50, (16, 16, 42)),
]:
    draw.rectangle([x, H - 90 - bh, x + bw, H - 88], fill=col)
    # windows
    for wy in range(H - 90 - bh + 15, H - 105, 25):
        for wx in range(x + 8, x + bw - 8, 16):
            if (wx + wy) % 3 != 0:
                draw.rectangle([wx, wy, wx+6, wy+10], fill=(40, 40, 90))

# ── ground ─────────────────────────────────────────────────────────────────────
GRD_Y = H - 88
draw.rectangle([0, GRD_Y, W, GRD_Y + 3], fill=(30, 30, 80))
for gx in range(0, W, 55):
    draw.rectangle([gx, GRD_Y + 6, gx + 16, GRD_Y + 8], fill=(20, 20, 55))

# ── game scene (centre column) ─────────────────────────────────────────────────
CX = W // 2

# obstacles
cactus(draw, CX + 280, GRD_Y, 70)
cactus(draw, CX + 340, GRD_Y, 55)
cactus(draw, CX + 180, GRD_Y, 45)

# clones (ghost outlines, behind player)
runner(draw, CX + 20,  GRD_Y,  1.0,  (20, 80, 180),    outline_only=True,  lw_ratio=3)
runner(draw, CX + 10,  GRD_Y - 40, 1.0, (120, 30, 160), outline_only=True, lw_ratio=3)  # one jumping

# player (solid white, front)
runner(draw, CX - 10, GRD_Y, 1.1, (210, 210, 210), outline_only=False)

# jump particle dots
for dx in [-16, 0, 16]:
    draw.ellipse([CX - 10 + dx - 5, GRD_Y - 6, CX - 10 + dx + 5, GRD_Y + 4],
                 fill=(40, 100, 220, 180))

# ── title banner ───────────────────────────────────────────────────────────────
TH = 96
draw.rectangle([0, 0, W, TH], fill=(8, 8, 22))
draw.rectangle([0, TH, W, TH + 3], fill=(30, 50, 150))

draw.text((W//2, TH//2 - 10), "BITOCHI", font=font(28), fill=(60, 60, 120), anchor="mm")
draw.text((W//2, TH//2 + 22), "SHADOW CLONE RUNNER", font=font(42), fill=(180, 200, 255), anchor="mm")

# coloured underline trio
for i, col in enumerate([(30, 90, 220), (140, 40, 200), (30, 170, 100)]):
    x0 = W//2 - 210 + i * 145
    draw.rectangle([x0, TH - 8, x0 + 130, TH - 3], fill=col)

# ── feature cards ──────────────────────────────────────────────────────────────
CARD_Y  = TH + 20
CARD_H  = H - CARD_Y - 20
CARDS   = [
    ("SHADOW\nCLONES", "Your past runs haunt\nyou as ghost obstacles.\nAvoid yourself!",
     (20, 60, 180), (10, 10, 40)),
    ("ENDLESS\nRUNNER", "Jump + Duck to clear\nobstacles. Speed\nincreases over time.",
     (140, 40, 190), (30, 10, 40)),
    ("3 GHOST\nLIMIT", "Only last 3 runs are\nsaved as clones.\nSurvive your own past.",
     (20, 150, 90), (10, 30, 20)),
    ("CONTROLS", "UP / SELECT: Jump\nDOWN: Duck / Pound\nBACK: End run",
     (80, 80, 180), (18, 18, 40)),
]
NL       = len(CARDS)
MARGIN   = 18
GAP      = 14
TOTAL_W  = W - 2 * MARGIN
CW       = (TOTAL_W - (NL - 1) * GAP) // NL

for i, (title, body, accent, bg) in enumerate(CARDS):
    cx_card = MARGIN + i * (CW + GAP)
    # panel
    draw.rectangle([cx_card, CARD_Y, cx_card + CW, CARD_Y + CARD_H], fill=bg)
    draw.rectangle([cx_card, CARD_Y, cx_card + CW, CARD_Y + 5], fill=accent)
    # title
    tf = font(26)
    ty = CARD_Y + 18
    for line in title.split("\n"):
        draw.text((cx_card + CW // 2, ty), line, font=tf, fill=accent, anchor="mm")
        ty += 32
    # body
    bf  = font(19)
    by  = ty + 10
    for line in body.split("\n"):
        draw.text((cx_card + CW // 2, by), line, font=bf, fill=(160, 160, 210), anchor="mm")
        by += 26

# ── decorative glow dots ───────────────────────────────────────────────────────
for x, y, r, col in [
    (180, 280, 40, (20, 50, 180)),
    (1260, 310, 35, (100, 20, 160)),
    (720, H - 130, 30, (20, 130, 80)),
]:
    for dr in range(r, 0, -3):
        a = int(15 * dr / r)
        overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        d2 = ImageDraw.Draw(overlay)
        d2.ellipse([x-dr, y-dr, x+dr, y+dr], fill=(*col, a))
        img = Image.alpha_composite(img.convert("RGBA"), overlay).convert("RGB")
        draw = ImageDraw.Draw(img)

img.save(OUT)
print(f"Saved → {OUT}")
