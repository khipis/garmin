#!/usr/bin/env python3
"""
Generate chess_hero.png — premium 2x supersampled render mirroring the
in-game piece renderer (silhouette → rim → body → mid-band → highlight → sparkle).
"""

import math, os, random
from PIL import Image, ImageDraw, ImageFont, ImageFilter

random.seed(11)
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

def get_serif(size):
    for path in [
        "/System/Library/Fonts/Supplemental/Times New Roman.ttf",
        "/System/Library/Fonts/Times.ttc",
        "/System/Library/Fonts/Supplemental/Georgia.ttf",
    ]:
        try: return ImageFont.truetype(path, size)
        except: pass
    return get_font(size)

def save(img, path):
    os.makedirs(os.path.dirname(path) if os.path.dirname(path) else ".", exist_ok=True)
    img.save(path, "PNG", optimize=True)
    kb = os.path.getsize(path) // 1024
    print(f"  saved {path}  {img.size}  ({kb} KB)")

# ── Final size + 2x supersample ───────────────────────────────────────────
W_OUT, H_OUT = 1440, 720
SS = 2
W, H = W_OUT * SS, H_OUT * SS

img = Image.new("RGB", (W, H))
d   = ImageDraw.Draw(img)

# ── Background: rich dark wood gradient ───────────────────────────────────
for y in range(H):
    t = y / H
    r = int(14 + t * 14 + math.sin(y * 0.018) * 4)
    g = int(8  + t * 8)
    b = int(3  + t * 3)
    d.line([(0, y), (W, y)], fill=(r, g, b))

# Wood grain noise
for _ in range(8000):
    sx = random.randint(0, W-1); sy = random.randint(0, H-1)
    v  = random.randint(0, 12)
    d.point((sx, sy), fill=(v, v//2, 0))

# ── Spotlight halo behind board ───────────────────────────────────────────
glow = Image.new("RGB", (W, H), (0, 0, 0))
gd   = ImageDraw.Draw(glow)
for gr in range(900*SS//2, 0, -8):
    a = int(40 * gr / (900*SS//2))
    if a < 1: continue
    gd.ellipse([W//2-gr, H//2-gr*4//5, W//2+gr, H//2+gr*4//5],
               fill=(min(64,a), min(48,a*3//4), min(20,a//3)))
glow_blur = glow.filter(ImageFilter.GaussianBlur(20*SS))
img = Image.blend(img.convert("RGB"), glow_blur, 0.35)
d = ImageDraw.Draw(img)

# Re-paint base over glow but only outer edges
# (we want glow to show in middle, so leave middle alone)

# ── Board geometry ────────────────────────────────────────────────────────
SQ = 78 * SS  # bigger pieces
BW = SQ * 8
bx = W // 2 - BW // 2
by = 30 * SS

light_sq = (240, 213, 158)
dark_sq  = (122, 80, 44)

# ── Board outer frame (5-layer bevel) ─────────────────────────────────────
fp = SS  # frame px scale
d.rectangle([bx - 14*fp, by - 14*fp, bx + BW + 14*fp, by + BW + 14*fp], fill=(0,0,0))
d.rectangle([bx - 12*fp, by - 12*fp, bx + BW + 12*fp, by + BW + 12*fp], fill=(58, 30, 6))
d.rectangle([bx - 10*fp, by - 10*fp, bx + BW + 10*fp, by + BW + 10*fp], fill=(180, 120, 56))
d.rectangle([bx -  8*fp, by -  8*fp, bx + BW +  8*fp, by + BW +  8*fp], fill=(74, 38, 8))
d.rectangle([bx -  6*fp, by -  6*fp, bx + BW +  6*fp, by + BW +  6*fp], fill=(210, 156, 78))
d.rectangle([bx -  4*fp, by -  4*fp, bx + BW +  4*fp, by + BW +  4*fp], fill=(60, 30, 8))

# Board inner squares with edge shading
for row in range(8):
    for col in range(8):
        is_light = (row + col) % 2 == 0
        base = light_sq if is_light else dark_sq
        x0 = bx + col * SQ; y0 = by + row * SQ
        d.rectangle([x0, y0, x0+SQ-1, y0+SQ-1], fill=base)
        hi = tuple(min(c+18, 255) for c in base)
        sh = tuple(max(c-22, 0) for c in base)
        d.line([(x0, y0), (x0+SQ-2, y0)], fill=hi)
        d.line([(x0, y0), (x0, y0+SQ-2)], fill=hi)
        d.line([(x0+1, y0+SQ-1), (x0+SQ-1, y0+SQ-1)], fill=sh)
        d.line([(x0+SQ-1, y0+1), (x0+SQ-1, y0+SQ-1)], fill=sh)

# ── Coordinate labels ─────────────────────────────────────────────────────
coord_font = get_font(16 * SS)
files = "abcdefgh"
for i in range(8):
    cx_ = bx + i * SQ + SQ // 2
    d.text((cx_, by + BW + 10*SS), files[i], font=coord_font, fill=(120, 88, 48), anchor="mt")
    d.text((bx - 16*SS, by + i * SQ + SQ // 2), str(8-i), font=coord_font, fill=(120, 88, 48), anchor="mm")

# ── Piece renderer (mirrors Monkey C drawPiece exactly) ───────────────────
def frr(draw, x, y, w, h, rad, color):
    if w <= 1 or h <= 1: return
    rad = min(rad, w//2, h//2, 18)
    draw.rounded_rectangle([x, y, x+w-1, y+h-1], radius=rad, fill=color)

def fc(draw, x, y, rad, color):
    if rad < 1: return
    draw.ellipse([x-rad, y-rad, x+rad, y+rad], fill=color)

def fpoly(draw, pts, color):
    draw.polygon([tuple(p) for p in pts], fill=color)

def line(draw, x1, y1, x2, y2, color, width=1):
    draw.line([(x1,y1),(x2,y2)], fill=color, width=width)

def fr(draw, x, y, w, h, color):
    if w <= 0 or h <= 0: return
    draw.rectangle([x, y, x+w-1, y+h-1], fill=color)

def draw_piece(draw, bx_, by_, piece, s, white):
    cx  = bx_ + s // 2
    bot = by_ + s - 2
    if white:
        sil_c, rim_c, body_c, mid_c, hl_c, shd_c, mark_c = \
            (42,24,8), (168,112,44), (255,244,220), (210,166,114), \
            (255,255,255), (20,10,4), (88,56,16)
    else:
        sil_c, rim_c, body_c, mid_c, hl_c, shd_c, mark_c = \
            (232,184,80), (106,66,20), (8,4,0), (42,24,8), \
            (164,112,40), (0,0,0), (224,184,96)
    gold_c   = (255, 208, 40)
    gold_hi  = (255, 234, 136)
    ruby_c   = (232, 40, 74)
    ruby_hi  = (255, 112, 144)
    def r(p): return max(1, s * p // 100)

    # ground shadow
    frr(draw, cx-r(36), bot-1, r(72), 3, 1, shd_c)

    if piece == 'P':
        hr = max(4, r(22))
        frr(draw, cx-r(36), bot-r(22), r(72), r(22), 4, sil_c)
        frr(draw, cx-r(34), bot-r(21), r(68), r(19), 3, rim_c)
        frr(draw, cx-r(32), bot-r(20), r(64), r(16), 2, body_c)
        frr(draw, cx-r(32), bot-r(8),  r(64), r(4),  1, mid_c)
        line(draw, cx-r(30), bot-r(19), cx+r(30), bot-r(19), hl_c, 1)

        frr(draw, cx-r(22), bot-r(30), r(44), r(10), 3, sil_c)
        frr(draw, cx-r(20), bot-r(29), r(40), r(8),  2, rim_c)

        frr(draw, cx-r(13), bot-r(60), r(26), r(32), 3, sil_c)
        frr(draw, cx-r(12), bot-r(59), r(24), r(30), 2, rim_c)
        frr(draw, cx-r(10), bot-r(58), r(20), r(27), 1, body_c)
        fr(draw, cx+r(4), bot-r(38), r(6), r(6), mid_c)
        fr(draw, cx-r(8), bot-r(55), 2, r(22), hl_c)

        fc(draw, cx+1, bot-r(66)+1, hr, shd_c)
        fc(draw, cx,   bot-r(66),   hr,    sil_c)
        fc(draw, cx,   bot-r(66),   hr-1,  rim_c)
        fc(draw, cx,   bot-r(66),   hr-2,  body_c)
        if hr > 4:
            fc(draw, cx + hr//3, bot-r(66) + hr//3, hr*3//5, mid_c)
        if hr > 5:
            fc(draw, cx, bot-r(66), hr-4, body_c)
        if hr > 4:
            fc(draw, cx - hr*3//8, bot-r(66) - hr*3//8, hr//3, hl_c)
        if hr > 6:
            fc(draw, cx - hr*5//8, bot-r(66) - hr*5//8 + 1, 1, hl_c)

    elif piece == 'R':
        bw = max(9, r(54)); mW = max(2, bw//3); mH = max(3, r(16))
        frr(draw, cx-r(34), bot-r(22), r(68), r(22), 3, sil_c)
        frr(draw, cx-r(32), bot-r(21), r(64), r(19), 2, rim_c)
        frr(draw, cx-r(30), bot-r(20), r(60), r(16), 2, body_c)
        fr(draw, cx-r(30), bot-r(8), r(60), r(3), mid_c)

        frr(draw, cx-r(30), bot-r(30), r(60), r(9), 2, sil_c)
        frr(draw, cx-r(28), bot-r(29), r(56), r(7), 1, rim_c)

        frr(draw, cx-bw//2,   bot-r(82), bw,   r(52), 2, sil_c)
        frr(draw, cx-bw//2+1, bot-r(81), bw-2, r(50), 1, rim_c)
        frr(draw, cx-bw//2+2, bot-r(80), bw-4, r(48), 1, body_c)
        fr(draw, cx+bw//2-5, bot-r(78), 3, r(44), mid_c)

        sW2 = max(2, r(10)); sH2 = max(3, r(22))
        frr(draw, cx-sW2//2-1, bot-r(65)-1, sW2+2, sH2+2, 1, sil_c)
        frr(draw, cx-sW2//2, bot-r(65), sW2, sH2, 1, shd_c)
        line(draw, cx-sW2//2+1, bot-r(65)+1, cx-sW2//2+1, bot-r(65)+sH2-2,
             (200,164,124) if white else (48,24,8), 1)

        line(draw, cx-bw//2+2, bot-r(78), cx+bw//2-4, bot-r(78), hl_c, 1)

        for ti in range(3):
            mx = (cx-bw//2) if ti==0 else ((cx-mW//2) if ti==1 else (cx+bw//2-mW))
            fr(draw, mx-1, bot-r(82)-mH-1, mW+2, mH+3, sil_c)
            fr(draw, mx,   bot-r(82)-mH,   mW,   mH+2, rim_c)
            fr(draw, mx+1, bot-r(82)-mH,   mW-2, mH,   body_c)
            line(draw, mx+1, bot-r(82)-mH, mx+mW-2, bot-r(82)-mH, hl_c, 1)

    elif piece == 'N':
        # base
        frr(draw, cx-r(30), bot-r(22), r(60), r(22), 3, sil_c)
        frr(draw, cx-r(28), bot-r(21), r(56), r(19), 2, rim_c)
        frr(draw, cx-r(26), bot-r(20), r(52), r(16), 2, body_c)
        fr(draw, cx-r(26), bot-r(8), r(52), r(3), mid_c)

        # body / chest
        frr(draw, cx-r(22), bot-r(60), r(44), r(40), 4, sil_c)
        frr(draw, cx-r(21), bot-r(59), r(42), r(38), 3, rim_c)
        frr(draw, cx-r(19), bot-r(58), r(38), r(35), 2, body_c)

        # horse head as polygon (faces right)
        pts = [
            (cx-r(16), bot-r(60)),
            (cx-r(18), bot-r(72)),
            (cx-r(12), bot-r(82)),
            (cx+r(4),  bot-r(92)),
            (cx+r(10), bot-r(98)),
            (cx+r(16), bot-r(92)),
            (cx+r(22), bot-r(86)),
            (cx+r(28), bot-r(78)),
            (cx+r(30), bot-r(70)),
            (cx+r(28), bot-r(64)),
            (cx+r(20), bot-r(60)),
            (cx+r(8),  bot-r(58)),
        ]
        # silhouette polygon (1px expanded outward)
        pts_sil = [
            (pts[0][0]-1,  pts[0][1]+1),
            (pts[1][0]-1,  pts[1][1]),
            (pts[2][0],    pts[2][1]-1),
            (pts[3][0],    pts[3][1]-1),
            (pts[4][0]+1,  pts[4][1]-1),
            (pts[5][0]+1,  pts[5][1]-1),
            (pts[6][0]+1,  pts[6][1]-1),
            (pts[7][0]+1,  pts[7][1]),
            (pts[8][0]+1,  pts[8][1]+1),
            (pts[9][0]+1,  pts[9][1]+1),
            (pts[10][0]+1, pts[10][1]+1),
            (pts[11][0],   pts[11][1]+1),
        ]
        fpoly(draw, pts_sil, sil_c)
        fpoly(draw, pts, rim_c)
        pts_in = [
            (pts[0][0]+1,  pts[0][1]-1),
            (pts[1][0]+1,  pts[1][1]),
            (pts[2][0]+1,  pts[2][1]+1),
            (pts[3][0]+1,  pts[3][1]+1),
            (pts[4][0],    pts[4][1]+2),
            (pts[5][0]-1,  pts[5][1]+1),
            (pts[6][0]-1,  pts[6][1]+1),
            (pts[7][0]-1,  pts[7][1]),
            (pts[8][0]-1,  pts[8][1]-1),
            (pts[9][0]-1,  pts[9][1]-1),
            (pts[10][0]-1, pts[10][1]-1),
            (pts[11][0],   pts[11][1]-1),
        ]
        fpoly(draw, pts_in, body_c)

        # eye
        eyeX = cx + r(15); eyeY = bot - r(80); eyeR = max(2, r(7))
        fc(draw, eyeX, eyeY, eyeR+1, sil_c)
        fc(draw, eyeX, eyeY, eyeR, rim_c)
        fc(draw, eyeX, eyeY, eyeR-1 if eyeR>2 else 1, body_c)
        fc(draw, eyeX-1, eyeY-1, 1, (255,255,255) if white else (255,208,136))

        fc(draw, cx+r(26), bot-r(68), 2, mark_c)
        line(draw, cx+r(22), bot-r(64), cx+r(28), bot-r(65), sil_c, 1)

        line(draw, cx-r(14), bot-r(64), cx-r(4), bot-r(82), hl_c, 1)
        line(draw, cx-r(8),  bot-r(64), cx-r(0), bot-r(84), hl_c, 1)
        fr(draw, cx-r(17), bot-r(55), 2, r(30), hl_c)

    elif piece == 'B':
        bwB = max(8, r(46)); bwU = bwB*7//10

        # base
        frr(draw, cx-r(30), bot-r(22), r(60), r(22), 3, sil_c)
        frr(draw, cx-r(28), bot-r(21), r(56), r(19), 2, rim_c)
        frr(draw, cx-r(26), bot-r(20), r(52), r(16), 2, body_c)
        fr(draw, cx-r(26), bot-r(8), r(52), r(3), mid_c)

        # lower body
        frr(draw, cx-bwB//2-1, bot-r(55), bwB+2, r(36), 4, sil_c)
        frr(draw, cx-bwB//2,   bot-r(54), bwB,   r(34), 3, rim_c)
        frr(draw, cx-bwB//2+1, bot-r(53), bwB-2, r(31), 2, body_c)
        fr(draw, cx+bwB//2-4, bot-r(50), 2, r(28), mid_c)
        fr(draw, cx-bwB//2+2, bot-r(50), 2, r(26), hl_c)

        # collar (gold band)
        frr(draw, cx-bwB//2-1, bot-r(60), bwB+2, r(9), 2, sil_c)
        frr(draw, cx-bwB//2, bot-r(59), bwB, r(7), 1, gold_c)
        line(draw, cx-bwB//2+1, bot-r(58), cx+bwB//2-2, bot-r(58), gold_hi, 1)

        # upper body
        frr(draw, cx-bwU//2-1, bot-r(72), bwU+2, r(16), 3, sil_c)
        frr(draw, cx-bwU//2,   bot-r(71), bwU,   r(14), 2, rim_c)
        frr(draw, cx-bwU//2+1, bot-r(70), bwU-2, r(12), 1, body_c)

        # bishop cut
        line(draw, cx-bwU//2+2, bot-r(68), cx+bwU//2-2, bot-r(64), sil_c, 1)
        line(draw, cx-bwU//2+2, bot-r(67), cx+bwU//2-2, bot-r(63), mid_c, 1)

        # orb
        orR = max(3, r(12))
        fc(draw, cx+1, bot-r(78)+1, orR, shd_c)
        fc(draw, cx, bot-r(78), orR, sil_c)
        fc(draw, cx, bot-r(78), orR-1, rim_c)
        fc(draw, cx, bot-r(78), orR-2, body_c)
        if orR > 3: fc(draw, cx + orR//3, bot-r(78) + orR//3, orR*3//5, mid_c)
        if orR > 4: fc(draw, cx, bot-r(78), orR-4, body_c)
        if orR > 3: fc(draw, cx - orR*3//8, bot-r(78) - orR*3//8, orR//3, hl_c)
        if orR > 5: fc(draw, cx - orR*5//8, bot-r(78) - orR*5//8, 1, hl_c)

        # mitre as polygon
        mBase = bot - r(84); mW2 = max(3, r(11)); mH2 = max(5, r(22))
        mPts = [
            (cx-mW2//2-1, mBase+2),
            (cx-mW2//2,   mBase-mH2*2//3),
            (cx-1,        mBase-mH2),
            (cx+1,        mBase-mH2),
            (cx+mW2//2,   mBase-mH2*2//3),
            (cx+mW2//2+1, mBase+2),
        ]
        mPtsIn = [
            (cx-mW2//2+1, mBase+1),
            (cx-mW2//2+1, mBase-mH2*2//3),
            (cx-1,        mBase-mH2+1),
            (cx+1,        mBase-mH2+1),
            (cx+mW2//2-1, mBase-mH2*2//3),
            (cx+mW2//2-1, mBase+1),
        ]
        fpoly(draw, mPts, sil_c)
        fpoly(draw, mPtsIn, rim_c)
        frr(draw, cx-mW2//2+2, mBase-mH2*2//3, mW2-4, mH2*2//3+1, 1, body_c)
        line(draw, cx-mW2//2+2, mBase-mH2*2//3+1, cx-mW2//2+2, mBase, hl_c, 1)

        # gold cross on tip
        crossT = mBase - mH2 - (7 if s > 22*SS else 5)
        fr(draw, cx-2, crossT, 5, mH2//2+2, sil_c)
        fr(draw, cx-4, crossT+2, 9, 4, sil_c)
        fr(draw, cx-1, crossT+1, 3, mH2//2, gold_c)
        fr(draw, cx-3, crossT+3, 7, 2, gold_c)
        fr(draw, cx-1, crossT+1, 1, mH2//2, gold_hi)

    elif piece == 'Q':
        bwQ = max(11, r(60)); pr2 = max(3, r(12))

        # base
        frr(draw, cx-r(36), bot-r(22), r(72), r(22), 3, sil_c)
        frr(draw, cx-r(34), bot-r(21), r(68), r(19), 2, rim_c)
        frr(draw, cx-r(32), bot-r(20), r(64), r(16), 2, body_c)
        fr(draw, cx-r(32), bot-r(8), r(64), r(3), mid_c)
        line(draw, cx-r(30), bot-r(19), cx+r(30), bot-r(19), hl_c, 1)

        # lower bell
        frr(draw, cx-bwQ//2-1, bot-r(52), bwQ+2, r(32), 5, sil_c)
        frr(draw, cx-bwQ//2,   bot-r(51), bwQ,   r(30), 4, rim_c)
        frr(draw, cx-bwQ//2+1, bot-r(50), bwQ-2, r(27), 3, body_c)
        fr(draw, cx+bwQ//2-4, bot-r(48), 2, r(24), mid_c)

        # waist
        bwW = bwQ * 65 // 100
        frr(draw, cx-bwW//2-1, bot-r(60), bwW+2, r(12), 3, sil_c)
        frr(draw, cx-bwW//2,   bot-r(59), bwW,   r(10), 2, rim_c)
        frr(draw, cx-bwW//2+1, bot-r(58), bwW-2, r(8),  1, body_c)

        # upper torso
        bwT = bwQ * 80 // 100
        frr(draw, cx-bwT//2-1, bot-r(78), bwT+2, r(22), 4, sil_c)
        frr(draw, cx-bwT//2,   bot-r(77), bwT,   r(20), 3, rim_c)
        frr(draw, cx-bwT//2+1, bot-r(76), bwT-2, r(17), 2, body_c)
        fr(draw, cx-bwT//2+2, bot-r(74), 2, r(14), hl_c)

        # crown ring
        crownBase = bot - r(78)
        frr(draw, cx-bwQ//2-1, crownBase-r(8), bwQ+2, r(9), 2, sil_c)
        frr(draw, cx-bwQ//2, crownBase-r(7), bwQ, r(7), 1, gold_c)
        line(draw, cx-bwQ//2+1, crownBase-r(6), cx+bwQ//2-2, crownBase-r(6), gold_hi, 1)

        # 5 pearls with spikes
        crownY2 = crownBase - r(8) - pr2
        pearlStep = bwQ * 22 // 100
        for pi in range(5):
            px2 = cx + (pi-2) * pearlStep
            fr(draw, px2-1, crownY2+1, 2, r(7), gold_c)
            fc(draw, px2+1, crownY2+1, pr2, shd_c)
            fc(draw, px2,   crownY2,   pr2, sil_c)
            fc(draw, px2,   crownY2,   pr2-1, gold_c if pi==2 else rim_c)
            fc(draw, px2,   crownY2,   pr2-2 if pr2>2 else 1, ruby_c if pi==2 else body_c)
            if pr2 > 3:
                fc(draw, px2-1, crownY2-pr2//2, 2 if pr2>4 else 1, ruby_hi if pi==2 else hl_c)
            if pr2 > 5 and pi == 2:
                fc(draw, px2-pr2//3, crownY2-pr2//2, 1, (255,255,255))

        # collar gold band
        frr(draw, cx-bwT//2+1, bot-r(60), bwT-2, r(3), 1, gold_c)

    elif piece == 'K':
        bwK = max(11, r(60)); mWK = max(3, bwK*28//100); mHK = max(3, r(13))

        # base
        frr(draw, cx-r(36), bot-r(22), r(72), r(22), 3, sil_c)
        frr(draw, cx-r(34), bot-r(21), r(68), r(19), 2, rim_c)
        frr(draw, cx-r(32), bot-r(20), r(64), r(16), 2, body_c)
        fr(draw, cx-r(32), bot-r(8), r(64), r(3), mid_c)
        line(draw, cx-r(30), bot-r(19), cx+r(30), bot-r(19), hl_c, 1)

        # lower bell
        frr(draw, cx-bwK//2-1, bot-r(52), bwK+2, r(32), 5, sil_c)
        frr(draw, cx-bwK//2,   bot-r(51), bwK,   r(30), 4, rim_c)
        frr(draw, cx-bwK//2+1, bot-r(50), bwK-2, r(27), 3, body_c)
        fr(draw, cx+bwK//2-4, bot-r(48), 2, r(24), mid_c)

        # waist
        bwKW = bwK * 65 // 100
        frr(draw, cx-bwKW//2-1, bot-r(60), bwKW+2, r(12), 3, sil_c)
        frr(draw, cx-bwKW//2,   bot-r(59), bwKW,   r(10), 2, rim_c)
        frr(draw, cx-bwKW//2+1, bot-r(58), bwKW-2, r(8),  1, body_c)

        # upper torso
        bwKT = bwK * 80 // 100
        frr(draw, cx-bwKT//2-1, bot-r(82), bwKT+2, r(26), 4, sil_c)
        frr(draw, cx-bwKT//2,   bot-r(81), bwKT,   r(24), 3, rim_c)
        frr(draw, cx-bwKT//2+1, bot-r(80), bwKT-2, r(21), 2, body_c)
        fr(draw, cx-bwKT//2+2, bot-r(78), 2, r(16), hl_c)

        # crown ring
        cBase2 = bot - r(82)
        frr(draw, cx-bwK//2-1, cBase2-r(7), bwK+2, r(8), 2, sil_c)
        frr(draw, cx-bwK//2, cBase2-r(6), bwK, r(6), 1, gold_c)
        line(draw, cx-bwK//2+1, cBase2-r(5), cx+bwK//2-2, cBase2-r(5), gold_hi, 1)

        # 3 battlements
        for ki in range(3):
            kmx = (cx-bwK//2) if ki==0 else ((cx-mWK//2) if ki==1 else (cx+bwK//2-mWK))
            fr(draw, kmx-1, cBase2-r(7)-mHK-1, mWK+2, mHK+3, sil_c)
            fr(draw, kmx,   cBase2-r(7)-mHK,   mWK,   mHK+2, rim_c)
            fr(draw, kmx+1, cBase2-r(7)-mHK,   mWK-2, mHK,   body_c)
            line(draw, kmx+1, cBase2-r(7)-mHK, kmx+mWK-2, cBase2-r(7)-mHK, hl_c, 1)
            if ki == 1 and mWK > 3:
                fc(draw, cx, cBase2-r(7)-mHK//2, mWK//3+1, ruby_c)
                if mWK > 5:
                    fc(draw, cx-1, cBase2-r(7)-mHK//2-1, 1, ruby_hi)

        # cross
        crossH3 = max(5, r(30)); armW3 = max(4, r(16))
        crossY3 = cBase2 - r(7) - mHK - crossH3
        fr(draw, cx-3, crossY3-1, 6, crossH3+2, sil_c)
        fr(draw, cx-armW3//2-1, crossY3+crossH3*4//10-1, armW3+2, 5, sil_c)
        fr(draw, cx-2, crossY3, 4, crossH3, gold_c)
        fr(draw, cx-armW3//2, crossY3+crossH3*4//10, armW3, 3, gold_c)
        fr(draw, cx-2, crossY3, 1, crossH3, gold_hi)
        fr(draw, cx-armW3//2, crossY3+crossH3*4//10, armW3-1, 1, gold_hi)
        fr(draw, cx-2, crossY3, 2, 2, (255,255,255))

# ── Board position (showcases all 6 piece types) ─────────────────────────
board_pos = [
    # Black back rank (top)
    (0,0,'R',False), (2,0,'B',False), (4,0,'K',False), (7,0,'R',False),
    (3,1,'Q',False),
    (0,1,'P',False), (2,2,'P',False), (4,1,'P',False),
    (5,1,'P',False), (7,1,'P',False),
    (5,2,'N',False),
    # White (bottom)
    (0,7,'R',True), (7,7,'R',True),
    (3,6,'Q',True),
    (4,7,'K',True),
    (1,6,'P',True), (2,5,'P',True), (5,6,'P',True),
    (6,6,'P',True), (7,6,'P',True),
    (2,4,'N',True), (5,5,'B',True),
]

# Highlights
legal_targets = [(4,4),(4,3),(5,4)]
capture_target = (5,2)
sel_col, sel_row = 3, 3
cur_col, cur_row = 4, 4
check_col, check_row = 4, 0

# Tint legal squares (green)
for (tc, tr) in legal_targets:
    is_light = (tr+tc) % 2 == 0
    tint = (190, 220, 110) if is_light else (51, 102, 24)
    d.rectangle([bx+tc*SQ, by+tr*SQ, bx+tc*SQ+SQ-1, by+tr*SQ+SQ-1], fill=tint)

# Selection square: gold tint
is_light = (sel_row+sel_col) % 2 == 0
d.rectangle([bx+sel_col*SQ, by+sel_row*SQ, bx+sel_col*SQ+SQ-1, by+sel_row*SQ+SQ-1],
            fill=(221, 187, 40) if is_light else (154, 122, 6))

# Check square: red
d.rectangle([bx+check_col*SQ, by+check_row*SQ, bx+check_col*SQ+SQ-1, by+check_row*SQ+SQ-1],
            fill=(187, 30, 30))

# Draw all pieces (with selected piece overdrawn)
for (col, row, piece, white) in board_pos:
    draw_piece(d, bx+col*SQ, by+row*SQ, piece, SQ, white)
draw_piece(d, bx+sel_col*SQ, by+sel_row*SQ, 'Q', SQ, True)

# ── Overlays ─────────────────────────────────────────────────────────────
# Legal-move dots on empty squares (3-layer glow)
for (tc, tr) in legal_targets:
    cx_ = bx + tc*SQ + SQ//2; cy_ = by + tr*SQ + SQ//2
    dr = SQ * 28 // 100
    d.ellipse([cx_-dr-3, cy_-dr-3, cx_+dr+3, cy_+dr+3], fill=(10, 76, 10))
    d.ellipse([cx_-dr, cy_-dr, cx_+dr, cy_+dr], fill=(0, 204, 68))
    d.ellipse([cx_-dr//2, cy_-dr//2, cx_+dr//2, cy_+dr//2], fill=(136, 255, 153))

# Corner brackets
def corner_brackets(draw, bx_, by_, s, color, thick=2, arm=None):
    arm = arm or max(4, s//4)
    draw.rectangle([bx_,         by_,          bx_+arm,     by_+thick-1], fill=color)
    draw.rectangle([bx_,         by_,          bx_+thick-1, by_+arm],     fill=color)
    draw.rectangle([bx_+s-arm,   by_,          bx_+s,       by_+thick-1], fill=color)
    draw.rectangle([bx_+s-thick, by_,          bx_+s,       by_+arm],     fill=color)
    draw.rectangle([bx_,         by_+s-thick,  bx_+arm,     by_+s],       fill=color)
    draw.rectangle([bx_,         by_+s-arm,    bx_+thick-1, by_+s],       fill=color)
    draw.rectangle([bx_+s-arm,   by_+s-thick,  bx_+s,       by_+s],       fill=color)
    draw.rectangle([bx_+s-thick, by_+s-arm,    bx_+s,       by_+s],       fill=color)

# Capture target brackets
tc, tr = capture_target
corner_brackets(d, bx+tc*SQ, by+tr*SQ, SQ, (0, 204, 51), thick=3*SS, arm=14*SS)
# Selected piece brackets (gold, thicker)
corner_brackets(d, bx+sel_col*SQ, by+sel_row*SQ, SQ, (255, 136, 0), thick=4*SS, arm=18*SS)
# Cursor brackets (cyan)
corner_brackets(d, bx+cur_col*SQ, by+cur_row*SQ, SQ, (0, 204, 255), thick=3*SS, arm=14*SS)

# ── Captured pieces on either side ────────────────────────────────────────
cap_s = 40 * SS
cap_w_pieces = [('N', True), ('B', True), ('P', True)]
for i, (p, w) in enumerate(cap_w_pieces):
    draw_piece(d, bx - 56*SS, by + i * (cap_s + 8*SS) + 14*SS, p, cap_s, w)

cap_b_pieces = [('P', False), ('P', False), ('R', False)]
for i, (p, w) in enumerate(cap_b_pieces):
    draw_piece(d, bx + BW + 16*SS, by + i * (cap_s + 8*SS) + 14*SS, p, cap_s, w)

# ── Feature badge column ──────────────────────────────────────────────────
badge_x = bx + BW + 80*SS
badge_y = by + 70*SS
badges = [
    "BEAUTIFUL PIECES",
    "3 AI LEVELS",
    "3 GAME MODES",
    "SIDE SELECTION",
    "CHECK DETECTION",
    "PROMOTION",
]
bf = get_font(20 * SS)
for i, txt in enumerate(badges):
    by_ = badge_y + i * 38 * SS
    bw_ = 220 * SS; bh_ = 28 * SS
    bx_ = badge_x
    # shadow
    d.rounded_rectangle([bx_+2*SS, by_+2*SS, bx_+bw_+2*SS, by_+bh_+2*SS], radius=5*SS, fill=(0,0,0))
    # body
    d.rounded_rectangle([bx_, by_, bx_+bw_, by_+bh_], radius=5*SS, fill=(40, 24, 8))
    d.rounded_rectangle([bx_, by_, bx_+bw_, by_+bh_], radius=5*SS, outline=(180, 124, 56), width=SS)
    # gold bullet
    d.ellipse([bx_+10*SS, by_+bh_//2-5*SS, bx_+20*SS, by_+bh_//2+5*SS], fill=(255, 208, 40))
    d.ellipse([bx_+11*SS, by_+bh_//2-5*SS, bx_+15*SS, by_+bh_//2-1*SS], fill=(255, 234, 136))
    d.text((bx_+30*SS, by_+bh_//2), txt, font=bf, fill=(228, 200, 148), anchor="lm")

# ── Title ──────────────────────────────────────────────────────────────
title_y = by + BW + 30*SS
tf  = get_serif(86 * SS)
sf  = get_font(24 * SS)

title = "BITOCHI CHESS"
# multi-layer drop shadow
for off in range(8, 0, -2):
    d.text((W//2 + off*SS//2, title_y + off*SS//2), title, font=tf, fill=(0, 0, 0), anchor="mt")
# gradient gold via three text layers
d.text((W//2-1, title_y-1), title, font=tf, fill=(255, 240, 130), anchor="mt")
d.text((W//2,   title_y),   title, font=tf, fill=(255, 210, 70), anchor="mt")
d.text((W//2+1, title_y+1), title, font=tf, fill=(180, 130, 30), anchor="mt")

# Decorative gold separator (with diamond/swords)
line_y = title_y - 14*SS
lw = 280 * SS
d.line([(W//2-lw, line_y), (W//2+lw, line_y)], fill=(120, 80, 30), width=2*SS)
ds = 7*SS
d.polygon([(W//2, line_y-ds), (W//2+ds, line_y), (W//2, line_y+ds), (W//2-ds, line_y)], fill=(255, 208, 40))
d.polygon([(W//2-lw, line_y-ds//2), (W//2-lw+ds, line_y), (W//2-lw, line_y+ds//2)], fill=(180, 124, 56))
d.polygon([(W//2+lw, line_y-ds//2), (W//2+lw-ds, line_y), (W//2+lw, line_y+ds//2)], fill=(180, 124, 56))

sub = "Garmin Watch Chess  ·  3 AI Levels  ·  P vs AI / P vs P / AI vs AI  ·  Side Choice"
d.text((W//2, title_y + 96*SS), sub, font=sf, fill=(165, 138, 100), anchor="mt")

# Notes near showcased squares
note_f = get_font(15 * SS)

def note_label(x, y, text, bg, fg, padx=6, pady=3):
    bbox = d.textbbox((0,0), text, font=note_f)
    tw = bbox[2]-bbox[0]; th = bbox[3]-bbox[1]
    d.rounded_rectangle([x-tw//2-padx*SS, y-th//2-pady*SS, x+tw//2+padx*SS, y+th//2+pady*SS],
                        radius=3*SS, fill=bg)
    d.text((x, y), text, font=note_f, fill=fg, anchor="mm")

sx_ = bx + sel_col*SQ + SQ//2; sy_ = by + sel_row*SQ - 18*SS
note_label(sx_, sy_, "SELECTED", (60, 36, 0), (255, 196, 0))

cx__ = bx + cur_col*SQ + SQ//2; cy__ = by + cur_row*SQ + SQ + 18*SS
note_label(cx__, cy__, "CURSOR", (0, 24, 48), (0, 204, 255))

kx_ = bx + check_col*SQ + SQ//2; ky_ = by - 18*SS
note_label(kx_, ky_, "CHECK!", (120, 0, 0), (255, 80, 80))

# ── Vignette ──────────────────────────────────────────────────────────────
vig = Image.new("RGBA", (W, H), (0,0,0,0))
vd  = ImageDraw.Draw(vig)
for i in range(140):
    a = int(2.0 * i)
    vd.rectangle([i, i, W-i, H-i], outline=(0,0,0,a))
img_rgba = img.convert("RGBA")
img_rgba.alpha_composite(vig)
img_full = img_rgba.convert("RGB")

# ── Downsample to final resolution with LANCZOS (smooth piece edges) ──
img_out = img_full.resize((W_OUT, H_OUT), Image.LANCZOS)

# Light final sharpen for crispness
img_out = img_out.filter(ImageFilter.UnsharpMask(radius=1.0, percent=60, threshold=2))

save(img_out, os.path.join(BASE, "chess_hero.png"))
print("Done!")
