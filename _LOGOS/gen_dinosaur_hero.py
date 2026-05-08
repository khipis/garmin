#!/usr/bin/env python3
"""Generate dinosaur_hero.png (1440×720) for Dino Run."""

from PIL import Image, ImageDraw, ImageFont
import os, math

W, H = 1440, 720
OUT  = os.path.join(os.path.dirname(__file__), "dinosaur_hero.png")

img = Image.new("RGB", (W, H), (10, 10, 10))
d   = ImageDraw.Draw(img)

# ── helpers ───────────────────────────────────────────────────────────────────
def load_font(size, bold=False):
    candidates = [
        f"/System/Library/Fonts/Supplemental/Courier New{'Bold' if bold else ''}.ttf",
        "/System/Library/Fonts/Supplemental/Courier New.ttf",
        "/System/Library/Fonts/Monaco.ttf",
        "/System/Library/Fonts/Menlo.ttc",
    ]
    for p in candidates:
        try: return ImageFont.truetype(p, size)
        except Exception: pass
    return ImageFont.load_default()

def text_w(draw, txt, font):
    bb = draw.textbbox((0, 0), txt, font=font)
    return bb[2] - bb[0]

def centered(draw, txt, cx, y, font, color):
    tw = text_w(draw, txt, font)
    draw.text((cx - tw // 2, y), txt, font=font, fill=color)

def pill(draw, x, y, w, h, r, fill, outline=None):
    draw.rounded_rectangle([x, y, x + w, y + h], radius=r, fill=fill,
                            outline=outline, width=2 if outline else 0)

GREEN      = (46, 170, 68)
DGREEN     = (28, 110, 44)
DINO_COL   = (220, 220, 220)
DINO_DARK  = (155, 155, 155)
CACTUS     = (46, 170, 68)
BG         = (14, 14, 14)
CARD_BG    = (20, 20, 20)
BORDER     = (40, 40, 40)
DIM        = (80, 80, 80)
MID        = (130, 130, 130)
BRIGHT     = (210, 210, 210)
SCORE_COL  = (96, 96, 96)
HI_COL     = (60, 60, 60)
GOLD       = (255, 200, 0)
RED        = (204, 51, 51)

# ── background ────────────────────────────────────────────────────────────────
for y in range(H):
    v = int(10 + (H - y) * 0.04)
    d.line([(0, y), (W, y)], fill=(v, v, v))
for y in range(0, H, 4):
    d.line([(0, y), (W, y)], fill=(0, 0, 0, 18))

# ── title bar ─────────────────────────────────────────────────────────────────
TITLE_H = 80
pill(d, 0, 0, W, TITLE_H, 0, (16, 16, 16))
d.line([(0, TITLE_H), (W, TITLE_H)], fill=BORDER, width=1)

fn_title = load_font(46, bold=True)
fn_sub   = load_font(18)
centered(d, "BITOCHI DINO RUN", W // 2, 12, fn_title, GREEN)
centered(d, "Chrome-style endless runner for Garmin round watches",
         W // 2, TITLE_H - 24, fn_sub, DIM)

# ── layout ────────────────────────────────────────────────────────────────────
MARGIN = 24
GAP    = 20
LW     = 320   # left card: controls
GW_PX  = 520   # centre: simulated game screen
RW     = W - LW - GW_PX - MARGIN * 2 - GAP * 2  # right card: features

LX = MARGIN
GX = LX + LW + GAP
RX = GX + GW_PX + GAP

CARD_TOP = TITLE_H + 18
CARD_BOT = H - 18
CARD_H   = CARD_BOT - CARD_TOP

fn_h  = load_font(16, bold=True)
fn_b  = load_font(14)
fn_sm = load_font(12)
fn_xs = load_font(11)

# ── LEFT card — controls ──────────────────────────────────────────────────────
pill(d, LX, CARD_TOP, LW, CARD_H, 10, CARD_BG, BORDER)
centered(d, "CONTROLS", LX + LW // 2, CARD_TOP + 14, fn_h, GREEN)
d.line([(LX + 16, CARD_TOP + 36), (LX + LW - 16, CARD_TOP + 36)], fill=BORDER)

controls = [
    ("ANY BUTTON",  "Jump / Start / Restart"),
    ("BACK",        "Pause mid-run"),
    ("TAP SCREEN",  "Jump (touchscreen)"),
]

cy2 = CARD_TOP + 50
for key, desc in controls:
    tw = text_w(d, key, fn_b)
    pill(d, LX + 16, cy2, tw + 16, 24, 5, (28, 28, 28))
    d.text((LX + 24, cy2 + 5), key, font=fn_b, fill=GREEN)
    d.text((LX + 16, cy2 + 30), desc, font=fn_sm, fill=MID)
    cy2 = cy2 + 58

d.line([(LX + 16, cy2 + 4), (LX + LW - 16, cy2 + 4)], fill=BORDER)
cy2 = cy2 + 18

# difficulty note
for line in [
    "Speed increases automatically.",
    "Game ends on collision.",
    "High score saved until",
    "app is closed.",
]:
    d.text((LX + 16, cy2), line, font=fn_xs, fill=DIM)
    cy2 = cy2 + 18

# ── CENTRE — simulated watch screen ──────────────────────────────────────────
SCRSZ = min(CARD_H - 20, GW_PX - 20)
SCR_X = GX + (GW_PX - SCRSZ) // 2
SCR_Y = CARD_TOP + (CARD_H - SCRSZ) // 2

# watch bezel (outer ring)
pill(d, SCR_X - 12, SCR_Y - 12, SCRSZ + 24, SCRSZ + 24, (SCRSZ + 24) // 2,
     (28, 28, 28), (50, 50, 50))
# screen
pill(d, SCR_X, SCR_Y, SCRSZ, SCRSZ, SCRSZ // 2, (16, 16, 16))

# clip mask for round screen
mask = Image.new("L", (SCRSZ, SCRSZ), 0)
ImageDraw.Draw(mask).ellipse([0, 0, SCRSZ - 1, SCRSZ - 1], fill=255)
scr_img = Image.new("RGB", (SCRSZ, SCRSZ), (16, 16, 16))
sd = ImageDraw.Draw(scr_img)

SW = SCRSZ
SH = SCRSZ
GRD_SY = SH * 70 // 100

# ground
sd.rectangle([0, GRD_SY, SW, GRD_SY + 2], fill=(58, 58, 58))
sd.rectangle([0, GRD_SY + 4, SW, GRD_SY + 4], fill=(38, 38, 38))

# clouds
for (cx, cy3, cw3) in [(SW*35//100, SH*18//100, 70), (SW*62//100, SH*26//100, 55),
                        (SW*80//100, SH*12//100, 80)]:
    sd.rounded_rectangle([cx, cy3 + 8, cx + cw3, cy3 + 18], radius=5, fill=(28, 28, 28))
    sd.rounded_rectangle([cx + cw3//5, cy3, cx + cw3*4//5, cy3 + 20], radius=8, fill=(28, 28, 28))

# dino
DX2 = SW * 17 // 100
DW2 = SW * 7 // 100
if DW2 < 22: DW2 = 22
DH2 = DW2 + DW2 // 2
DY2 = GRD_SY - DH2

sd.rounded_rectangle([DX2, DY2 + DH2*36//100, DX2 + DW2*76//100, DY2 + DH2], radius=3, fill=DINO_COL)
sd.rounded_rectangle([DX2 + DW2*36//100, DY2 + DH2*4//100, DX2 + DW2, DY2 + DH2*42//100], radius=3, fill=DINO_COL)
sd.rounded_rectangle([DX2 - DW2*10//100, DY2 + DH2*40//100,
                       DX2 + DW2*8//100,  DY2 + DH2*58//100], radius=2, fill=DINO_DARK)
sd.rectangle([DX2 + DW2*85//100, DY2 + DH2*11//100,
              DX2 + DW2*85//100 + 3, DY2 + DH2*11//100 + 3], fill=(16, 16, 16))
# legs
sd.rectangle([DX2 + DW2*22//100, DY2 + DH2*74//100, DX2 + DW2*38//100, DY2 + DH2], fill=DINO_DARK)
sd.rectangle([DX2 + DW2*50//100, DY2 + DH2*80//100, DX2 + DW2*66//100, DY2 + DH2], fill=DINO_DARK)

# cactus
def draw_cactus(draw, ox, oh, ow, grd_y):
    oy = grd_y - oh
    draw.rounded_rectangle([ox + ow//4, oy, ox + ow*3//4, grd_y], radius=2, fill=CACTUS)
    if oh > DH2 * 6 // 10:
        draw.rounded_rectangle([ox, oy + oh//4, ox + ow*28//100, oy + oh*42//100], radius=2, fill=DGREEN)
        draw.rounded_rectangle([ox + ow*7//10, oy + oh*36//100, ox + ow, oy + oh*54//100], radius=2, fill=DGREEN)

draw_cactus(sd, SW * 55 // 100, DH2 * 75 // 100, DW2 * 10 // 10, GRD_SY)
draw_cactus(sd, SW * 68 // 100, DH2 * 95 // 100, DW2 * 12 // 10, GRD_SY)

# score
fn_scr = load_font(13)
tw_s = text_w(sd, "00347", fn_scr)
sd.text((SW * 78 // 100 - tw_s // 2, SH * 8 // 100), "00347", font=fn_scr, fill=(96, 96, 96))
fn_hi = load_font(11)
tw_h = text_w(sd, "HI 00512", fn_hi)
sd.text((SW * 78 // 100 - tw_h // 2, SH * 17 // 100), "HI 00512", font=fn_hi, fill=(60, 60, 60))

img.paste(scr_img, (SCR_X, SCR_Y), mask)

# ── RIGHT card — features & obstacles ────────────────────────────────────────
pill(d, RX, CARD_TOP, RW, CARD_H, 10, CARD_BG, BORDER)
centered(d, "FEATURES", RX + RW // 2, CARD_TOP + 14, fn_h, GREEN)
d.line([(RX + 16, CARD_TOP + 36), (RX + RW - 16, CARD_TOP + 36)], fill=BORDER)

features = [
    (GREEN,  "Infinite runner"),
    (GREEN,  "3 cactus sizes"),
    (GREEN,  "Speed ramp (5→13 px/tick)"),
    (GREEN,  "Running animation"),
    (GREEN,  "Parallax clouds"),
    (GOLD,   "High score tracking"),
    (GOLD,   "NEW BEST flash"),
    ((170, 170, 170), "Round-watch optimised"),
    ((170, 170, 170), "No permissions needed"),
]

fy = CARD_TOP + 50
for col, txt in features:
    d.ellipse([RX + 20, fy + 5, RX + 28, fy + 13], fill=col)
    d.text((RX + 36, fy), txt, font=fn_sm, fill=MID)
    fy = fy + 26

d.line([(RX + 16, fy + 4), (RX + RW - 16, fy + 4)], fill=BORDER)
fy = fy + 18
centered(d, "OBSTACLES", RX + RW // 2, fy, fn_h, DIM)
fy = fy + 24

# draw 3 mini cactus types
cactus_data = [("SMALL", DH2*55//100), ("MEDIUM", DH2*75//100), ("LARGE", DH2*95//100)]
slot_w = (RW - 32) // 3
for idx, (label, oh) in enumerate(cactus_data):
    sx = RX + 16 + idx * slot_w + slot_w // 2
    ow2 = 20
    oy2 = fy + 50 - oh
    # stem
    d.rectangle([sx - ow2//4, oy2, sx + ow2//4, fy + 50], fill=GREEN)
    if oh > 25:
        d.rectangle([sx - ow2//2, oy2 + oh//4, sx - ow2//4 + 2, oy2 + oh*42//100], fill=DGREEN)
        d.rectangle([sx + ow2//4 - 2, oy2 + oh*36//100, sx + ow2//2, oy2 + oh*54//100], fill=DGREEN)
    centered(d, label, sx, fy + 56, fn_xs, DIM)

# ── bottom bar ────────────────────────────────────────────────────────────────
d.line([(0, H - 28), (W, H - 28)], fill=BORDER)
centered(d, "BITOCHI — bitochi.com", W // 2, H - 20, fn_xs, (40, 40, 40))

img.save(OUT)
print(f"Saved {OUT}")
