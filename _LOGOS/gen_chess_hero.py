#!/usr/bin/env python3
"""
Generate chess_hero.png — showcases the same layered piece rendering
(shadow→rim→body→highlight) used by the in-game renderer.
"""

import math, os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

BASE = os.path.dirname(os.path.abspath(__file__))

def get_font(size):
    for path in [
        "/System/Library/Fonts/Supplemental/Impact.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/Arial.ttf",
    ]:
        try: return ImageFont.truetype(path, size)
        except: pass
    return ImageFont.load_default()

def save(img, path):
    os.makedirs(os.path.dirname(path) if os.path.dirname(path) else ".", exist_ok=True)
    img.save(path, "PNG", optimize=True)
    kb = os.path.getsize(path) // 1024
    print(f"  saved {path}  {img.size}  ({kb} KB)")

# ── Canvas ────────────────────────────────────────────────────────────────────
W, H = 1440, 720
img = Image.new("RGB", (W, H))
d = ImageDraw.Draw(img)

# ── Background: rich dark wood gradient ────────────────────────────────────
for y in range(H):
    t = y / H
    r = int(16 + t * 12 + math.sin(y * 0.025) * 3)
    g = int(10 + t * 7)
    b = int(4 + t * 3)
    d.line([(0, y), (W, y)], fill=(r, g, b))

# Subtle wood grain noise
import random; random.seed(7)
for _ in range(5000):
    sx = random.randint(0, W-1); sy = random.randint(0, H-1)
    v = random.randint(0, 10)
    d.point((sx, sy), fill=(v, v//2, 0))

# Spotlight glow above board
for gr in range(380, 0, -5):
    a = int(22 * gr / 380)
    gx, gy = W//2, H//2 - 60
    d.ellipse([gx-gr, gy-gr*3//4, gx+gr, gy+gr*3//4], fill=(55, 40, 16, a) if False else (55, 40, 16))

# ── Board geometry ─────────────────────────────────────────────────────────
SQ = 72  # larger squares to showcase piece detail
BW = SQ * 8
bx = W // 2 - BW // 2
by = 24

light_sq = (240, 213, 160)
dark_sq  = (124, 82, 48)
frame_c  = (74, 40, 8)
frame_hi = (160, 108, 48)

# Board outer frame (3-layer bevel)
d.rectangle([bx-14, by-14, bx+BW+14, by+BW+14], fill=(0, 0, 0))
d.rectangle([bx-12, by-12, bx+BW+12, by+BW+12], fill=frame_c)
d.rectangle([bx-10, by-10, bx+BW+10, by+BW+10], fill=frame_hi)
d.rectangle([bx-8, by-8, bx+BW+8, by+BW+8], fill=frame_c)
d.rectangle([bx-6, by-6, bx+BW+6, by+BW+6], fill=frame_hi)

# Squares with 3D edge shading
for row in range(8):
    for col in range(8):
        is_light = (row + col) % 2 == 0
        base = light_sq if is_light else dark_sq
        x0 = bx + col * SQ; y0 = by + row * SQ
        d.rectangle([x0, y0, x0+SQ-1, y0+SQ-1], fill=base)
        hi = tuple(min(c+14, 255) for c in base)
        sh = tuple(max(c-18, 0) for c in base)
        d.line([(x0, y0), (x0+SQ-2, y0)], fill=hi)
        d.line([(x0, y0), (x0, y0+SQ-2)], fill=hi)
        d.line([(x0+1, y0+SQ-1), (x0+SQ-1, y0+SQ-1)], fill=sh)
        d.line([(x0+SQ-1, y0+1), (x0+SQ-1, y0+SQ-1)], fill=sh)

# ── Coordinate labels ───────────────────────────────────────────────────────
coord_font = get_font(14)
files = "abcdefgh"
for i in range(8):
    cx_ = bx + i * SQ + SQ // 2
    d.text((cx_, by + BW + 10), files[i], font=coord_font, fill=(100, 72, 36), anchor="mt")
    d.text((bx - 14, by + i * SQ + SQ // 2), str(8-i), font=coord_font, fill=(100, 72, 36), anchor="mm")

# ── Piece renderer (mirrors the Monkey C drawPiece function exactly) ────────
def frr(draw, x, y, w, h, rad, color):
    """filled rounded rect"""
    if w <= 1 or h <= 1: return
    rad = min(rad, w//2, h//2, 8)
    draw.rounded_rectangle([x, y, x+w-1, y+h-1], radius=rad, fill=color)

def fc(draw, x, y, rad, color):
    """filled circle"""
    if rad < 1: return
    draw.ellipse([x-rad, y-rad, x+rad, y+rad], fill=color)

def draw_piece(draw, bx_, by_, piece, s, white):
    cx  = bx_ + s // 2
    bot = by_ + s - 2

    if white:
        rim_c  = (184, 120, 48)
        body_c = (255, 240, 208)
        hl_c   = (255, 255, 255)
        shd_c  = (48, 32, 16)
        mark_c = (88, 56, 16)
    else:
        rim_c  = (200, 144, 64)
        body_c = (24, 12, 4)
        hl_c   = (90, 60, 28)
        shd_c  = (4, 1, 0)
        mark_c = (224, 184, 96)

    accent_c = (255, 208, 32)

    def r(pct): return max(1, s * pct // 100)

    if piece == 'P':
        frr(draw, cx-r(33)+1, bot-r(19)+1, r(66), r(19), 3, shd_c)
        frr(draw, cx-r(33), bot-r(19), r(66), r(19), 3, rim_c)
        frr(draw, cx-r(30), bot-r(18), r(60), r(16), 2, body_c)
        frr(draw, cx-r(11), bot-r(60), r(22), r(43), 2, rim_c)
        frr(draw, cx-r(9),  bot-r(59), r(18), r(41), 1, body_c)
        hr = max(3, r(20))
        fc(draw, cx+1, bot-r(66)+1, hr, shd_c)
        fc(draw, cx,   bot-r(66),   hr,    rim_c)
        fc(draw, cx,   bot-r(66),   hr-2,  body_c)
        fc(draw, cx - hr//3, bot-r(68), 2, hl_c)

    elif piece == 'R':
        bw  = max(8, r(52)); mW = max(2, bw//3); mH = max(3, r(18))
        frr(draw, cx-bw//2+1, bot-r(79)+1, bw, r(79), 2, shd_c)
        frr(draw, cx-r(32), bot-r(20), r(64), r(20), 3, rim_c)
        frr(draw, cx-r(29), bot-r(19), r(58), r(17), 2, body_c)
        frr(draw, cx-bw//2,   bot-r(79), bw,   r(61), 2, rim_c)
        frr(draw, cx-bw//2+1, bot-r(78), bw-2, r(59), 1, body_c)
        sW2 = max(2, r(10)); sH2 = max(3, r(22))
        frr(draw, cx-sW2//2, bot-r(65), sW2, sH2, 0, shd_c)
        for mx in [cx-bw//2, cx-mW//2, cx+bw//2-mW]:
            draw.rectangle([mx, bot-r(79)-mH, mx+mW, bot-r(79)+2], fill=rim_c)
            draw.rectangle([mx+1, bot-r(79)-mH, mx+mW-1, bot-r(79)+1], fill=body_c)
        draw.line([(cx-bw//2+2, bot-r(77)), (cx+bw//2-3, bot-r(77))], fill=hl_c, width=1)

    elif piece == 'N':
        frr(draw, cx-r(26)+1, bot-r(20)+1, r(52), r(20), 3, shd_c)
        frr(draw, cx-r(26), bot-r(20), r(52), r(20), 3, rim_c)
        frr(draw, cx-r(23), bot-r(19), r(46), r(17), 2, body_c)
        frr(draw, cx-r(20), bot-r(65), r(40), r(47), 3, rim_c)
        frr(draw, cx-r(18), bot-r(64), r(36), r(45), 2, body_c)
        frr(draw, cx-r(5)+1,  bot-r(86)+1, r(34), r(26), 5, shd_c)
        frr(draw, cx-r(5),    bot-r(86),   r(34), r(26), 5, rim_c)
        frr(draw, cx-r(3),    bot-r(85),   r(30), r(23), 4, body_c)
        frr(draw, cx+r(18), bot-r(96), r(10), r(13), 3, rim_c)
        frr(draw, cx+r(19), bot-r(95), r(8),  r(11), 2, body_c)
        eyeX = cx+r(16); eyeY = bot-r(76); eyeR = max(2, r(7))
        fc(draw, eyeX, eyeY, eyeR, rim_c)
        fc(draw, eyeX, eyeY, eyeR//2+1, shd_c)
        fc(draw, cx+r(26), bot-r(68), 2, mark_c)
        draw.line([(cx-r(14), bot-r(61)), (cx-r(4), bot-r(84))], fill=hl_c, width=1)

    elif piece == 'B':
        bwB = max(7, r(44)); bwU = bwB*7//10
        frr(draw, cx-bwB//2+1, bot-r(20)+1, bwB, r(20), 3, shd_c)
        frr(draw, cx-bwB//2,   bot-r(20),   bwB, r(20), 3, rim_c)
        frr(draw, cx-bwB//2+1, bot-r(19), bwB-2, r(17), 2, body_c)
        frr(draw, cx-bwB//2,   bot-r(52), bwB,   r(34), 3, rim_c)
        frr(draw, cx-bwB//2+1, bot-r(51), bwB-2, r(32), 2, body_c)
        frr(draw, cx-bwB//2, bot-r(55), bwB, r(7), 2, rim_c)
        draw.line([(cx-bwB//2+2, bot-r(54)), (cx+bwB//2-3, bot-r(54))], fill=hl_c, width=1)
        frr(draw, cx-bwU//2,   bot-r(69), bwU,   r(16), 2, rim_c)
        frr(draw, cx-bwU//2+1, bot-r(68), bwU-2, r(14), 1, body_c)
        orR = max(2, r(11))
        fc(draw, cx+1, bot-r(74)+1, orR, shd_c)
        fc(draw, cx,   bot-r(74),   orR, rim_c)
        fc(draw, cx,   bot-r(74),   max(1,orR-2), body_c)
        if orR > 3: fc(draw, cx-orR//3, bot-r(76), 2, hl_c)
        mBase = bot-r(77); mW2 = max(3, r(9)); mH2 = max(4, r(20))
        frr(draw, cx-mW2//2, mBase-mH2, mW2, mH2, mW2//2, rim_c)
        frr(draw, cx-mW2//2+1, mBase-mH2, mW2-2, mH2-1, max(0,mW2//2-1), body_c)
        draw.rectangle([cx-1, mBase-mH2-5, cx+1, mBase-mH2+1], fill=accent_c)
        draw.rectangle([cx-3, mBase-mH2-3, cx+3, mBase-mH2-1], fill=accent_c)

    elif piece == 'Q':
        bwQ = max(10, r(56)); pr2 = max(2, r(11))
        frr(draw, cx-bwQ//2+1, bot-r(78)+1, bwQ, r(78), 4, shd_c)
        frr(draw, cx-r(34), bot-r(20), r(68), r(20), 3, rim_c)
        frr(draw, cx-r(31), bot-r(19), r(62), r(17), 2, body_c)
        frr(draw, cx-bwQ//2,   bot-r(78), bwQ,   r(60), 4, rim_c)
        frr(draw, cx-bwQ//2+1, bot-r(77), bwQ-2, r(58), 3, body_c)
        bwW = bwQ*7//10
        frr(draw, cx-bwW//2,   bot-r(59), bwW,   r(10), 2, rim_c)
        frr(draw, cx-bwW//2+1, bot-r(58), bwW-2, r(8),  1, body_c)
        crownBase = bot-r(78)
        frr(draw, cx-bwQ//2, crownBase-r(7), bwQ, r(7), 2, accent_c)
        crownY2 = crownBase-r(8)-pr2; pearlStep = bwQ*22//100
        for pi in range(5):
            px2 = cx + (pi-2)*pearlStep
            fc(draw, px2+1, crownY2+1, pr2, shd_c)
            fc(draw, px2,   crownY2,   pr2, rim_c)
            fc(draw, px2,   crownY2,   max(1,pr2-1), accent_c if pi==2 else body_c)
            if pr2 > 3: fc(draw, px2-1, crownY2-pr2//2, 1, hl_c)
        if pr2 > 2: fc(draw, cx, crownY2, pr2-2, (255, 34, 85))
        draw.line([(cx-bwQ//2+2, bot-r(76)), (cx-bwQ//2+2, bot-r(23))], fill=hl_c, width=1)

    elif piece == 'K':
        bwK = max(10, r(58)); mWK = max(3, bwK*28//100); mHK = max(3, r(14))
        frr(draw, cx-bwK//2+1, bot-r(82)+1, bwK, r(82), 4, shd_c)
        frr(draw, cx-r(34), bot-r(20), r(68), r(20), 3, rim_c)
        frr(draw, cx-r(31), bot-r(19), r(62), r(17), 2, body_c)
        frr(draw, cx-bwK//2,   bot-r(82), bwK,   r(64), 4, rim_c)
        frr(draw, cx-bwK//2+1, bot-r(81), bwK-2, r(62), 3, body_c)
        cBase2 = bot-r(82)
        frr(draw, cx-bwK//2, cBase2-r(6), bwK, r(6), 2, accent_c)
        for mx in [cx-bwK//2, cx-mWK//2, cx+bwK//2-mWK]:
            draw.rectangle([mx,   cBase2-r(6)-mHK, mx+mWK,   cBase2-r(6)+2], fill=rim_c)
            draw.rectangle([mx+1, cBase2-r(6)-mHK, mx+mWK-1, cBase2-r(6)+1], fill=body_c)
        crossH3 = max(4, r(28)); armW3 = max(3, r(14))
        crossY3 = cBase2-r(6)-mHK-crossH3
        draw.rectangle([cx-1, crossY3+1, cx+1, crossY3+crossH3+1], fill=shd_c)
        draw.rectangle([cx-armW3//2+1, crossY3+crossH3*4//10+1, cx+armW3//2, crossY3+crossH3*4//10+4], fill=shd_c)
        draw.rectangle([cx-1,         crossY3,             cx+1,         crossY3+crossH3],   fill=accent_c)
        draw.rectangle([cx-armW3//2,  crossY3+crossH3*4//10, cx+armW3//2, crossY3+crossH3*4//10+3], fill=accent_c)
        draw.line([(cx-1, crossY3), (cx-1, crossY3+crossH3)], fill=(255,255,128), width=1)
        draw.line([(cx-bwK//2+2, bot-r(80)), (cx-bwK//2+2, bot-r(23))], fill=hl_c, width=1)

# ── Board position (mid-game, showing all 6 piece types) ──────────────────
# col, row, piece, white  (row 0 = rank 8 = black's back rank in image coords)
board_pos = [
    # Black pieces
    (0, 0, 'R', False), (4, 0, 'K', False), (7, 0, 'R', False),
    (3, 1, 'Q', False),
    (0, 1, 'P', False), (2, 2, 'P', False), (4, 1, 'P', False),
    (5, 1, 'P', False), (7, 1, 'P', False),
    (5, 2, 'N', False), (2, 0, 'B', False),
    # White pieces
    (0, 7, 'R', True),  (7, 7, 'R', True),
    (3, 6, 'Q', True),
    (4, 7, 'K', True),
    (1, 6, 'P', True),  (2, 5, 'P', True),  (5, 6, 'P', True),
    (6, 6, 'P', True),  (7, 6, 'P', True),
    (2, 4, 'N', True),  (5, 5, 'B', True),
]

# Tint legal-move destination squares (white queen at d2 scenario)
legal_targets = [(4, 4), (4, 3), (5, 4)]  # some empty destination squares
capture_target = (5, 2)  # N capture target shown with corner brackets

for (tc, tr) in legal_targets:
    is_light = (tr + tc) % 2 == 0
    tint = (190, 220, 110) if is_light else (51, 102, 24)
    d.rectangle([bx+tc*SQ, by+tr*SQ, bx+tc*SQ+SQ-1, by+tr*SQ+SQ-1], fill=tint)

# Draw pieces
for (col, row, piece, white) in board_pos:
    draw_piece(d, bx + col*SQ, by + row*SQ, piece, SQ, white)

# ── Overlay: legal move dots on empty squares ──────────────────────────────
for (tc, tr) in legal_targets:
    cx_ = bx + tc*SQ + SQ//2; cy_ = by + tr*SQ + SQ//2
    dr = SQ * 28 // 100
    d.ellipse([cx_-dr-2, cy_-dr-2, cx_+dr+2, cy_+dr+2], fill=(10, 76, 10))
    d.ellipse([cx_-dr, cy_-dr, cx_+dr, cy_+dr], fill=(0, 204, 68))
    d.ellipse([cx_-dr//2, cy_-dr//2, cx_+dr//2, cy_+dr//2], fill=(136, 255, 153))

# ── Overlay: green capture brackets on black knight at (5,2) ──────────────
def corner_brackets(draw, bx_, by_, s, color, thick=2, arm=None):
    arm = arm or max(4, s//4)
    draw.rectangle([bx_,         by_,          bx_+arm,     by_+thick-1],    fill=color)
    draw.rectangle([bx_,         by_,          bx_+thick-1, by_+arm],        fill=color)
    draw.rectangle([bx_+s-arm,   by_,          bx_+s,       by_+thick-1],    fill=color)
    draw.rectangle([bx_+s-thick, by_,          bx_+s,       by_+arm],        fill=color)
    draw.rectangle([bx_,         by_+s-thick,  bx_+arm,     by_+s],          fill=color)
    draw.rectangle([bx_,         by_+s-arm,    bx_+thick-1, by_+s],          fill=color)
    draw.rectangle([bx_+s-arm,   by_+s-thick,  bx_+s,       by_+s],          fill=color)
    draw.rectangle([bx_+s-thick, by_+s-arm,    bx_+s,       by_+s],          fill=color)

tc, tr = capture_target
corner_brackets(d, bx+tc*SQ, by+tr*SQ, SQ, (0, 204, 51), thick=3, arm=12)

# ── Overlay: SELECTED piece — white queen d6 (col=3, row=2) ───────────────
sel_col, sel_row = 3, 3
# golden square tint
is_light = (sel_row + sel_col) % 2 == 0
d.rectangle([bx+sel_col*SQ, by+sel_row*SQ, bx+sel_col*SQ+SQ-1, by+sel_row*SQ+SQ-1],
            fill=(221, 187, 40) if is_light else (154, 122, 6))
# redraw piece on top
draw_piece(d, bx+sel_col*SQ, by+sel_row*SQ, 'Q', SQ, True)
# golden selection brackets (thick)
corner_brackets(d, bx+sel_col*SQ, by+sel_row*SQ, SQ, (255, 136, 0), thick=4, arm=16)

# ── Overlay: CURSOR — cyan brackets on (4,4) ─────────────────────────────
cur_col, cur_row = 4, 4
corner_brackets(d, bx+cur_col*SQ, by+cur_row*SQ, SQ, (0, 204, 255), thick=3, arm=13)

# ── CHECK! king square at (4,0) black king ────────────────────────────────
d.rectangle([bx+4*SQ, by+0*SQ, bx+4*SQ+SQ-1, by+0*SQ+SQ-1], fill=(187, 30, 30))
draw_piece(d, bx+4*SQ, by+0*SQ, 'K', SQ, False)

# ── Captured pieces (sides) ───────────────────────────────────────────────
cap_s = 34
cap_font_pieces = [('N', True), ('B', True), ('P', True)]
for i, (p, w) in enumerate(cap_font_pieces):
    draw_piece(d, bx - 52, by + i * (cap_s + 6) + 10, p, cap_s, w)

cap_bl_pieces = [('P', False), ('P', False), ('R', False)]
for i, (p, w) in enumerate(cap_bl_pieces):
    draw_piece(d, bx + BW + 18, by + i * (cap_s + 6) + 10, p, cap_s, w)

# ── Feature badge strip ────────────────────────────────────────────────────
badge_x = bx + BW + 70
badge_y = by + BW // 2 - 80
badges = [
    "BEAUTIFUL PIECES",
    "3 AI LEVELS",
    "3 GAME MODES",
    "SIDE SELECTION",
    "CHECK DETECTION",
    "PROMOTION",
]
bf = get_font(16)
for i, txt in enumerate(badges):
    by_ = badge_y + i * 30
    bw_ = 180; bh_ = 22
    bx_ = badge_x
    d.rounded_rectangle([bx_, by_, bx_+bw_, by_+bh_], radius=4, fill=(40, 24, 8))
    d.rounded_rectangle([bx_, by_, bx_+bw_, by_+bh_], radius=4, outline=(160, 108, 48), width=1)
    # gold bullet
    d.ellipse([bx_+8, by_+bh_//2-4, bx_+16, by_+bh_//2+4], fill=(255, 200, 40))
    d.text((bx_+22, by_+bh_//2), txt, font=bf, fill=(220, 190, 140), anchor="lm")

# ── Title area ─────────────────────────────────────────────────────────────
title_y = by + BW + 18
tf  = get_font(80)
sf  = get_font(22)
hlf = get_font(18)

title = "BITOCHI CHESS"
# Shadow
d.text((W//2+3, title_y+3), title, font=tf, fill=(0,0,0,200), anchor="mt")
# Gold title
d.text((W//2,   title_y),   title, font=tf, fill=(255, 210, 70), anchor="mt")

# Decorative separator
line_y = title_y - 10
lw = 220
d.line([(W//2-lw, line_y), (W//2+lw, line_y)], fill=(80, 55, 25), width=1)
ds = 5
d.polygon([(W//2, line_y-ds), (W//2+ds, line_y), (W//2, line_y+ds), (W//2-ds, line_y)], fill=(140, 95, 45))

sub = "Garmin Watch Chess  ·  3 AI Levels  ·  P vs AI / P vs P / AI vs AI  ·  Side Choice"
d.text((W//2, title_y+78), sub, font=sf, fill=(155, 130, 95), anchor="mt")

# Feature callout labels near the board overlays
note_f = get_font(13)
# "SELECTED" label near golden brackets
sx_ = bx + sel_col*SQ + SQ//2; sy_ = by + sel_row*SQ - 14
d.rounded_rectangle([sx_-36, sy_-2, sx_+36, sy_+13], radius=3, fill=(60, 36, 0))
d.text((sx_, sy_+5), "SELECTED", font=note_f, fill=(255, 196, 0), anchor="mm")

# "CURSOR" label near cyan brackets
cx__ = bx + cur_col*SQ + SQ//2; cy__ = by + cur_row*SQ - 14
d.rounded_rectangle([cx__-28, cy__-2, cx__+28, cy__+13], radius=3, fill=(0, 24, 48))
d.text((cx__, cy__+5), "CURSOR", font=note_f, fill=(0, 204, 255), anchor="mm")

# "CHECK!" label over red king square
kx_ = bx + 4*SQ + SQ//2; ky_ = by - 14
d.rounded_rectangle([kx_-28, ky_-2, kx_+28, ky_+13], radius=3, fill=(120, 0, 0))
d.text((kx_, ky_+5), "CHECK!", font=note_f, fill=(255, 80, 80), anchor="mm")

# ── Vignette ──────────────────────────────────────────────────────────────
vig = Image.new("RGBA", (W, H), (0,0,0,0))
vd  = ImageDraw.Draw(vig)
for i in range(80):
    a = int(2.2 * i)
    vd.rectangle([i, i, W-i, H-i], outline=(0,0,0,a))
img_rgba = img.convert("RGBA")
img_rgba.alpha_composite(vig)
img_out = img_rgba.convert("RGB")

save(img_out, os.path.join(BASE, "chess_hero.png"))

print("Done!")
