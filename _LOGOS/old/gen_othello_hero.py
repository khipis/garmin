#!/usr/bin/env python3
"""Generate othello_hero.png (1440×720) — dramatic in-game moment."""
from PIL import Image, ImageDraw, ImageFont
import math, os

W, H = 1440, 720
OUT  = os.path.join(os.path.dirname(__file__), "othello_hero.png")

# ── Palette ───────────────────────────────────────────────────────────────────
BG       = (6,  14,  6)
BOARD_BG = (22, 100, 22)
GRID_LN  = (10,  72, 10)
ACCENT   = (40, 220, 40)
DIM_ACC  = (20, 110, 20)
TITLE_C  = (50, 240, 50)
SHADOW   = (0,   0,  0)
WHITE_D  = (230, 230, 230)
BLACK_D  = (18,  18,  18)
CURSOR   = (255, 240,  40)
ARROW    = (255, 80,  40)
FLIP_HL  = (255, 140,  30)
BADGE_BG = (10,  28, 10)

img  = Image.new("RGB", (W, H), BG)
draw = ImageDraw.Draw(img)

def font(size, bold=True):
    candidates = [
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/Arial.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
    ]
    for p in candidates:
        try: return ImageFont.truetype(p, size)
        except: pass
    return ImageFont.load_default()

# ── Background gradient bands ─────────────────────────────────────────────────
for y in range(H):
    t = y / H
    r = int(BG[0] + t * 4)
    g = int(BG[1] + t * 8)
    b = int(BG[2] + t * 4)
    draw.line([(0, y), (W, y)], fill=(r, g, b))

# ── Large board — left-center ──────────────────────────────────────────────────
STEP  = 66
BOARD = STEP * 8
BX    = 80
BY    = (H - BOARD) // 2 - 10

# Board shadow
draw.rectangle([BX+6, BY+6, BX+BOARD+6, BY+BOARD+6], fill=(0, 30, 0))
# Board surface
draw.rectangle([BX, BY, BX+BOARD, BY+BOARD], fill=BOARD_BG)
# Grid lines
for i in range(9):
    lx = BX + i * STEP; ly = BY + i * STEP
    draw.line([(lx, BY), (lx, BY+BOARD)], fill=GRID_LN, width=2)
    draw.line([(BX, ly), (BX+BOARD, ly)], fill=GRID_LN, width=2)
# Star dots (classic Othello markers at d4,d6,f4,f6)
for (gr, gc) in [(2, 2), (2, 5), (5, 2), (5, 5)]:
    sx = BX + gc * STEP; sy = BY + gr * STEP
    draw.ellipse([sx-4, sy-4, sx+4, sy+4], fill=GRID_LN)
# Board border
draw.rectangle([BX, BY, BX+BOARD, BY+BOARD], outline=(8, 55, 8), width=3)

DR = 27  # disc radius

def stone(gc, gr, col, highlight=False, flipping=False):
    px = BX + gc * STEP + STEP // 2
    py = BY + gr * STEP + STEP // 2
    if flipping:
        # Draw squished flipping disc (mid-flip = thin oval)
        draw.ellipse([px-DR, py-7, px+DR, py+7], fill=FLIP_HL)
        draw.ellipse([px-DR+3, py-5, px-DR+10, py-1], fill=(255,200,80))
        return
    if col == 'B':
        draw.ellipse([px-DR+2, py-DR+2, px+DR+2, py+DR+2], fill=(0, 0, 0))  # shadow
        draw.ellipse([px-DR, py-DR, px+DR, py+DR], fill=BLACK_D)
        draw.ellipse([px-DR+5, py-DR+5, px-DR+14, py-DR+14], fill=(60, 60, 60))
        if highlight:
            draw.ellipse([px-DR-3, py-DR-3, px+DR+3, py+DR+3], outline=FLIP_HL, width=3)
    else:
        draw.ellipse([px-DR+2, py-DR+2, px+DR+2, py+DR+2], fill=(80, 80, 80))  # shadow
        draw.ellipse([px-DR, py-DR, px+DR, py+DR], fill=WHITE_D)
        draw.ellipse([px-DR+5, py-DR+5, px-DR+14, py-DR+14], fill=(255, 255, 255))
        if highlight:
            draw.ellipse([px-DR-3, py-DR-3, px+DR+3, py+DR+3], outline=FLIP_HL, width=3)

# ── A dramatic mid-game board position ────────────────────────────────────────
# White just played at (4,2) — capturing a long diagonal chain of Black discs
# Rows 0-7, Cols 0-7
static_discs = [
    # Row 0
    ('B',0,0),('W',1,0),('B',2,0),('W',3,0),('W',4,0),('B',5,0),('W',6,0),('B',7,0),
    # Row 1
    ('W',0,1),('B',1,1),('W',2,1),('B',3,1),('W',4,1),('W',5,1),('B',6,1),('W',7,1),
    # Row 2 — highlight: white played (4,2), now a chain is captured
    ('B',0,2),('B',1,2),('W',2,2),('B',3,2),            ('B',5,2),('B',6,2),('W',7,2),
    # Row 3
    ('W',0,3),('B',1,3),('B',2,3),('W',3,3),('B',4,3),('W',5,3),('W',6,3),('W',7,3),
    # Row 4
    ('B',0,4),('W',1,4),('W',2,4),('B',3,4),('W',4,4),('B',5,4),('W',6,4),('B',7,4),
    # Row 5
    ('W',0,5),('B',1,5),('W',2,5),('B',3,5),('B',4,5),('W',5,5),('B',6,5),('W',7,5),
    # Row 6
    ('B',0,6),('W',1,6),('B',2,6),('W',3,6),('B',4,6),('B',5,6),('W',6,6),
    # Row 7
    ('W',0,7),('B',1,7),('W',2,7),('B',3,7),           ('B',5,7),('W',6,7),('B',7,7),
]
for (col, gc, gr) in static_discs:
    stone(gc, gr, col)

# Flipping discs (the captured chain, mid-flip animation): horizontal row 2, cols 3-6
flip_chain = [(3,2),(4,2),(5,2)]  # these are captured/flipping
for (gc, gr) in flip_chain:
    stone(gc, gr, 'B', flipping=True)

# The new white disc just placed at (6,2) — highlighted winner
stone(6, 2, 'W', highlight=True)
# Also highlight the disc that was the "anchor" of the capture
stone(2, 2, 'W', highlight=True)

# Valid-move dots (3 candidate positions)
for (gc, gr) in [(4, 7), (2, 4)]:
    vx = BX + gc * STEP + STEP // 2
    vy = BY + gr * STEP + STEP // 2
    draw.ellipse([vx-7, vy-7, vx+7, vy+7], fill=ACCENT, outline=(20, 180, 20), width=2)

# Cursor around valid move at (4,7)
cur_gc, cur_gr = 4, 7
cpx = BX + cur_gc * STEP; cpy = BY + cur_gr * STEP
for thickness in [4, 2]:
    off = 4 - thickness
    draw.rectangle([cpx+off, cpy+off, cpx+STEP-off, cpy+STEP-off],
                   outline=CURSOR, width=thickness)

# ── Capture arrows — show the sandwich ────────────────────────────────────────
# Draw arrow from anchor (2,2) through flipping chain to new stone (6,2)
def arrow(x0, y0, x1, y1, col=ARROW, w=4):
    draw.line([(x0, y0), (x1, y1)], fill=col, width=w)
    # Arrowhead
    dx = x1 - x0; dy = y1 - y0
    length = math.sqrt(dx*dx + dy*dy)
    if length < 1: return
    ux = dx / length; uy = dy / length
    px = -uy; py = ux
    size = 14
    ax = x1 - ux*size; ay = y1 - uy*size
    pts = [(int(x1), int(y1)),
           (int(ax + px*size*0.5), int(ay + py*size*0.5)),
           (int(ax - px*size*0.5), int(ay - py*size*0.5))]
    draw.polygon(pts, fill=col)

# Horizontal capture chain arrow across row 2
ax0 = BX + 2*STEP + STEP//2
ay0 = BY + 2*STEP + STEP//2
ax1 = BX + 6*STEP + STEP//2
ay1 = ay0
arrow(ax0, ay0, ax1, ay1, ARROW, 4)

# Label "FLIPPED!" above the chain
fx = (ax0 + ax1) // 2
fy = ay0 - DR - 22
draw.text((fx+2, fy+2), "FLIPPED!", font=font(22), fill=(0,0,0), anchor="mm")
draw.text((fx, fy), "FLIPPED!", font=font(22), fill=FLIP_HL, anchor="mm")

# ── Right panel — title + features ────────────────────────────────────────────
PX = BX + BOARD + 60
PW = W - PX - 30

# Title block
draw.text((PX + PW//2 + 2, 52), "OTHELLO", font=font(86), fill=(0,30,0), anchor="mm")
draw.text((PX + PW//2,     52), "OTHELLO", font=font(86), fill=TITLE_C, anchor="mm")
draw.text((PX + PW//2 + 2, 122), "BLITZ", font=font(86), fill=(0,30,0), anchor="mm")
draw.text((PX + PW//2,     122), "BLITZ", font=font(86), fill=TITLE_C, anchor="mm")

# Subtitle
draw.text((PX + PW//2, 160), "Classic strategy on your wrist",
          font=font(22), fill=DIM_ACC, anchor="mm")

# Separator line
draw.rectangle([PX, 178, PX + PW, 181], fill=ACCENT)

# ── Score panel ───────────────────────────────────────────────────────────────
SY = 200
# Black side
BK_CNT = 23; WH_CNT = 33
# Black disc + score
bsx = PX + PW // 4
draw.ellipse([bsx-22, SY-22, bsx+22, SY+22], fill=BLACK_D)
draw.ellipse([bsx-17, SY-17, bsx-9,  SY-9],  fill=(60,60,60))
draw.text((bsx + 34, SY + 2), str(BK_CNT), font=font(42), fill=(180,180,180), anchor="lm")
# White disc + score
wsx = PX + PW * 3 // 4
draw.ellipse([wsx-22, SY-22, wsx+22, SY+22], fill=WHITE_D)
draw.ellipse([wsx-17, SY-17, wsx-9,  SY-9],  fill=(255,255,255))
draw.text((wsx + 34, SY + 2), str(WH_CNT), font=font(42), fill=(240,240,240), anchor="lm")
# "vs" label
draw.text((PX + PW//2, SY + 2), "vs", font=font(26), fill=DIM_ACC, anchor="mm")

# Move indicator "WHITE MOVES"
draw.text((PX + PW//2, SY + 52), "WHITE TO MOVE",
          font=font(20), fill=WHITE_D, anchor="mm")

# Separator
draw.rectangle([PX, SY + 72, PX + PW, SY + 74], fill=(20, 60, 20))

# ── Feature badges ─────────────────────────────────────────────────────────────
features = [
    ("8×8 BOARD",      "Classic full-size grid"),
    ("FLIP CAPTURES",  "Sandwich to convert discs"),
    ("3 AI LEVELS",    "Easy · Medium · Hard"),
    ("3 GAME MODES",   "PvAI · PvP · AI vs AI"),
    ("SIDE CHOICE",    "Play as Black or White"),
    ("WRAP CURSOR",    "One-button H/V navigation"),
]

FY0 = SY + 92
ROW_H = 62
COL_W = PW // 2

for idx, (title, desc) in enumerate(features):
    col = idx % 2
    row = idx // 2
    fx = PX + col * COL_W + 12
    fy = FY0 + row * ROW_H
    # Badge background
    draw.rounded_rectangle([fx, fy, fx + COL_W - 16, fy + ROW_H - 8],
                            radius=6, fill=BADGE_BG, outline=(20, 70, 20), width=1)
    draw.text((fx + 10, fy + 12), title, font=font(18), fill=ACCENT)
    draw.text((fx + 10, fy + 35), desc,  font=font(14), fill=(100, 150, 100))

# ── Bottom bar ────────────────────────────────────────────────────────────────
draw.rectangle([0, H-34, W, H], fill=(5, 18, 5))
draw.rectangle([0, H-34, W, H-31], fill=(20, 80, 20))
controls = [
    ("◀▶ / PAGE BTN", "move cursor"),
    ("SELECT",         "place disc"),
    ("BACK",           "menu / exit"),
]
cw = W // len(controls)
for i, (key, act) in enumerate(controls):
    cx2 = i * cw + cw // 2
    draw.text((cx2, H - 17), f"{key}  —  {act}", font=font(16), fill=(70, 130, 70), anchor="mm")

img.save(OUT)
print(f"Saved → {OUT}")
