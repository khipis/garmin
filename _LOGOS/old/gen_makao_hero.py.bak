#!/usr/bin/env python3
"""Generate Makao Lite store hero image (1440×720).
5 special cards: 2 (draw 2), 3 (draw 3), J (request rank),
                 K♥ (opponent draws 5), A (choose suit).
"""
from PIL import Image, ImageDraw, ImageFont
import math, os

W, H = 1440, 720
OUT  = os.path.join(os.path.dirname(__file__), "makao_hero.png")

# ── Background: deep card-table green ────────────────────────────────────────
img = Image.new("RGB", (W, H), (8, 26, 12))
d   = ImageDraw.Draw(img)

# Subtle felt texture — concentric ellipses
for r in range(0, 420, 9):
    br = int(14 * (1 - r / 420))
    d.ellipse([W//2 - r*2, H//2 - r, W//2 + r*2, H//2 + r],
              outline=(8 + br, 26 + br, 12 + br))

# ── Fonts ────────────────────────────────────────────────────────────────────
def font(size, bold=False):
    paths = [
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold
            else "/System/Library/Fonts/Supplemental/Arial.ttf",
    ]
    for p in paths:
        try: return ImageFont.truetype(p, size)
        except: pass
    return ImageFont.load_default()

title_font = font(104, bold=True)
sub_font   = font(36)
tag_font   = font(28)
lab_font   = font(22)
card_rank  = font(36, bold=True)
card_suit  = font(32)
card_big   = font(70, bold=True)
badge_font = font(19, bold=True)

# ── Left panel: Title + features ─────────────────────────────────────────────
TX = 80

# Title shadow
d.text((TX+3, 123), "MAKAO",  fill=(10,60,10), font=title_font)
d.text((TX+3, 233), "LITE",   fill=(10,60,10), font=title_font)
# Title
d.text((TX,   120), "MAKAO",  fill=(50, 210, 70), font=title_font)
d.text((TX,   230), "LITE",   fill=(35, 160, 50), font=title_font)

d.text((TX,   355), "Polish card game for your wrist",
       fill=(120, 180, 120), font=sub_font)

# Separator line
d.line([(TX, 408), (TX+480, 408)], fill=(40, 100, 40), width=1)

# Feature tags (now reflecting the 5 specials)
tags = [
    "Match by Rank or Suit",
    "5 Special Cards  ·  Smart AI",
    "Player vs AI  ·  Easy / Med / Hard",
    "Quick sessions for your wrist",
]
for i, t in enumerate(tags):
    y = 422 + i * 48
    d.rounded_rectangle([TX, y, TX + 490, y + 38], radius=7,
                        fill=(14, 46, 16), outline=(44, 100, 44), width=1)
    d.text((TX + 14, y + 9), t, fill=(155, 220, 155), font=tag_font)

# ── Helper: draw one card image ───────────────────────────────────────────────
def make_card(w, h, rank, suit_char, is_red, highlight=False):
    """Returns an RGBA card Image."""
    card = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    cd   = ImageDraw.Draw(card)
    bg   = (252, 248, 238) if not highlight else (255, 252, 224)
    cd.rounded_rectangle([0, 0, w-1, h-1], radius=10,
                         fill=bg, outline=(160, 160, 160), width=2)
    if highlight:
        cd.rounded_rectangle([2, 2, w-3, h-3], radius=9,
                             outline=(220, 180, 0), width=2)
    col = (204, 15, 10) if is_red else (18, 18, 18)
    # Top-left corner
    cd.text((11, 8),  rank,      fill=col, font=card_rank)
    cd.text((11, 46), suit_char, fill=col, font=card_suit)
    # Bottom-right (rotated 180°)
    # centre suit
    cd.text((w//2, h//2 + 6), suit_char, fill=col, font=card_big, anchor="mm")
    return card

def paste_card(base, card_img, cx, cy, angle_deg):
    rot = card_img.rotate(-angle_deg, expand=True, resample=Image.BICUBIC)
    rw, rh = rot.size
    base.paste(rot, (cx - rw//2, cy - rh//2), rot)

# ── 5 special cards — fan layout ─────────────────────────────────────────────
# Cards: 2H, 3D, JC, KH, AS
specials = [
    # (rank, suit_char, is_red, angle, cx_offset)
    ("2",  "H", True,  -22, -215),
    ("3",  "D", True,  -11, -110),
    ("J",  "C", False,   0,    0),
    ("K",  "H", True,   11,  110),
    ("A",  "S", False,  22,  215),
]

CW, CH   = 130, 185
FAN_CX   = 1020   # centre of right panel (600..1440)
FAN_CY   = 260

for i, (rk, su, red, ang, dx) in enumerate(specials):
    hi = (rk == "K" and su == "♥")  # highlight King of Hearts
    card = make_card(CW, CH, rk, su, red, highlight=hi)
    paste_card(img, card, FAN_CX + dx, FAN_CY, ang)

# ── Special-card badge strip below the fan ───────────────────────────────────
badges = [
    ("2H",  "Draw 2",         (220, 60,  60)),
    ("3D",  "Draw 3",         (220, 100, 40)),
    ("J",   "Request rank",   (80,  180, 220)),
    ("KH",  "Opponent +5 !!", (255, 215, 0)),
    ("A",   "Choose suit",    (130, 220, 130)),
]

BW, BH = 154, 68
GAP_B  = 8
# Centre the 5 badges in the right panel (x=600..1440)
total_badges = 5 * BW + 4 * GAP_B
bx0    = 600 + (840 - total_badges) // 2
by0    = 428

for i, (lbl, desc, col) in enumerate(badges):
    bx = bx0 + i * (BW + GAP_B)
    d.rounded_rectangle([bx, by0, bx+BW, by0+BH], radius=8,
                        fill=(14, 36, 16), outline=col, width=2)
    d.text((bx + BW//2, by0 + 10), lbl,  fill=col,
           font=badge_font, anchor="mt")
    d.text((bx + BW//2, by0 + 36), desc, fill=(195, 195, 195),
           font=lab_font, anchor="mt")

# ── Divider between left and right panels ────────────────────────────────────
d.line([(590, 60), (590, 660)], fill=(30, 80, 30), width=1)

# ── Section header for right panel ───────────────────────────────────────────
d.text((FAN_CX, 60), "SPECIAL CARDS",
       fill=(80, 160, 80), font=tag_font, anchor="mt")
d.line([(FAN_CX - 220, 96), (FAN_CX + 220, 96)], fill=(40, 100, 40), width=1)

img.save(OUT)
print(f"Saved → {OUT}")
