#!/usr/bin/env python3
"""
Makao Lite — store hero image (1440×720).
Luxury casino aesthetic: deep felt, spotlight, elegant fan, gold accents.
Rendered at 2× then LANCZOS-downsampled for crisp edges.
"""
from PIL import Image, ImageDraw, ImageFont
import math, os

SCALE = 2
W, H  = 1440 * SCALE, 720 * SCALE
OUT   = os.path.join(os.path.dirname(__file__), "makao_hero.png")

# ── Fonts ─────────────────────────────────────────────────────────────────────
def font(size, bold=False):
    paths = [
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold
            else "/System/Library/Fonts/Supplemental/Arial.ttf",
    ]
    for p in paths:
        try: return ImageFont.truetype(p, size * SCALE)
        except: pass
    return ImageFont.load_default()

F_TITLE = font(96, bold=True)
F_TAG   = font(28)
F_FEAT  = font(22)
F_RANK  = font(30, bold=True)
F_BDGL  = font(17, bold=True)
F_BDGS  = font(15)

# ── Suit shapes ───────────────────────────────────────────────────────────────
def draw_suit(draw, cx, cy, suit, sz, col, alpha_img=None):
    """Draw a playing-card suit symbol centred at (cx, cy), size sz."""
    s = sz
    if suit == 'H':
        r = s // 2
        draw.ellipse([cx - r,     cy - r,     cx,         cy + r // 3], fill=col)
        draw.ellipse([cx,         cy - r,     cx + r,     cy + r // 3], fill=col)
        draw.polygon([(cx - r, cy), (cx + r, cy), (cx, cy + int(r * 1.25))], fill=col)
    elif suit == 'D':
        hw = int(s * 0.52); hh = int(s * 0.72)
        draw.polygon([(cx, cy - hh), (cx + hw, cy),
                      (cx, cy + hh), (cx - hw, cy)], fill=col)
    elif suit == 'C':
        r = s // 3
        for ox, oy in [(-r // 2, r // 3), (r // 2, r // 3), (0, -r // 2)]:
            draw.ellipse([cx + ox - r, cy + oy - r,
                          cx + ox + r, cy + oy + r], fill=col)
        sw = max(2 * SCALE, r // 3)
        draw.rectangle([cx - sw, cy + r // 2, cx + sw, cy + int(r * 1.5)], fill=col)
        draw.rectangle([cx - r, cy + int(r * 1.3),
                        cx + r, cy + int(r * 1.5) + sw], fill=col)
    elif suit == 'S':
        r = s // 2
        draw.polygon([(cx, cy - int(r * 1.1)), (cx + r, cy + r // 3),
                      (cx - r, cy + r // 3)], fill=col)
        draw.ellipse([cx - r,      cy - r // 5,
                      cx,          cy + r * 3 // 4], fill=col)
        draw.ellipse([cx,          cy - r // 5,
                      cx + r,      cy + r * 3 // 4], fill=col)
        sw = max(2 * SCALE, r // 4)
        draw.rectangle([cx - sw, cy + r // 2, cx + sw, cy + int(r * 1.4)], fill=col)
        draw.rectangle([cx - r * 3 // 4, cy + int(r * 1.2),
                        cx + r * 3 // 4,  cy + int(r * 1.4) + sw], fill=col)

# ── Background — deep baize ───────────────────────────────────────────────────
img = Image.new("RGB", (W, H), (5, 16, 8))
d   = ImageDraw.Draw(img)

# Felt micro-texture
for xi in range(0, W + H, 10):
    d.line([(xi, 0), (xi - H, H)], fill=(7, 19, 10), width=1)

# Radial spotlight (right panel)
SPX, SPY = int(W * 0.73), int(H * 0.44)
for r in range(460 * SCALE, 0, -4):
    t = r / (460 * SCALE)
    b = int(44 * (1 - t) ** 1.6)
    d.ellipse([SPX - r, SPY - int(r * 0.60),
               SPX + r, SPY + int(r * 0.60)],
              fill=(5 + b, 16 + b * 2, 8 + b))

# ── Gold palette ─────────────────────────────────────────────────────────────
GOLD    = (212, 175,  55)
GOLD_DK = (140, 110,  30)
GOLD_LT = (255, 230, 100)

def gline(x0, y0, x1, y1, w=2):
    d.line([(x0, y0), (x1, y1)], fill=GOLD_DK, width=w * SCALE + 2)
    d.line([(x0, y0), (x1, y1)], fill=GOLD,    width=w * SCALE)
    d.line([(x0, y0), (x1, y1)], fill=GOLD_LT, width=max(1, w * SCALE - 2))

# Frame and divider
gline(28,   26,   W // SCALE - 28,  26,  1)
gline(28, H // SCALE - 26, W // SCALE - 28, H // SCALE - 26, 1)
gline(612,  36, 612, H // SCALE - 36, 1)

def diamond(cx, cy, r=7):
    r *= SCALE; cx *= SCALE; cy *= SCALE
    d.polygon([(cx, cy - r),(cx + r, cy),(cx, cy + r),(cx - r, cy)], fill=GOLD)

for cx, cy in [(28,26),(W//SCALE-28,26),(28,H//SCALE-26),(W//SCALE-28,H//SCALE-26)]:
    diamond(cx, cy)

# ── Left panel — title & features ─────────────────────────────────────────────
TX = 68 * SCALE

# Multi-layer glow behind title text
for gw in range(10, 0, -2):
    g = 12 + gw * 5
    d.text((TX + gw, 88 * SCALE + gw), "MAKAO",
           fill=(g, g * 4, g), font=F_TITLE)
    d.text((TX + gw, 196 * SCALE + gw), "LITE",
           fill=(g, g * 4, g), font=F_TITLE)

# Title layers (dark → mid → bright)
for shade, off in [((5,35,8), 4*SCALE), ((30,170,55), 2*SCALE), ((70,240,90), 0)]:
    d.text((TX - off//2, 88*SCALE - off//2), "MAKAO", fill=shade, font=F_TITLE)
    d.text((TX - off//2, 196*SCALE - off//2), "LITE",  fill=shade, font=F_TITLE)

# Gold line under title
gline(TX // SCALE, 308, TX // SCALE + 430, 308, 1)

# Tagline
d.text((TX, 320 * SCALE), "Polish card game for your wrist",
       fill=(135, 195, 140), font=F_TAG)

# Feature list
feats = [
    "Match by Rank  or  Suit",
    "5 Special Cards  +  Smart AI",
    "Player vs AI  |  Easy / Med / Hard",
    "K(H) draws 5  |  A chooses suit",
]
FY0 = 388 * SCALE
for i, txt in enumerate(feats):
    fy = FY0 + i * 62 * SCALE
    d.rounded_rectangle([TX - 8*SCALE, fy - 4*SCALE,
                         TX + 488*SCALE, fy + 36*SCALE],
                        radius=8*SCALE, fill=(10,30,12), outline=GOLD_DK, width=SCALE)
    d.text((TX + 14*SCALE, fy + 4*SCALE), txt,
           fill=(168, 228, 172), font=F_FEAT)

# ── Card drawing ───────────────────────────────────────────────────────────────
CW = 148 * SCALE
CH = 210 * SCALE

RANK_FONT  = font(28, bold=True)
SMALL_RANK = font(24, bold=True)

def make_card(rank, suit, is_red, glow_col=None):
    card = Image.new("RGBA", (CW + 20*SCALE, CH + 24*SCALE), (0,0,0,0))
    cd   = ImageDraw.Draw(card)
    ink  = (195, 20, 20) if is_red else (18, 18, 22)
    off  = 12 * SCALE  # shadow offset

    # Drop shadows (multiple layers)
    for s in range(off, 0, -2):
        al = int(200 * (1 - s / (off + 1)))
        cd.rounded_rectangle([s, s, CW - 1 + s, CH - 1 + s],
                             radius=14*SCALE, fill=(0, 0, 0, al))

    # Card face
    cd.rounded_rectangle([0, 0, CW - 1, CH - 1], radius=14*SCALE,
                         fill=(252, 248, 236), outline=(185, 180, 168), width=2*SCALE)
    # Inner border
    cd.rounded_rectangle([5*SCALE, 5*SCALE, CW - 6*SCALE, CH - 6*SCALE],
                         radius=11*SCALE, fill=None,
                         outline=(218, 214, 200), width=SCALE)

    # Special glow ring
    if glow_col:
        for gw in range(5, 1, -1):
            a = 80 + gw * 30
            gc = tuple(min(255, c) for c in glow_col)
            cd.rounded_rectangle([gw*SCALE, gw*SCALE,
                                  CW - 1 - gw*SCALE, CH - 1 - gw*SCALE],
                                 radius=(14 - gw)*SCALE,
                                 fill=None, outline=gc + (a,) if False else gc,
                                 width=SCALE)

    # Rank top-left
    cd.text((10*SCALE, 8*SCALE),  rank, fill=ink, font=RANK_FONT)
    # Suit top-left
    draw_suit(cd, 18*SCALE, 46*SCALE, suit, 20*SCALE, ink)

    # Big centre suit
    draw_suit(cd, CW//2, CH//2, suit, 56*SCALE, ink)

    # Rank bottom-right (inverted)
    bb = cd.textbbox((0,0), rank, font=RANK_FONT)
    rw = bb[2] - bb[0]; rh = bb[3] - bb[1]
    cd.text((CW - 10*SCALE - rw, CH - 8*SCALE - rh), rank, fill=ink, font=RANK_FONT)
    draw_suit(cd, CW - 18*SCALE, CH - 46*SCALE, suit, 20*SCALE, ink)

    return card

def paste_card(base, card_img, cx, cy, angle_deg):
    rot = card_img.rotate(-angle_deg, expand=True, resample=Image.BICUBIC)
    rw, rh = rot.size
    base.paste(rot, (cx - rw//2, cy - rh//2), rot)

# 5 special cards fan
# (rank, suit, is_red, angle, cx_frac, cy_frac, glow_color)
cards = [
    ("2", "H", True,  -30, 0.630, 0.53, (220, 70, 60)),
    ("3", "D", True,  -15, 0.695, 0.47, (220, 120, 50)),
    ("J", "C", False,   0, 0.760, 0.44, (80, 170, 220)),
    ("K", "H", True,   15, 0.825, 0.47, (255, 210, 0)),
    ("A", "S", False,  30, 0.890, 0.53, (120, 220, 130)),
]

for rk, su, red, ang, xf, yf, gc in cards:
    c = make_card(rk, su, red, glow_col=gc)
    paste_card(img, c, int(W * xf), int(H * yf), ang)

# ── "SPECIAL CARDS" header ────────────────────────────────────────────────────
HX = int(W * 0.758)
HY = 30 * SCALE
d.text((HX, HY), "SPECIAL CARDS", fill=GOLD, font=F_FEAT, anchor="mt")
gline(int(HX // SCALE) - 200, HY // SCALE + 30,
      int(HX // SCALE) + 200, HY // SCALE + 30, 1)

# ── Badge strip ───────────────────────────────────────────────────────────────
badges = [
    ("2H",  "Draw 2",         (220,  65,  60)),
    ("3D",  "Draw 3",         (220, 120,  45)),
    ("J",   "Request rank",   ( 80, 175, 220)),
    ("KH",  "Opponent +5!!",  (255, 215,   0)),
    ("A",   "Choose suit",    (120, 220, 130)),
]

BW = 156 * SCALE; BH = 62 * SCALE; BGAP = 12 * SCALE
bTot = 5 * BW + 4 * BGAP
bx0 = int(W * 0.44) + (int(W * 0.56) - bTot) // 2
by0 = int(H * 0.875)

for i, (lbl, desc, col) in enumerate(badges):
    bx = bx0 + i * (BW + BGAP)
    # Ambient glow
    d.rounded_rectangle([bx-3, by0-3, bx+BW+3, by0+BH+3],
                        radius=10*SCALE,
                        fill=tuple(max(0,c//10) for c in col))
    # Body
    d.rounded_rectangle([bx, by0, bx+BW, by0+BH],
                        radius=8*SCALE, fill=(10,26,12), outline=col, width=2*SCALE)
    d.text((bx + BW//2, by0 + 8*SCALE),  lbl,  fill=col,
           font=F_BDGL, anchor="mt")
    d.text((bx + BW//2, by0 + 34*SCALE), desc, fill=(170, 195, 170),
           font=F_BDGS, anchor="mt")

# Badge suit icons
suit_map = {"H": "H", "D": "D", "C": "C", "S": "S"}
badge_suits = [("H", True), ("D", True), None, ("H", True), ("S", False)]
for i, bs in enumerate(badge_suits):
    if bs is None: continue
    su, red = bs
    bx = bx0 + i * (BW + BGAP)
    col = badges[i][2]
    # tiny suit icon in badge
    draw_suit(d, bx + BW - 16*SCALE, by0 + 14*SCALE, su, 12*SCALE, col)

# ── Downscale ─────────────────────────────────────────────────────────────────
out = img.resize((W // SCALE, H // SCALE), Image.LANCZOS)
out.save(OUT, optimize=True)
print(f"Saved {OUT}  ({W//SCALE}×{H//SCALE})")
