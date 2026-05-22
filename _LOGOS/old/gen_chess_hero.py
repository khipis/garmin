#!/usr/bin/env python3
"""Royal chess_hero.png — premium 2x supersampled render."""
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
        try:
            return ImageFont.truetype(path, size)
        except Exception:
            pass
    return ImageFont.load_default()


def get_serif(size):
    for path in [
        "/System/Library/Fonts/Supplemental/Trajan Pro Regular.ttf",
        "/System/Library/Fonts/Supplemental/Times New Roman Bold.ttf",
        "/System/Library/Fonts/Supplemental/Times New Roman.ttf",
        "/System/Library/Fonts/Times.ttc",
        "/System/Library/Fonts/Supplemental/Georgia.ttf",
        "/System/Library/Fonts/Supplemental/Baskerville.ttc",
    ]:
        try:
            return ImageFont.truetype(path, size)
        except Exception:
            pass
    return get_font(size)


def get_italic(size):
    for path in [
        "/System/Library/Fonts/Supplemental/Times New Roman Italic.ttf",
        "/System/Library/Fonts/Supplemental/Georgia Italic.ttf",
    ]:
        try:
            return ImageFont.truetype(path, size)
        except Exception:
            pass
    return get_serif(size)


def save(img, path):
    os.makedirs(os.path.dirname(path) if os.path.dirname(path) else ".", exist_ok=True)
    img.save(path, "PNG", optimize=True)
    kb = os.path.getsize(path) // 1024
    print(f"  saved {path}  {img.size}  ({kb} KB)")


# ── Final size + 2x supersample for smooth edges ────────────────────────
W_OUT, H_OUT = 1440, 720
SS = 2
W, H = W_OUT * SS, H_OUT * SS

img = Image.new("RGB", (W, H))
d = ImageDraw.Draw(img)

# ── Deep burgundy/mahogany gradient backdrop ────────────────────────────
for y in range(H):
    t = y / H
    r = int(36 + (1 - t) * 18 + math.sin(y * 0.012) * 3)
    g = int(8 + (1 - t) * 4)
    b = int(10 + (1 - t) * 4)
    d.line([(0, y), (W, y)], fill=(max(r, 6), max(g, 2), max(b, 2)))

# Faint canvas / linen noise
for _ in range(12000):
    sx = random.randint(0, W - 1)
    sy = random.randint(0, H - 1)
    v = random.randint(0, 14)
    d.point((sx, sy), fill=(v + 8, v // 2 + 2, v // 2 + 2))

# ── Subtle damask diamond pattern in faded gold ─────────────────────────
damask = Image.new("RGB", (W, H), (0, 0, 0))
ddam = ImageDraw.Draw(damask)
diamond = 60 * SS
for y in range(0, H, diamond):
    for x in range(-diamond, W + diamond, diamond):
        cx_ = x + ((y // diamond) % 2) * diamond // 2
        cy_ = y
        # tiny fleur-de-lis stylised as 3 ellipses + pole
        ddam.ellipse([cx_ - 4 * SS, cy_ - 2 * SS, cx_ + 4 * SS, cy_ + 2 * SS], fill=(40, 28, 8))
        ddam.ellipse([cx_ - 2 * SS, cy_ - 6 * SS, cx_ + 2 * SS, cy_ + 4 * SS], fill=(40, 28, 8))
        ddam.line([(cx_, cy_ - 6 * SS), (cx_, cy_ + 6 * SS)], fill=(40, 28, 8), width=SS)
damask = damask.filter(ImageFilter.GaussianBlur(2 * SS))
img = Image.blend(img.convert("RGB"), damask, 0.18)
d = ImageDraw.Draw(img)

# ── Soft golden spotlight halo behind board centre ──────────────────────
glow = Image.new("RGB", (W, H), (0, 0, 0))
gd = ImageDraw.Draw(glow)
for gr in range(900 * SS // 2, 0, -10):
    a = int(60 * gr / (900 * SS // 2))
    if a < 1:
        continue
    gd.ellipse([W // 2 - gr, H // 2 - gr * 5 // 6, W // 2 + gr, H // 2 + gr * 5 // 6],
               fill=(min(72, a), min(54, a * 3 // 4), min(20, a // 4)))
glow_blur = glow.filter(ImageFilter.GaussianBlur(28 * SS))
img = Image.blend(img.convert("RGB"), glow_blur, 0.4)
d = ImageDraw.Draw(img)


# ── Outer canvas border (thin gold inlay frame) ─────────────────────────
def outer_frame(d, W, H, SS):
    pad = 18 * SS
    d.rectangle([pad, pad, W - pad, H - pad], outline=(140, 92, 36), width=SS)
    d.rectangle([pad + 4 * SS, pad + 4 * SS, W - pad - 4 * SS, H - pad - 4 * SS],
                outline=(220, 160, 60), width=SS)
    d.rectangle([pad + 8 * SS, pad + 8 * SS, W - pad - 8 * SS, H - pad - 8 * SS],
                outline=(80, 50, 18), width=SS)


outer_frame(d, W, H, SS)


# ── Decorative corner flourishes ────────────────────────────────────────
def corner_flourish(d, x, y, ssize, color, mirror_x=False, mirror_y=False):
    sx = -1 if mirror_x else 1
    sy = -1 if mirror_y else 1
    pts = [
        (x + sx * 0, y + sy * 0),
        (x + sx * 60 * ssize, y + sy * 0),
        (x + sx * 50 * ssize, y + sy * 4 * ssize),
        (x + sx * 12 * ssize, y + sy * 4 * ssize),
        (x + sx * 4 * ssize, y + sy * 12 * ssize),
        (x + sx * 4 * ssize, y + sy * 50 * ssize),
        (x + sx * 0, y + sy * 60 * ssize),
    ]
    for i in range(len(pts) - 1):
        d.line([pts[i], pts[i + 1]], fill=color, width=ssize)
    # decorative scrolls (small spirals)
    cxa = x + sx * 14 * ssize
    cya = y + sy * 14 * ssize
    d.arc([cxa - 8 * ssize, cya - 8 * ssize, cxa + 8 * ssize, cya + 8 * ssize],
          0 if not mirror_x and not mirror_y else 90, 270, fill=color, width=ssize)
    # gold dot at vertex
    d.ellipse([cxa - 2 * ssize, cya - 2 * ssize, cxa + 2 * ssize, cya + 2 * ssize], fill=color)


pad = 28 * SS
corner_flourish(d, pad, pad, SS, (210, 160, 60))
corner_flourish(d, W - pad, pad, SS, (210, 160, 60), mirror_x=True)
corner_flourish(d, pad, H - pad, SS, (210, 160, 60), mirror_y=True)
corner_flourish(d, W - pad, H - pad, SS, (210, 160, 60), mirror_x=True, mirror_y=True)


# ── Crown emblem at top-centre ──────────────────────────────────────────
def draw_crown(d, cx, cy, w, gold, gold_hi, ruby, ruby_hi, sapphire, ssize):
    """Stylised three-point royal crown."""
    base_h = w * 22 // 100
    band_top = cy + w // 4
    band_bot = band_top + base_h
    # band shadow
    d.rectangle([cx - w // 2 - 2 * ssize, band_top + 2 * ssize,
                 cx + w // 2 + 2 * ssize, band_bot + 2 * ssize], fill=(20, 6, 4))
    # band silhouette
    d.rectangle([cx - w // 2 - ssize, band_top - ssize,
                 cx + w // 2 + ssize, band_bot + ssize], fill=(80, 40, 12))
    # band gold body
    d.rectangle([cx - w // 2, band_top, cx + w // 2, band_bot], fill=gold)
    # band highlight
    d.line([(cx - w // 2 + 2 * ssize, band_top + 2 * ssize),
            (cx + w // 2 - 3 * ssize, band_top + 2 * ssize)], fill=gold_hi, width=ssize)
    # band lower shadow
    d.line([(cx - w // 2 + 2 * ssize, band_bot - 2 * ssize),
            (cx + w // 2 - 3 * ssize, band_bot - 2 * ssize)], fill=(140, 88, 24), width=ssize)

    # decorative band gems
    for i, gem in enumerate([sapphire, ruby, sapphire]):
        gx = cx + (i - 1) * w * 26 // 100
        gy = band_top + base_h // 2
        d.ellipse([gx - 5 * ssize - ssize, gy - 5 * ssize - ssize,
                   gx + 5 * ssize + ssize, gy + 5 * ssize + ssize], fill=(40, 16, 4))
        d.ellipse([gx - 5 * ssize, gy - 5 * ssize, gx + 5 * ssize, gy + 5 * ssize], fill=gem)
        d.ellipse([gx - 2 * ssize, gy - 3 * ssize, gx, gy - 1 * ssize], fill=(255, 255, 255))

    # 5 spikes (3 large, 2 smaller between)
    spike_w = w * 16 // 100
    spike_h = w * 38 // 100
    spike_xs = [cx - w * 36 // 100, cx, cx + w * 36 // 100]
    for sx_ in spike_xs:
        # silhouette
        pts_sil = [
            (sx_ - spike_w // 2 - ssize, band_top + ssize),
            (sx_ - spike_w // 2 - ssize, band_top - spike_h * 6 // 10),
            (sx_ - ssize, band_top - spike_h),
            (sx_ + ssize, band_top - spike_h),
            (sx_ + spike_w // 2 + ssize, band_top - spike_h * 6 // 10),
            (sx_ + spike_w // 2 + ssize, band_top + ssize),
        ]
        d.polygon(pts_sil, fill=(80, 40, 12))
        pts = [
            (sx_ - spike_w // 2, band_top),
            (sx_ - spike_w // 2, band_top - spike_h * 6 // 10),
            (sx_, band_top - spike_h),
            (sx_, band_top - spike_h),
            (sx_ + spike_w // 2, band_top - spike_h * 6 // 10),
            (sx_ + spike_w // 2, band_top),
        ]
        d.polygon(pts, fill=gold)
        # highlight on left edge of spike
        d.line([(sx_ - spike_w // 2 + ssize, band_top - 2 * ssize),
                (sx_ - ssize, band_top - spike_h + 2 * ssize)], fill=gold_hi, width=ssize)
        # ball atop spike
        bx_ = sx_
        by_ = band_top - spike_h - 4 * ssize
        d.ellipse([bx_ - 5 * ssize, by_ - 5 * ssize, bx_ + 5 * ssize, by_ + 5 * ssize],
                  fill=(80, 40, 12))
        d.ellipse([bx_ - 4 * ssize, by_ - 4 * ssize, bx_ + 4 * ssize, by_ + 4 * ssize],
                  fill=gold)
        d.ellipse([bx_ - 2 * ssize, by_ - 3 * ssize, bx_, by_ - 1 * ssize],
                  fill=gold_hi)

    # smaller spikes between
    small_xs = [cx - w * 18 // 100, cx + w * 18 // 100]
    for sx_ in small_xs:
        d.line([(sx_, band_top), (sx_, band_top - spike_h * 5 // 10)],
               fill=(80, 40, 12), width=4 * ssize)
        d.line([(sx_, band_top), (sx_, band_top - spike_h * 5 // 10)],
               fill=gold, width=2 * ssize)
        # cross or star ball at top
        bx_ = sx_
        by_ = band_top - spike_h * 5 // 10 - 3 * ssize
        d.ellipse([bx_ - 3 * ssize, by_ - 3 * ssize, bx_ + 3 * ssize, by_ + 3 * ssize],
                  fill=ruby)
        d.ellipse([bx_ - 1 * ssize, by_ - 2 * ssize, bx_ + 1 * ssize, by_], fill=ruby_hi)

    # cross atop centre
    crossx = cx
    crossy = band_top - spike_h - 8 * ssize
    crossh = w * 12 // 100
    d.rectangle([crossx - 2 * ssize, crossy - crossh - ssize,
                 crossx + 2 * ssize, crossy + ssize], fill=(80, 40, 12))
    d.rectangle([crossx - crossh // 2 - ssize, crossy - crossh * 6 // 10 - ssize,
                 crossx + crossh // 2 + ssize, crossy - crossh * 4 // 10 + ssize],
                fill=(80, 40, 12))
    d.rectangle([crossx - ssize, crossy - crossh, crossx + ssize, crossy], fill=gold)
    d.rectangle([crossx - crossh // 2, crossy - crossh * 6 // 10,
                 crossx + crossh // 2, crossy - crossh * 4 // 10], fill=gold)
    d.rectangle([crossx - ssize, crossy - crossh, crossx, crossy], fill=gold_hi)


crown_cx = W // 2
crown_cy = 40 * SS
draw_crown(d, crown_cx, crown_cy, 180 * SS, (255, 208, 40), (255, 234, 136),
           (228, 40, 70), (255, 112, 144), (60, 110, 220), SS)


# ── Board geometry ──────────────────────────────────────────────────────
SQ = 56 * SS
BW = SQ * 8
bx = W // 2 - BW // 2
by = 130 * SS

light_sq = (240, 213, 158)
dark_sq = (122, 80, 44)

# ── Multi-layer ornate gold-inlaid board frame ──────────────────────────
fp = SS
# outer dark shadow
d.rectangle([bx - 32 * fp, by - 32 * fp, bx + BW + 32 * fp, by + BW + 32 * fp], fill=(0, 0, 0))
# outer rich brown
d.rectangle([bx - 28 * fp, by - 28 * fp, bx + BW + 28 * fp, by + BW + 28 * fp], fill=(48, 22, 6))
# outer gold frame
d.rectangle([bx - 22 * fp, by - 22 * fp, bx + BW + 22 * fp, by + BW + 22 * fp], fill=(190, 134, 50))
d.rectangle([bx - 21 * fp, by - 21 * fp, bx + BW + 21 * fp, by + BW + 21 * fp], outline=(255, 222, 120), width=fp)
# wood band with grain
d.rectangle([bx - 16 * fp, by - 16 * fp, bx + BW + 16 * fp, by + BW + 16 * fp], fill=(86, 44, 12))
for _ in range(2200):
    rx = random.randint(bx - 16 * fp, bx + BW + 16 * fp)
    ry = random.randint(by - 16 * fp, by + BW + 16 * fp)
    if (bx - 8 * fp <= rx <= bx + BW + 8 * fp) and (by - 8 * fp <= ry <= by + BW + 8 * fp):
        continue
    v = random.randint(0, 22)
    img.putpixel((rx, ry), (110 + v, 60 + v // 2, 16))
d = ImageDraw.Draw(img)
# inner gold inlay
d.rectangle([bx - 10 * fp, by - 10 * fp, bx + BW + 10 * fp, by + BW + 10 * fp], fill=(220, 162, 60))
d.rectangle([bx - 9 * fp, by - 9 * fp, bx + BW + 9 * fp, by + BW + 9 * fp], outline=(255, 232, 132), width=fp)
d.rectangle([bx - 7 * fp, by - 7 * fp, bx + BW + 7 * fp, by + BW + 7 * fp], outline=(140, 86, 24), width=fp)
# inner dark wood
d.rectangle([bx - 6 * fp, by - 6 * fp, bx + BW + 6 * fp, by + BW + 6 * fp], fill=(58, 28, 8))
# innermost gold liner
d.rectangle([bx - 2 * fp, by - 2 * fp, bx + BW + 2 * fp, by + BW + 2 * fp], fill=(180, 122, 44))


# ── Frame corner ornaments (gold fleur-de-lis at each board corner) ─────
def fleur(d, cx, cy, w, gold, hi, dark):
    h = w * 5 // 4
    # central petal
    d.polygon([(cx, cy - h // 2), (cx - w // 2, cy + h // 8), (cx, cy + h // 4), (cx + w // 2, cy + h // 8)], fill=gold)
    # side curls
    d.ellipse([cx - w // 2 - 2 * SS, cy - h // 4, cx - w // 8, cy + h // 4], fill=gold)
    d.ellipse([cx + w // 8, cy - h // 4, cx + w // 2 + 2 * SS, cy + h // 4], fill=gold)
    # band
    d.rectangle([cx - w * 6 // 10, cy + h // 5, cx + w * 6 // 10, cy + h // 4 + SS], fill=dark)
    # central highlight
    d.line([(cx, cy - h // 2 + 2 * SS), (cx, cy + h // 4 - SS)], fill=hi, width=SS)


fleur_w = 22 * SS
fleur(d, bx - 16 * fp, by - 16 * fp, fleur_w, (255, 208, 40), (255, 234, 136), (80, 40, 8))
fleur(d, bx + BW + 16 * fp, by - 16 * fp, fleur_w, (255, 208, 40), (255, 234, 136), (80, 40, 8))
fleur(d, bx - 16 * fp, by + BW + 16 * fp, fleur_w, (255, 208, 40), (255, 234, 136), (80, 40, 8))
fleur(d, bx + BW + 16 * fp, by + BW + 16 * fp, fleur_w, (255, 208, 40), (255, 234, 136), (80, 40, 8))


# Squares with edge shading
for row in range(8):
    for col in range(8):
        is_light = (row + col) % 2 == 0
        base = light_sq if is_light else dark_sq
        x0 = bx + col * SQ
        y0 = by + row * SQ
        d.rectangle([x0, y0, x0 + SQ - 1, y0 + SQ - 1], fill=base)
        hi = tuple(min(c + 18, 255) for c in base)
        sh = tuple(max(c - 24, 0) for c in base)
        d.line([(x0, y0), (x0 + SQ - 2, y0)], fill=hi)
        d.line([(x0, y0), (x0, y0 + SQ - 2)], fill=hi)
        d.line([(x0 + 1, y0 + SQ - 1), (x0 + SQ - 1, y0 + SQ - 1)], fill=sh)
        d.line([(x0 + SQ - 1, y0 + 1), (x0 + SQ - 1, y0 + SQ - 1)], fill=sh)


# ── Piece renderer (mirrors Monkey C drawPiece) ──────────────────────────
def frr(draw, x, y, w, h, rad, color):
    if w <= 1 or h <= 1:
        return
    rad = min(rad, w // 2, h // 2, 18)
    draw.rounded_rectangle([x, y, x + w - 1, y + h - 1], radius=rad, fill=color)


def fc(draw, x, y, rad, color):
    if rad < 1:
        return
    draw.ellipse([x - rad, y - rad, x + rad, y + rad], fill=color)


def fpoly(draw, pts, color):
    draw.polygon([tuple(p) for p in pts], fill=color)


def line(draw, x1, y1, x2, y2, color, width=1):
    draw.line([(x1, y1), (x2, y2)], fill=color, width=width)


def fr(draw, x, y, w, h, color):
    if w <= 0 or h <= 0:
        return
    draw.rectangle([x, y, x + w - 1, y + h - 1], fill=color)


def cast_shadow(draw, bx_, by_, s):
    """Soft elliptical cast-shadow under the piece (light from upper-left)."""
    cx = bx_ + s // 2
    cy = by_ + s - s * 8 // 100
    rx = s * 32 // 100
    ry = s * 6 // 100
    # 3-step soft shadow (no alpha, blend by drawing darker rectangles)
    for k in range(3, 0, -1):
        col = (max(0, 30 - k * 8), max(0, 14 - k * 4), max(0, 6 - k * 2))
        draw.ellipse([cx - rx - k, cy - ry, cx + rx + k, cy + ry + k], fill=col)


def draw_piece(draw, bx_, by_, piece, s, white):
    cx = bx_ + s // 2
    bot = by_ + s - 2
    if white:
        sil_c = (32, 18, 6)
        rim_c = (174, 116, 48)
        body_c = (255, 244, 220)
        mid_c = (210, 166, 114)
        hl_c = (255, 255, 255)
        shd_c = (16, 8, 2)
        mark_c = (88, 56, 16)
    else:
        sil_c = (232, 184, 80)
        rim_c = (108, 68, 22)
        body_c = (10, 5, 0)
        mid_c = (44, 26, 10)
        hl_c = (164, 112, 40)
        shd_c = (0, 0, 0)
        mark_c = (224, 184, 96)
    gold_c = (255, 208, 40)
    gold_hi = (255, 234, 136)
    ruby_c = (232, 40, 74)
    ruby_hi = (255, 112, 144)

    def r(p):
        return max(1, s * p // 100)

    cast_shadow(draw, bx_, by_, s)
    frr(draw, cx - r(36), bot - 1, r(72), 3, 1, shd_c)

    if piece == 'P':
        hr = max(4, r(22))
        frr(draw, cx - r(36), bot - r(22), r(72), r(22), 4, sil_c)
        frr(draw, cx - r(34), bot - r(21), r(68), r(19), 3, rim_c)
        frr(draw, cx - r(32), bot - r(20), r(64), r(16), 2, body_c)
        frr(draw, cx - r(32), bot - r(8), r(64), r(4), 1, mid_c)
        line(draw, cx - r(30), bot - r(19), cx + r(30), bot - r(19), hl_c, 1)
        frr(draw, cx - r(22), bot - r(30), r(44), r(10), 3, sil_c)
        frr(draw, cx - r(20), bot - r(29), r(40), r(8), 2, rim_c)
        frr(draw, cx - r(13), bot - r(60), r(26), r(32), 3, sil_c)
        frr(draw, cx - r(12), bot - r(59), r(24), r(30), 2, rim_c)
        frr(draw, cx - r(10), bot - r(58), r(20), r(27), 1, body_c)
        fr(draw, cx + r(4), bot - r(38), r(6), r(6), mid_c)
        fr(draw, cx - r(8), bot - r(55), 2, r(22), hl_c)
        fc(draw, cx + 1, bot - r(66) + 1, hr, shd_c)
        fc(draw, cx, bot - r(66), hr, sil_c)
        fc(draw, cx, bot - r(66), hr - 1, rim_c)
        fc(draw, cx, bot - r(66), hr - 2, body_c)
        if hr > 4:
            fc(draw, cx + hr // 3, bot - r(66) + hr // 3, hr * 3 // 5, mid_c)
        if hr > 5:
            fc(draw, cx, bot - r(66), hr - 4, body_c)
        if hr > 4:
            fc(draw, cx - hr * 3 // 8, bot - r(66) - hr * 3 // 8, hr // 3, hl_c)
        if hr > 6:
            fc(draw, cx - hr * 5 // 8, bot - r(66) - hr * 5 // 8 + 1, 1, hl_c)

    elif piece == 'R':
        bw = max(9, r(54))
        mW = max(2, bw // 3)
        mH = max(3, r(16))
        frr(draw, cx - r(34), bot - r(22), r(68), r(22), 3, sil_c)
        frr(draw, cx - r(32), bot - r(21), r(64), r(19), 2, rim_c)
        frr(draw, cx - r(30), bot - r(20), r(60), r(16), 2, body_c)
        fr(draw, cx - r(30), bot - r(8), r(60), r(3), mid_c)
        frr(draw, cx - r(30), bot - r(30), r(60), r(9), 2, sil_c)
        frr(draw, cx - r(28), bot - r(29), r(56), r(7), 1, rim_c)
        frr(draw, cx - bw // 2, bot - r(82), bw, r(52), 2, sil_c)
        frr(draw, cx - bw // 2 + 1, bot - r(81), bw - 2, r(50), 1, rim_c)
        frr(draw, cx - bw // 2 + 2, bot - r(80), bw - 4, r(48), 1, body_c)
        fr(draw, cx + bw // 2 - 5, bot - r(78), 3, r(44), mid_c)
        sW2 = max(2, r(10))
        sH2 = max(3, r(22))
        frr(draw, cx - sW2 // 2 - 1, bot - r(65) - 1, sW2 + 2, sH2 + 2, 1, sil_c)
        frr(draw, cx - sW2 // 2, bot - r(65), sW2, sH2, 1, shd_c)
        line(draw, cx - sW2 // 2 + 1, bot - r(65) + 1, cx - sW2 // 2 + 1, bot - r(65) + sH2 - 2,
             (200, 164, 124) if white else (48, 24, 8), 1)
        line(draw, cx - bw // 2 + 2, bot - r(78), cx + bw // 2 - 4, bot - r(78), hl_c, 1)
        for ti in range(3):
            mx = (cx - bw // 2) if ti == 0 else ((cx - mW // 2) if ti == 1 else (cx + bw // 2 - mW))
            fr(draw, mx - 1, bot - r(82) - mH - 1, mW + 2, mH + 3, sil_c)
            fr(draw, mx, bot - r(82) - mH, mW, mH + 2, rim_c)
            fr(draw, mx + 1, bot - r(82) - mH, mW - 2, mH, body_c)
            line(draw, mx + 1, bot - r(82) - mH, mx + mW - 2, bot - r(82) - mH, hl_c, 1)

    elif piece == 'N':
        frr(draw, cx - r(30), bot - r(22), r(60), r(22), 3, sil_c)
        frr(draw, cx - r(28), bot - r(21), r(56), r(19), 2, rim_c)
        frr(draw, cx - r(26), bot - r(20), r(52), r(16), 2, body_c)
        fr(draw, cx - r(26), bot - r(8), r(52), r(3), mid_c)
        frr(draw, cx - r(22), bot - r(60), r(44), r(40), 4, sil_c)
        frr(draw, cx - r(21), bot - r(59), r(42), r(38), 3, rim_c)
        frr(draw, cx - r(19), bot - r(58), r(38), r(35), 2, body_c)
        pts = [
            (cx - r(16), bot - r(60)),
            (cx - r(18), bot - r(72)),
            (cx - r(12), bot - r(82)),
            (cx + r(4), bot - r(92)),
            (cx + r(10), bot - r(98)),
            (cx + r(16), bot - r(92)),
            (cx + r(22), bot - r(86)),
            (cx + r(28), bot - r(78)),
            (cx + r(30), bot - r(70)),
            (cx + r(28), bot - r(64)),
            (cx + r(20), bot - r(60)),
            (cx + r(8), bot - r(58)),
        ]
        pts_sil = [
            (pts[0][0] - 1, pts[0][1] + 1),
            (pts[1][0] - 1, pts[1][1]),
            (pts[2][0], pts[2][1] - 1),
            (pts[3][0], pts[3][1] - 1),
            (pts[4][0] + 1, pts[4][1] - 1),
            (pts[5][0] + 1, pts[5][1] - 1),
            (pts[6][0] + 1, pts[6][1] - 1),
            (pts[7][0] + 1, pts[7][1]),
            (pts[8][0] + 1, pts[8][1] + 1),
            (pts[9][0] + 1, pts[9][1] + 1),
            (pts[10][0] + 1, pts[10][1] + 1),
            (pts[11][0], pts[11][1] + 1),
        ]
        fpoly(draw, pts_sil, sil_c)
        fpoly(draw, pts, rim_c)
        pts_in = [
            (pts[0][0] + 1, pts[0][1] - 1),
            (pts[1][0] + 1, pts[1][1]),
            (pts[2][0] + 1, pts[2][1] + 1),
            (pts[3][0] + 1, pts[3][1] + 1),
            (pts[4][0], pts[4][1] + 2),
            (pts[5][0] - 1, pts[5][1] + 1),
            (pts[6][0] - 1, pts[6][1] + 1),
            (pts[7][0] - 1, pts[7][1]),
            (pts[8][0] - 1, pts[8][1] - 1),
            (pts[9][0] - 1, pts[9][1] - 1),
            (pts[10][0] - 1, pts[10][1] - 1),
            (pts[11][0], pts[11][1] - 1),
        ]
        fpoly(draw, pts_in, body_c)
        eyeX = cx + r(15)
        eyeY = bot - r(80)
        eyeR = max(2, r(7))
        fc(draw, eyeX, eyeY, eyeR + 1, sil_c)
        fc(draw, eyeX, eyeY, eyeR, rim_c)
        fc(draw, eyeX, eyeY, eyeR - 1 if eyeR > 2 else 1, body_c)
        fc(draw, eyeX - 1, eyeY - 1, 1, (255, 255, 255) if white else (255, 208, 136))
        fc(draw, cx + r(26), bot - r(68), 2, mark_c)
        line(draw, cx + r(22), bot - r(64), cx + r(28), bot - r(65), sil_c, 1)
        line(draw, cx - r(14), bot - r(64), cx - r(4), bot - r(82), hl_c, 1)
        line(draw, cx - r(8), bot - r(64), cx - r(0), bot - r(84), hl_c, 1)
        fr(draw, cx - r(17), bot - r(55), 2, r(30), hl_c)

    elif piece == 'B':
        bwB = max(8, r(46))
        bwU = bwB * 7 // 10
        frr(draw, cx - r(30), bot - r(22), r(60), r(22), 3, sil_c)
        frr(draw, cx - r(28), bot - r(21), r(56), r(19), 2, rim_c)
        frr(draw, cx - r(26), bot - r(20), r(52), r(16), 2, body_c)
        fr(draw, cx - r(26), bot - r(8), r(52), r(3), mid_c)
        frr(draw, cx - bwB // 2 - 1, bot - r(55), bwB + 2, r(36), 4, sil_c)
        frr(draw, cx - bwB // 2, bot - r(54), bwB, r(34), 3, rim_c)
        frr(draw, cx - bwB // 2 + 1, bot - r(53), bwB - 2, r(31), 2, body_c)
        fr(draw, cx + bwB // 2 - 4, bot - r(50), 2, r(28), mid_c)
        fr(draw, cx - bwB // 2 + 2, bot - r(50), 2, r(26), hl_c)
        frr(draw, cx - bwB // 2 - 1, bot - r(60), bwB + 2, r(9), 2, sil_c)
        frr(draw, cx - bwB // 2, bot - r(59), bwB, r(7), 1, gold_c)
        line(draw, cx - bwB // 2 + 1, bot - r(58), cx + bwB // 2 - 2, bot - r(58), gold_hi, 1)
        frr(draw, cx - bwU // 2 - 1, bot - r(72), bwU + 2, r(16), 3, sil_c)
        frr(draw, cx - bwU // 2, bot - r(71), bwU, r(14), 2, rim_c)
        frr(draw, cx - bwU // 2 + 1, bot - r(70), bwU - 2, r(12), 1, body_c)
        line(draw, cx - bwU // 2 + 2, bot - r(68), cx + bwU // 2 - 2, bot - r(64), sil_c, 1)
        line(draw, cx - bwU // 2 + 2, bot - r(67), cx + bwU // 2 - 2, bot - r(63), mid_c, 1)
        orR = max(3, r(12))
        fc(draw, cx + 1, bot - r(78) + 1, orR, shd_c)
        fc(draw, cx, bot - r(78), orR, sil_c)
        fc(draw, cx, bot - r(78), orR - 1, rim_c)
        fc(draw, cx, bot - r(78), orR - 2, body_c)
        if orR > 3:
            fc(draw, cx + orR // 3, bot - r(78) + orR // 3, orR * 3 // 5, mid_c)
        if orR > 4:
            fc(draw, cx, bot - r(78), orR - 4, body_c)
        if orR > 3:
            fc(draw, cx - orR * 3 // 8, bot - r(78) - orR * 3 // 8, orR // 3, hl_c)
        if orR > 5:
            fc(draw, cx - orR * 5 // 8, bot - r(78) - orR * 5 // 8, 1, hl_c)
        mBase = bot - r(84)
        mW2 = max(3, r(11))
        mH2 = max(5, r(22))
        mPts = [
            (cx - mW2 // 2 - 1, mBase + 2),
            (cx - mW2 // 2, mBase - mH2 * 2 // 3),
            (cx - 1, mBase - mH2),
            (cx + 1, mBase - mH2),
            (cx + mW2 // 2, mBase - mH2 * 2 // 3),
            (cx + mW2 // 2 + 1, mBase + 2),
        ]
        mPtsIn = [
            (cx - mW2 // 2 + 1, mBase + 1),
            (cx - mW2 // 2 + 1, mBase - mH2 * 2 // 3),
            (cx - 1, mBase - mH2 + 1),
            (cx + 1, mBase - mH2 + 1),
            (cx + mW2 // 2 - 1, mBase - mH2 * 2 // 3),
            (cx + mW2 // 2 - 1, mBase + 1),
        ]
        fpoly(draw, mPts, sil_c)
        fpoly(draw, mPtsIn, rim_c)
        frr(draw, cx - mW2 // 2 + 2, mBase - mH2 * 2 // 3, mW2 - 4, mH2 * 2 // 3 + 1, 1, body_c)
        line(draw, cx - mW2 // 2 + 2, mBase - mH2 * 2 // 3 + 1, cx - mW2 // 2 + 2, mBase, hl_c, 1)
        crossT = mBase - mH2 - (7 if s > 22 * SS else 5)
        fr(draw, cx - 2, crossT, 5, mH2 // 2 + 2, sil_c)
        fr(draw, cx - 4, crossT + 2, 9, 4, sil_c)
        fr(draw, cx - 1, crossT + 1, 3, mH2 // 2, gold_c)
        fr(draw, cx - 3, crossT + 3, 7, 2, gold_c)
        fr(draw, cx - 1, crossT + 1, 1, mH2 // 2, gold_hi)

    elif piece == 'Q':
        bwQ = max(11, r(60))
        pr2 = max(3, r(12))
        frr(draw, cx - r(36), bot - r(22), r(72), r(22), 3, sil_c)
        frr(draw, cx - r(34), bot - r(21), r(68), r(19), 2, rim_c)
        frr(draw, cx - r(32), bot - r(20), r(64), r(16), 2, body_c)
        fr(draw, cx - r(32), bot - r(8), r(64), r(3), mid_c)
        line(draw, cx - r(30), bot - r(19), cx + r(30), bot - r(19), hl_c, 1)
        frr(draw, cx - bwQ // 2 - 1, bot - r(52), bwQ + 2, r(32), 5, sil_c)
        frr(draw, cx - bwQ // 2, bot - r(51), bwQ, r(30), 4, rim_c)
        frr(draw, cx - bwQ // 2 + 1, bot - r(50), bwQ - 2, r(27), 3, body_c)
        fr(draw, cx + bwQ // 2 - 4, bot - r(48), 2, r(24), mid_c)
        bwW = bwQ * 65 // 100
        frr(draw, cx - bwW // 2 - 1, bot - r(60), bwW + 2, r(12), 3, sil_c)
        frr(draw, cx - bwW // 2, bot - r(59), bwW, r(10), 2, rim_c)
        frr(draw, cx - bwW // 2 + 1, bot - r(58), bwW - 2, r(8), 1, body_c)
        bwT = bwQ * 80 // 100
        frr(draw, cx - bwT // 2 - 1, bot - r(78), bwT + 2, r(22), 4, sil_c)
        frr(draw, cx - bwT // 2, bot - r(77), bwT, r(20), 3, rim_c)
        frr(draw, cx - bwT // 2 + 1, bot - r(76), bwT - 2, r(17), 2, body_c)
        fr(draw, cx - bwT // 2 + 2, bot - r(74), 2, r(14), hl_c)
        crownBase = bot - r(78)
        frr(draw, cx - bwQ // 2 - 1, crownBase - r(8), bwQ + 2, r(9), 2, sil_c)
        frr(draw, cx - bwQ // 2, crownBase - r(7), bwQ, r(7), 1, gold_c)
        line(draw, cx - bwQ // 2 + 1, crownBase - r(6), cx + bwQ // 2 - 2, crownBase - r(6), gold_hi, 1)
        crownY2 = crownBase - r(8) - pr2
        pearlStep = bwQ * 22 // 100
        for pi in range(5):
            px2 = cx + (pi - 2) * pearlStep
            fr(draw, px2 - 1, crownY2 + 1, 2, r(7), gold_c)
            fc(draw, px2 + 1, crownY2 + 1, pr2, shd_c)
            fc(draw, px2, crownY2, pr2, sil_c)
            fc(draw, px2, crownY2, pr2 - 1, gold_c if pi == 2 else rim_c)
            fc(draw, px2, crownY2, pr2 - 2 if pr2 > 2 else 1, ruby_c if pi == 2 else body_c)
            if pr2 > 3:
                fc(draw, px2 - 1, crownY2 - pr2 // 2, 2 if pr2 > 4 else 1, ruby_hi if pi == 2 else hl_c)
            if pr2 > 5 and pi == 2:
                fc(draw, px2 - pr2 // 3, crownY2 - pr2 // 2, 1, (255, 255, 255))
        frr(draw, cx - bwT // 2 + 1, bot - r(60), bwT - 2, r(3), 1, gold_c)

    elif piece == 'K':
        bwK = max(11, r(60))
        mWK = max(3, bwK * 28 // 100)
        mHK = max(3, r(13))
        frr(draw, cx - r(36), bot - r(22), r(72), r(22), 3, sil_c)
        frr(draw, cx - r(34), bot - r(21), r(68), r(19), 2, rim_c)
        frr(draw, cx - r(32), bot - r(20), r(64), r(16), 2, body_c)
        fr(draw, cx - r(32), bot - r(8), r(64), r(3), mid_c)
        line(draw, cx - r(30), bot - r(19), cx + r(30), bot - r(19), hl_c, 1)
        frr(draw, cx - bwK // 2 - 1, bot - r(52), bwK + 2, r(32), 5, sil_c)
        frr(draw, cx - bwK // 2, bot - r(51), bwK, r(30), 4, rim_c)
        frr(draw, cx - bwK // 2 + 1, bot - r(50), bwK - 2, r(27), 3, body_c)
        fr(draw, cx + bwK // 2 - 4, bot - r(48), 2, r(24), mid_c)
        bwKW = bwK * 65 // 100
        frr(draw, cx - bwKW // 2 - 1, bot - r(60), bwKW + 2, r(12), 3, sil_c)
        frr(draw, cx - bwKW // 2, bot - r(59), bwKW, r(10), 2, rim_c)
        frr(draw, cx - bwKW // 2 + 1, bot - r(58), bwKW - 2, r(8), 1, body_c)
        bwKT = bwK * 80 // 100
        frr(draw, cx - bwKT // 2 - 1, bot - r(82), bwKT + 2, r(26), 4, sil_c)
        frr(draw, cx - bwKT // 2, bot - r(81), bwKT, r(24), 3, rim_c)
        frr(draw, cx - bwKT // 2 + 1, bot - r(80), bwKT - 2, r(21), 2, body_c)
        fr(draw, cx - bwKT // 2 + 2, bot - r(78), 2, r(16), hl_c)
        cBase2 = bot - r(82)
        frr(draw, cx - bwK // 2 - 1, cBase2 - r(7), bwK + 2, r(8), 2, sil_c)
        frr(draw, cx - bwK // 2, cBase2 - r(6), bwK, r(6), 1, gold_c)
        line(draw, cx - bwK // 2 + 1, cBase2 - r(5), cx + bwK // 2 - 2, cBase2 - r(5), gold_hi, 1)
        for ki in range(3):
            kmx = (cx - bwK // 2) if ki == 0 else ((cx - mWK // 2) if ki == 1 else (cx + bwK // 2 - mWK))
            fr(draw, kmx - 1, cBase2 - r(7) - mHK - 1, mWK + 2, mHK + 3, sil_c)
            fr(draw, kmx, cBase2 - r(7) - mHK, mWK, mHK + 2, rim_c)
            fr(draw, kmx + 1, cBase2 - r(7) - mHK, mWK - 2, mHK, body_c)
            line(draw, kmx + 1, cBase2 - r(7) - mHK, kmx + mWK - 2, cBase2 - r(7) - mHK, hl_c, 1)
            if ki == 1 and mWK > 3:
                fc(draw, cx, cBase2 - r(7) - mHK // 2, mWK // 3 + 1, ruby_c)
                if mWK > 5:
                    fc(draw, cx - 1, cBase2 - r(7) - mHK // 2 - 1, 1, ruby_hi)
        crossH3 = max(5, r(30))
        armW3 = max(4, r(16))
        crossY3 = cBase2 - r(7) - mHK - crossH3
        fr(draw, cx - 3, crossY3 - 1, 6, crossH3 + 2, sil_c)
        fr(draw, cx - armW3 // 2 - 1, crossY3 + crossH3 * 4 // 10 - 1, armW3 + 2, 5, sil_c)
        fr(draw, cx - 2, crossY3, 4, crossH3, gold_c)
        fr(draw, cx - armW3 // 2, crossY3 + crossH3 * 4 // 10, armW3, 3, gold_c)
        fr(draw, cx - 2, crossY3, 1, crossH3, gold_hi)
        fr(draw, cx - armW3 // 2, crossY3 + crossH3 * 4 // 10, armW3 - 1, 1, gold_hi)
        fr(draw, cx - 2, crossY3, 2, 2, (255, 255, 255))


# ── Beautiful starting / classical mid-game position ────────────────────
# Symmetric, museum-set arrangement (no UI overlays whatsoever).
board_pos = [
    # Black back rank (full)
    (0, 0, 'R', False), (1, 0, 'N', False), (2, 0, 'B', False), (3, 0, 'Q', False),
    (4, 0, 'K', False), (5, 0, 'B', False), (6, 0, 'N', False), (7, 0, 'R', False),
    # Black pawns (advanced d & e)
    (0, 1, 'P', False), (1, 1, 'P', False), (2, 1, 'P', False),
    (3, 3, 'P', False), (4, 3, 'P', False),
    (5, 1, 'P', False), (6, 1, 'P', False), (7, 1, 'P', False),
    # White pawns (advanced d & e)
    (0, 6, 'P', True), (1, 6, 'P', True), (2, 6, 'P', True),
    (3, 4, 'P', True), (4, 4, 'P', True),
    (5, 6, 'P', True), (6, 6, 'P', True), (7, 6, 'P', True),
    # White back rank
    (0, 7, 'R', True), (1, 7, 'N', True), (2, 7, 'B', True), (3, 7, 'Q', True),
    (4, 7, 'K', True), (5, 7, 'B', True), (6, 7, 'N', True), (7, 7, 'R', True),
]

for (col, row, piece, white) in board_pos:
    draw_piece(d, bx + col * SQ, by + row * SQ, piece, SQ, white)


# ── Title at bottom — gold serif with laurel branches ───────────────────
def laurel(d, cx, cy, length, gold, hi, dark, mirror=False):
    """Draws a stylised laurel branch."""
    sx = -1 if mirror else 1
    # central stem
    d.line([(cx, cy), (cx + sx * length, cy)], fill=gold, width=2 * SS)
    # leaves
    n = 8
    for i in range(1, n + 1):
        t = i / n
        lx = cx + sx * int(length * t)
        # alternating up / down leaves
        side = 1 if i % 2 == 0 else -1
        leaf_w = int(8 * SS + (1 - t) * 6 * SS)
        leaf_h = int(14 * SS + (1 - t) * 4 * SS)
        # leaf
        leaf_pts = [
            (lx, cy),
            (lx + sx * leaf_w // 2, cy + side * leaf_h // 2),
            (lx + sx * leaf_w, cy + side * leaf_h * 9 // 10),
            (lx + sx * leaf_w * 5 // 4, cy + side * leaf_h),
            (lx + sx * leaf_w, cy + side * leaf_h * 8 // 10),
            (lx + sx * leaf_w // 3, cy + side * leaf_h // 4),
        ]
        d.polygon(leaf_pts, fill=gold)
        d.polygon(leaf_pts, outline=dark)
        # subtle highlight on leaf
        d.line([(lx + sx * 2, cy + side * 2),
                (lx + sx * leaf_w * 4 // 5, cy + side * leaf_h * 6 // 10)],
               fill=hi, width=SS)


title_y = by + BW + 30 * SS
serif_size = 72 * SS
tf = get_serif(serif_size)
sf = get_italic(20 * SS)

title = "BITOCHI CHESS"

# Multi-layer drop shadow (for depth)
for off in range(10, 0, -2):
    d.text((W // 2 + off * SS // 2, title_y + off * SS // 2), title, font=tf,
           fill=(0, 0, 0), anchor="mt")

# Outer dark gold edge
d.text((W // 2 - 2, title_y - 2), title, font=tf, fill=(80, 50, 18), anchor="mt")
d.text((W // 2 + 2, title_y + 2), title, font=tf, fill=(80, 50, 18), anchor="mt")
d.text((W // 2 - 2, title_y + 2), title, font=tf, fill=(80, 50, 18), anchor="mt")
d.text((W // 2 + 2, title_y - 2), title, font=tf, fill=(80, 50, 18), anchor="mt")

# Main gold layers (top→bottom gradient via 3 stacked tints)
d.text((W // 2, title_y - 1), title, font=tf, fill=(255, 232, 110), anchor="mt")
d.text((W // 2, title_y + 1), title, font=tf, fill=(220, 158, 40), anchor="mt")
d.text((W // 2, title_y), title, font=tf, fill=(255, 200, 60), anchor="mt")

# Laurel branches on either side of title
title_bbox = d.textbbox((W // 2, title_y), title, font=tf, anchor="mt")
title_w = title_bbox[2] - title_bbox[0]
laurel_y = title_y + serif_size // 2 + 4 * SS
laurel_len = 110 * SS
laurel(d, W // 2 - title_w // 2 - 30 * SS, laurel_y, laurel_len,
       (210, 160, 60), (255, 234, 136), (90, 56, 18), mirror=True)
laurel(d, W // 2 + title_w // 2 + 30 * SS, laurel_y, laurel_len,
       (210, 160, 60), (255, 234, 136), (90, 56, 18), mirror=False)

# Italic subtitle
sub = "Royal Strategy on Your Wrist"
sub_y = title_y + serif_size * 7 // 10 + 8 * SS
d.text((W // 2 + 1, sub_y + 1), sub, font=sf, fill=(0, 0, 0), anchor="mt")
d.text((W // 2, sub_y), sub, font=sf, fill=(200, 168, 110), anchor="mt")


# ── Final vignette ──────────────────────────────────────────────────────
vig = Image.new("RGBA", (W, H), (0, 0, 0, 0))
vd = ImageDraw.Draw(vig)
for i in range(140):
    a = int(2.0 * i)
    vd.rectangle([i, i, W - i, H - i], outline=(0, 0, 0, a))
img_rgba = img.convert("RGBA")
img_rgba.alpha_composite(vig)
img_full = img_rgba.convert("RGB")

# Downsample with LANCZOS for smooth edges
img_out = img_full.resize((W_OUT, H_OUT), Image.LANCZOS)
img_out = img_out.filter(ImageFilter.UnsharpMask(radius=1.0, percent=55, threshold=2))

save(img_out, os.path.join(BASE, "chess_hero.png"))
print("Done!")






