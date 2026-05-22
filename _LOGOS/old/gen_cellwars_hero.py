#!/usr/bin/env python3
"""Generate the Bitochi Cell Wars hero / store banner image (1440 x 720 px).

Layout (all values within canvas):
  TOP BANNER  – 56 px  – full-width title "BITOCHI CELL WARS"
  LEFT  card  – 350 px wide  – algorithm guide
  CENTRE      – 608 px wide  – simulated battlefield grid (608×608)
  RIGHT card  – ~404 px wide – battle modes + features

Visual style: NEON theme – black bg, bright glowing pixels.
"""

from PIL import Image, ImageDraw, ImageFont
import math, random, os

W, H = 1440, 720
OUT  = os.path.join(os.path.dirname(__file__), "cellwars_hero.png")
random.seed(2025)

# ── Fonts ─────────────────────────────────────────────────────────────────────
def load(path, size, fallback=None):
    for p in ([path] if path else []) + (fallback or []):
        try: return ImageFont.truetype(p, size)
        except Exception: pass
    return ImageFont.load_default()

FONT_PATHS = [
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    "/System/Library/Fonts/Helvetica.ttc",
    "/System/Library/Fonts/Arial.ttf",
]
FONT_PATHS_REG = [
    "/System/Library/Fonts/Supplemental/Arial.ttf",
    "/System/Library/Fonts/Helvetica.ttc",
]

f_xl  = load(None, 72,  FONT_PATHS)
f_lg  = load(None, 44,  FONT_PATHS)
f_md  = load(None, 28,  FONT_PATHS)
f_sm  = load(None, 20,  FONT_PATHS)
f_xs  = load(None, 15,  FONT_PATHS_REG)

# ── Colours ───────────────────────────────────────────────────────────────────
BG          = (0, 0, 0)
CARD_BG     = (12, 10, 22)
CARD_BORDER = (40, 40, 70)
TITLE_COL   = (0, 238, 255)    # cyan

TEAM_COLS = [
    (0x00, 0xEE, 0xFF),   # cyan    – Conway
    (0xFF, 0x66, 0x00),   # orange  – HighLife
    (0xCC, 0x22, 0xFF),   # purple  – Day&Night
    (0x00, 0xFF, 0x88),   # green   – Maze
    (0xFF, 0x22, 0x88),   # magenta – Seeds
]

ALGO_INFO = [
    ("CONWAY",  "B3/S23",        "The classic — balanced growth"),
    ("HLIFE",   "B36/S23",       "Replicating patterns emerge"),
    ("DAY+N",   "B3678/S34678",  "Symmetric — alive=dead stable"),
    ("MAZE",    "B3/S12345",     "Carves sprawling corridors"),
    ("SEEDS",   "B2/S–",         "Explosive scatter birth"),
    ("CORAL",   "B3/S45678",     "Dense coral reef growth"),
    ("REPLI",   "B1357/S1357",   "Self-similar replication"),
    ("AMOEBA",  "B357/S1358",    "Flowing amorphous shapes"),
]

# ── Build a battle grid ───────────────────────────────────────────────────────
GCW, GCH = 72, 72
NTEAMS = 5

grid = [[0]*GCW for _ in range(GCH)]
for y in range(GCH):
    for x in range(GCW):
        if random.random() < 0.46:
            # Bias teams toward quadrants for a visible front-line effect
            if   x < GCW*0.35 and y < GCH*0.5:  grid[y][x] = 1
            elif x > GCW*0.65 and y < GCH*0.5:  grid[y][x] = 2
            elif x < GCW*0.4  and y > GCH*0.55: grid[y][x] = 3
            elif x > GCW*0.6  and y > GCH*0.55: grid[y][x] = 4
            else:                                 grid[y][x] = 5
        else:
            grid[y][x] = 0

def step_battle(g, n=NTEAMS):
    nxt = [[0]*GCW for _ in range(GCH)]
    for y in range(GCH):
        for x in range(GCW):
            counts = [0]*n
            total  = 0
            for dy in range(-1, 2):
                for dx in range(-1, 2):
                    if dx == 0 and dy == 0: continue
                    ny, nx = y+dy, x+dx
                    if 0 <= ny < GCH and 0 <= nx < GCW:
                        c = g[ny][nx]
                        if c > 0:
                            total += 1
                            if c-1 < n: counts[c-1] += 1
            c = g[y][x]
            if c > 0:
                nxt[y][x] = c if total in (2, 3) else 0
            else:
                if total == 3:
                    best = max(range(n), key=lambda t: counts[t])
                    nxt[y][x] = best+1 if counts[best] > 0 else 0
    return nxt

print("Simulating battlefield…")
for i in range(30):
    grid = step_battle(grid)
    if i % 10 == 0: print(f"  gen {i}")

# ── Layout constants (all derived so nothing escapes the canvas) ───────────────
MARGIN  = 12   # outer margin
GAP     = 14   # gap between columns
TITLE_H = 82   # top title strip height (title 52px + subtitle 18px + padding)
COL_Y   = TITLE_H + 4          # columns start here (y)
COL_H   = H - COL_Y - MARGIN   # column height  (= 720-62-12 = 646)

LW = 350                        # left card width
GW_PX = min(608, COL_H)         # grid is square, fits inside column height (608)
GH_PX = GW_PX
LX = MARGIN                     # left card x
GX = LX + LW + GAP             # grid x  (= 12+350+14 = 376)
RX = GX + GW_PX + GAP          # right card x  (= 376+608+14 = 998)
RW = W - RX - MARGIN            # right card width  (= 1440-998-12 = 430)
LH = COL_H
RH = COL_H
GY = COL_Y + (COL_H - GH_PX) // 2  # vertically centre the grid

# ── Canvas ────────────────────────────────────────────────────────────────────
img  = Image.new("RGB", (W, H), BG)
draw = ImageDraw.Draw(img)

# Deep space starfield
for _ in range(600):
    sx, sy = random.randint(0, W-1), random.randint(0, H-1)
    br = random.randint(30, 110)
    img.putpixel((sx, sy), (br, br, min(255, br+30)))

def card(x, y, w, h, col=CARD_BG, border=CARD_BORDER, radius=14):
    draw.rounded_rectangle([x, y, x+w, y+h], radius=radius, fill=col, outline=border, width=1)

def text_c(tx, ty, txt, font, col, anchor="mm"):
    draw.text((tx, ty), txt, font=font, fill=col, anchor=anchor)

def text_l(tx, ty, txt, font, col):
    draw.text((tx, ty), txt, font=font, fill=col, anchor="lm")

# ── TOP TITLE BANNER ──────────────────────────────────────────────────────────
# Gradient-like strip across full width
for gy_px in range(TITLE_H):
    alpha = int(30 * (1 - gy_px / TITLE_H))
    draw.line([(0, gy_px), (W, gy_px)], fill=(0, alpha//2, alpha))

# "BITOCHI" in a slightly smaller accent colour, "CELL WARS" in full cyan
title_y = 38   # vertically centre title in upper ~55px
# Measure approximate widths to place side-by-side
bitochi_txt = "BITOCHI "
cw_txt      = "CELL WARS"
# Draw as one combined string, coloured by drawing twice with offset fill trick
full_title = "BITOCHI  CELL WARS"
# Shadow / glow pass
draw.text((W//2, title_y), full_title, font=f_xl, fill=(0, 80, 100),
          anchor="mm", stroke_width=4, stroke_fill=(0, 40, 60))
# "BITOCHI" in softer teal, "CELL WARS" in bright cyan — approximate by drawing
# the full string in cyan, then overdraw just "BITOCHI" in teal
draw.text((W//2, title_y), full_title, font=f_xl, fill=(0, 238, 255), anchor="mm")
# Overdraw "BITOCHI" portion left-anchored from centre offset
bw = draw.textlength("BITOCHI  ", font=f_xl)
cw = draw.textlength(full_title,  font=f_xl)
bx_start = W//2 - cw//2
draw.text((bx_start, title_y), "BITOCHI", font=f_xl, fill=(0, 200, 180), anchor="lm")

# Subtitle line — well below title glyphs
draw.text((W//2, TITLE_H - 14), "Cellular Automata Battle Simulator for Garmin Watches",
          font=f_xs, fill=(70, 120, 145), anchor="mm")

# ── LEFT card — algorithm guide ───────────────────────────────────────────────
card(LX, COL_Y, LW, LH)

text_c(LX + LW//2, COL_Y + 24, "ALGORITHMS", f_md, (180, 180, 220))

row_h   = (LH - 72) // len(ALGO_INFO)   # distribute rows evenly
start_y = COL_Y + 66
for i, (tag, rule, desc) in enumerate(ALGO_INFO):
    ry  = start_y + i * row_h
    col = TEAM_COLS[i % NTEAMS]
    sw  = 28
    draw.rounded_rectangle([LX+14, ry-sw//2, LX+14+sw, ry+sw//2], radius=4, fill=col)
    text_l(LX+50, ry - 7, tag,  f_sm, col)
    text_l(LX+50, ry + 9,  rule, f_xs, (160, 160, 180))
    # clip description to card width
    draw.text((LX+50, ry + 23), desc, font=f_xs, fill=(90, 90, 110), anchor="lm")

# badge at bottom
bx = LX + LW//2
by = COL_Y + LH - 18
draw.rounded_rectangle([bx-96, by-12, bx+96, by+12], radius=9,
                        fill=(15, 50, 70), outline=(0, 170, 210))
text_c(bx, by, "8 ALGORITHMS  •  4 THEMES", f_xs, (0, 190, 215))

# ── CENTRE — battlefield ──────────────────────────────────────────────────────
CSIZ = GW_PX // GCW   # cell pixel size

for cy in range(GCH):
    for cx in range(GCW):
        c = grid[cy][cx]
        if c == 0: continue
        col = TEAM_COLS[(c-1) % NTEAMS]
        px = GX + cx * CSIZ
        py = GY + cy * CSIZ
        gc = tuple(v//4 for v in col)
        draw.rectangle([px-1, py-1, px+CSIZ, py+CSIZ], fill=gc)
        draw.rectangle([px, py, px+CSIZ-1, py+CSIZ-1], fill=col)

# Grid border
draw.rectangle([GX-1, GY-1, GX+GW_PX, GY+GH_PX], outline=(50, 50, 90), width=1)

# ── RIGHT card — battle modes ─────────────────────────────────────────────────
card(RX, COL_Y, RW, RH)

text_c(RX + RW//2, COL_Y + 24, "BATTLE MODES", f_md, (180, 180, 220))

modes = [
    ("BATTLE",   "All teams — Conway rules"),
    ("RUMBLE",   "Each team's own algorithm"),
    ("CONWAY",   "Pure Conway B3/S23"),
    ("HIGHLIFE", "B36/S23 with replicators"),
    ("DAY+N",    "B3678 symmetric life"),
    ("MAZE",     "B3/S12345 corridors"),
    ("SEEDS",    "B2/S explosive birth"),
]

mrow = (RH - 130) // len(modes)
msy  = COL_Y + 62
for i, (mname, msub) in enumerate(modes):
    my  = msy + i * mrow + mrow // 2
    col = TEAM_COLS[i % NTEAMS]
    bx1 = RX + 12
    bx2 = RX + RW - 12
    draw.rounded_rectangle([bx1, my-18, bx2, my+18],
                            radius=7, fill=(18, 16, 32), outline=col, width=1)
    text_c(RX + RW//2, my - 4, mname, f_sm, col)
    text_c(RX + RW//2, my + 11, msub,  f_xs, (130, 130, 155))

# Feature pills — 2×2 grid inside right card bottom
pills = ["AUTO RESET", "SPEED 1-5", "FILL CONTROL", "RANDOM ALGOS"]
pill_area_y = COL_Y + RH - 58
pill_w      = (RW - 36) // 2
for i, pill in enumerate(pills):
    px = RX + 12 + (i % 2) * (pill_w + 12)
    py = pill_area_y + (i // 2) * 26
    draw.rounded_rectangle([px, py-10, px+pill_w, py+10],
                            radius=6, fill=(10, 28, 48), outline=(0, 145, 195))
    text_c(px + pill_w//2, py, pill, f_xs, (0, 195, 225))

# Version badge bottom-right corner (well inside canvas)
vbx = W - MARGIN - 56
vby = H - MARGIN - 14
draw.rounded_rectangle([vbx-50, vby-11, vbx+50, vby+11], radius=8,
                        fill=(18, 55, 75), outline=(0, 175, 215))
text_c(vbx, vby, "v1.0  NEON", f_xs, (0, 225, 250))

img.save(OUT, "PNG", optimize=True)
print(f"Hero image saved → {OUT}  ({os.path.getsize(OUT)//1024} KB)")
