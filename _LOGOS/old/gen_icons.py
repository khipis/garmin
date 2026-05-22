#!/usr/bin/env python3
"""
Generate launcher_icon.png (40×40 RGBA) for:
  bricks, color, serpent, moon, blobs, blocks
And moon_hero.png (1440×720 RGB) for _LOGOS.
"""
import math, os, random
from PIL import Image, ImageDraw, ImageFilter

random.seed(77)

BASE  = os.path.dirname(os.path.abspath(__file__))
GAMES = os.path.dirname(BASE)

def save_icon(img, game):
    p = os.path.join(GAMES, game, "resources", "launcher_icon.png")
    img.save(p, "PNG")
    print(f"  icon → {game}/resources/launcher_icon.png")

def save_logo(img, name):
    p = os.path.join(BASE, name)
    img.convert("RGB").save(p, "PNG", optimize=True)
    kb = os.path.getsize(p) // 1024
    print(f"  logo → _LOGOS/{name}  ({kb} KB)")

def new_icon():
    return Image.new("RGBA", (40, 40), (0, 0, 0, 255))

def get_font(size):
    for path in [
        "/System/Library/Fonts/Supplemental/Impact.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/Arial.ttf",
        "/Library/Fonts/Arial.ttf",
    ]:
        try:
            from PIL import ImageFont
            return ImageFont.truetype(path, size)
        except:
            pass
    from PIL import ImageFont
    return ImageFont.load_default()

# ═══════════════════════════════════════════════════════════════════════════════
#  BRICKS — rows of coloured bricks, bouncing ball, paddle
# ═══════════════════════════════════════════════════════════════════════════════
print("bricks launcher_icon.png")
img = new_icon()
d = ImageDraw.Draw(img)

# Background gradient (dark navy → mid blue)
for y in range(40):
    t = y / 39
    r = int(6  + t * 10)
    g = int(10 + t * 18)
    b = int(28 + t * 22)
    d.line([(0, y), (39, y)], fill=(r, g, b, 255))

# Brick rows  — 5 bricks × 3 rows, each brick 7×4 px, 1 px gap
brick_rows = [
    (3,  [(220, 55, 55), (230, 65, 55), (225, 55, 55), (220, 60, 55), (230, 55, 55)]),
    (9,  [(230, 140, 30), (235, 130, 30), (230, 135, 30), (235, 140, 30), (230, 130, 30)]),
    (15, [(210, 200, 30), (215, 205, 30), (210, 195, 30), (215, 200, 30), (210, 205, 30)]),
]
for (ry, cols) in brick_rows:
    for i, col in enumerate(cols):
        bx = 1 + i * 8
        d.rectangle([bx, ry, bx + 6, ry + 3], fill=col + (255,))
        # Highlight top
        d.line([(bx, ry), (bx + 6, ry)], fill=(255, 255, 255, 80))
        # Shadow bottom
        d.line([(bx, ry + 3), (bx + 6, ry + 3)], fill=(0, 0, 0, 100))

# Ball — white circle with glow
for r in range(4, 0, -1):
    a = 60 + r * 45
    d.ellipse([27 - r, 25 - r, 27 + r, 25 + r], fill=(255, 255, 255, a))

# Paddle
d.rounded_rectangle([8, 35, 31, 38], radius=1, fill=(180, 220, 255, 255))
d.line([(9, 35), (30, 35)], fill=(255, 255, 255, 120))

# Ball trail
d.line([(23, 22), (27, 25)], fill=(180, 220, 255, 100), width=1)

save_icon(img, "bricks")


# ═══════════════════════════════════════════════════════════════════════════════
#  COLOR (DIAMONDS) — sparkling coloured diamonds on dark bg
# ═══════════════════════════════════════════════════════════════════════════════
print("color launcher_icon.png")
img = new_icon()
d = ImageDraw.Draw(img)

# Background: deep purple-black
for y in range(40):
    t = y / 39
    d.line([(0, y), (39, y)], fill=(int(10 + t * 6), int(5 + t * 8), int(20 + t * 10), 255))

# 4 large diamonds arranged in 2×2 grid
gem_defs = [
    # (cx, cy, half_w, half_h, base_col, highlight)
    (10, 11, 7, 8, (50, 220, 240),  (180, 255, 255)),   # cyan
    (30, 11, 7, 8, (240, 70,  70),  (255, 180, 180)),   # red
    (10, 29, 7, 8, (255, 210, 40),  (255, 255, 160)),   # yellow
    (30, 29, 7, 8, (160, 80,  255), (220, 180, 255)),   # purple
]
for (cx, cy, hw, hh, col, hi) in gem_defs:
    # Shadow
    pts_s = [(cx, cy - hh + 1), (cx + hw + 1, cy), (cx, cy + hh + 1), (cx - hw + 1, cy)]
    d.polygon(pts_s, fill=(0, 0, 0, 100))
    # Body — lower half darker
    pts_lo = [(cx - hw, cy), (cx + hw, cy), (cx, cy + hh), ]
    d.polygon(pts_lo, fill=(int(col[0]*0.55), int(col[1]*0.55), int(col[2]*0.55), 255))
    # Body — upper half main colour
    pts_up = [(cx, cy - hh), (cx + hw, cy), (cx - hw, cy)]
    d.polygon(pts_up, fill=col + (255,))
    # Left facet slightly brighter
    pts_lf = [(cx, cy - hh), (cx - hw, cy), (cx, cy)]
    d.polygon(pts_lf, fill=(min(col[0]+30, 255), min(col[1]+30, 255), min(col[2]+30, 255), 200))
    # Specular highlight (small bright line upper-left)
    d.line([(cx - hw // 2, cy - hh // 2), (cx, cy - hh + 1)], fill=hi + (220,), width=1)

# Subtle sparkles
for sx, sy in [(20, 5), (5, 20), (35, 20), (20, 36)]:
    d.point((sx, sy), fill=(255, 255, 255, 180))
    for off in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
        d.point((sx + off[0], sy + off[1]), fill=(255, 255, 255, 80))

save_icon(img, "color")


# ═══════════════════════════════════════════════════════════════════════════════
#  SERPENT — coiled glowing snake on dark green
# ═══════════════════════════════════════════════════════════════════════════════
print("serpent launcher_icon.png")
img = new_icon()
d = ImageDraw.Draw(img)

# Background
for y in range(40):
    t = y / 39
    d.line([(0, y), (39, y)], fill=(int(4 + t * 8), int(12 + t * 16), int(4 + t * 8), 255))

# Snake body: series of 4×4 squares forming a coiling path
# S-curve: right → down → left → down → right
snake_cells = [
    (26, 3), (21, 3), (16, 3), (11, 3), (6, 3),  # top row rightward
    (6, 8), (6, 13),                                # down
    (11, 13), (16, 13), (21, 13), (26, 13), (31, 13),  # middle row rightward
    (31, 18), (31, 23),                             # down
    (26, 23), (21, 23), (16, 23), (11, 23), (6, 23),   # lower row leftward
    (6, 28), (6, 33),                               # down
    (11, 33), (16, 33), (21, 33),                   # bottom row
]
body_col = (60, 220, 70)
dark_col = (30, 150, 40)

for i, (sx, sy) in enumerate(reversed(snake_cells)):
    t = i / len(snake_cells)
    r = int(body_col[0] * (0.5 + 0.5 * t))
    g = int(body_col[1] * (0.5 + 0.5 * t))
    b = int(body_col[2] * (0.5 + 0.5 * t))
    d.rectangle([sx, sy, sx + 3, sy + 3], fill=(r, g, b, 255))
    # Scale border
    d.rectangle([sx, sy, sx + 3, sy + 3], outline=(20, 80, 20, 200), width=1)

# Head (last cell = snake cells[0] = (26,3))
hx, hy = 31, 3
d.rectangle([hx, hy, hx + 4, hy + 4], fill=(40, 200, 50, 255))
# Eyes
d.rectangle([hx + 1, hy + 1, hx + 1, hy + 1], fill=(255, 255, 80, 255))
d.rectangle([hx + 3, hy + 1, hx + 3, hy + 1], fill=(255, 255, 80, 255))
# Tongue
d.line([(hx + 4, hy + 2), (hx + 6, hy + 1)], fill=(255, 50, 50, 255), width=1)
d.line([(hx + 4, hy + 2), (hx + 6, hy + 3)], fill=(255, 50, 50, 255), width=1)

# Food — red glowing dot
d.ellipse([17, 37, 21, 39], fill=(255, 60, 60, 255))
d.ellipse([16, 36, 22, 40], fill=(255, 60, 60, 80))

save_icon(img, "serpent")
# Also save for the Serpent folder (capital S)
p2 = os.path.join(GAMES, "Serpent", "resources", "launcher_icon.png")
img.save(p2, "PNG")
print(f"  icon → Serpent/resources/launcher_icon.png")


# ═══════════════════════════════════════════════════════════════════════════════
#  MOON — lander descending to lunar surface in starry space
# ═══════════════════════════════════════════════════════════════════════════════
print("moon launcher_icon.png")
img = new_icon()
d = ImageDraw.Draw(img)

# Space background (near-black blue)
for y in range(40):
    t = y / 39
    d.line([(0, y), (39, y)], fill=(int(2 + t * 4), int(3 + t * 6), int(12 + t * 10), 255))

# Stars
for sx, sy in [(3, 4), (14, 2), (34, 6), (38, 14), (7, 18), (28, 10), (36, 28)]:
    d.point((sx, sy), fill=(255, 255, 255, 200))

# Earth (upper-right, small circle, blue+green)
ex, ey, er = 34, 5, 5
d.ellipse([ex - er, ey - er, ex + er, ey + er], fill=(30, 80, 200, 255))
d.ellipse([ex - er + 1, ey - er + 1, ex + er - 1, ey + er - 1], fill=(40, 90, 210, 255))
# Green continents (tiny blobs)
d.rectangle([ex - 2, ey - 2, ex + 1, ey + 1], fill=(60, 160, 60, 200))
d.rectangle([ex + 1, ey + 2, ex + 3, ey + 4], fill=(60, 160, 60, 180))

# Moon terrain at bottom (hills + crater)
terrain_pts = [(0, 36), (4, 33), (8, 35), (12, 31), (16, 34), (22, 31), (27, 33),
               (30, 30), (34, 33), (39, 31), (39, 39), (0, 39)]
d.polygon(terrain_pts, fill=(90, 90, 90, 255))
d.line([(0, 36), (4, 33), (8, 35), (12, 31), (16, 34), (22, 31), (27, 33),
        (30, 30), (34, 33), (39, 31)], fill=(140, 140, 140, 255), width=1)
# Crater
d.ellipse([5, 34, 13, 38], fill=(70, 70, 70, 255))
d.arc([5, 34, 13, 38], 0, 180, fill=(110, 110, 110, 200), width=1)

# Landing pad (flat, yellow marker)
d.line([(17, 31), (26, 31)], fill=(255, 220, 40, 255), width=1)
d.line([(17, 28), (17, 31)], fill=(255, 220, 40, 200), width=1)
d.line([(26, 28), (26, 31)], fill=(255, 220, 40, 200), width=1)

# Lander body (centre, descending)
lx, ly = 20, 18
# Hull
d.rectangle([lx - 4, ly, lx + 4, ly + 5], fill=(210, 220, 240, 255))
# Window
d.rectangle([lx - 2, ly + 1, lx + 2, ly + 4], fill=(60, 120, 210, 255))
d.rectangle([lx - 1, ly + 1, lx + 1, ly + 2], fill=(150, 200, 255, 200))
# Legs
d.line([(lx - 3, ly + 5), (lx - 6, ly + 8)], fill=(180, 190, 210, 255))
d.line([(lx + 3, ly + 5), (lx + 6, ly + 8)], fill=(180, 190, 210, 255))
d.line([(lx - 7, ly + 9), (lx - 4, ly + 9)], fill=(180, 190, 210, 255))
d.line([(lx + 4, ly + 9), (lx + 7, ly + 9)], fill=(180, 190, 210, 255))

# Thruster flame (orange→yellow→white)
flame_pts = [(lx - 2, ly + 5), (lx + 2, ly + 5), (lx, ly + 10)]
d.polygon(flame_pts, fill=(255, 100, 20, 220))
d.polygon([(lx - 1, ly + 5), (lx + 1, ly + 5), (lx, ly + 8)], fill=(255, 240, 60, 255))
# Glow
d.ellipse([lx - 3, ly + 4, lx + 3, ly + 11], fill=(255, 120, 0, 40))

save_icon(img, "moon")


# ═══════════════════════════════════════════════════════════════════════════════
#  BLOBS — two angry blobs facing off, explosion between them
# ═══════════════════════════════════════════════════════════════════════════════
print("blobs launcher_icon.png")
img = new_icon()
d = ImageDraw.Draw(img)

# Background gradient
for y in range(40):
    t = y / 39
    d.line([(0, y), (39, y)], fill=(int(4 + t * 10), int(14 + t * 20), int(4 + t * 10), 255))

# Terrain (bottom)
terr_pts = [(0, 34), (5, 31), (10, 33), (15, 30), (20, 32), (25, 30),
            (30, 32), (35, 30), (39, 32), (39, 39), (0, 39)]
d.polygon(terr_pts, fill=(30, 80, 25, 255))
d.line([(0, 34), (5, 31), (10, 33), (15, 30), (20, 32), (25, 30),
        (30, 32), (35, 30), (39, 32)], fill=(50, 130, 40, 255))

# Left blob — green
def draw_icon_blob(d, cx, cy, r, col, dark_col):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(0, 0, 0, 60))  # shadow
    d.ellipse([cx - r - 1, cy - r - 1, cx + r + 1, cy + r + 1], fill=col[:3] + (60,))  # glow
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=col)
    # Highlight
    d.ellipse([cx - r // 2, cy - r, cx, cy - r // 3], fill=(255, 255, 255, 60))

draw_icon_blob(d, 9, 20, 8, (55, 200, 60, 240), (30, 130, 35, 240))
draw_icon_blob(d, 31, 20, 8, (55, 80, 220, 240), (30, 50, 150, 240))

# Angry eyes — LEFT blob (facing right)
for ex, ey_off in [(7, -3), (11, -3)]:
    d.ellipse([ex - 2, 20 + ey_off - 2, ex + 2, 20 + ey_off + 2], fill=(255, 255, 255, 220))
    d.ellipse([ex, 20 + ey_off - 1, ex + 2, 20 + ey_off + 2], fill=(220, 30, 30, 255))
# Angry brows left
d.line([(5, 14), (8, 16)], fill=(0, 0, 0, 220), width=1)
d.line([(10, 16), (13, 14)], fill=(0, 0, 0, 220), width=1)

# Angry eyes — RIGHT blob (facing left)
for ex, ey_off in [(29, -3), (33, -3)]:
    d.ellipse([ex - 2, 20 + ey_off - 2, ex + 2, 20 + ey_off + 2], fill=(255, 255, 255, 220))
    d.ellipse([ex - 2, 20 + ey_off - 1, ex, 20 + ey_off + 2], fill=(220, 30, 30, 255))
# Angry brows right
d.line([(27, 14), (30, 16)], fill=(0, 0, 0, 220), width=1)
d.line([(32, 16), (35, 14)], fill=(0, 0, 0, 220), width=1)

# Bazooka barrels pointing at each other
d.line([(17, 20), (13, 20)], fill=(60, 60, 70, 255), width=2)   # left blob barrel
d.line([(23, 20), (27, 20)], fill=(60, 60, 70, 255), width=2)   # right blob barrel

# Central explosion
for r, col, a in [(7, (255,60,0), 80), (5, (255,160,0), 120), (3, (255,240,50), 180), (1, (255,255,200), 255)]:
    d.ellipse([20 - r, 18 - r, 20 + r, 18 + r], fill=col + (a,))
# Explosion rays
for ang in range(0, 360, 45):
    rad = math.radians(ang)
    ex2 = 20 + int(math.cos(rad) * 9)
    ey2 = 18 + int(math.sin(rad) * 8)
    d.line([(20, 18), (ex2, ey2)], fill=(255, 180, 0, 160), width=1)

save_icon(img, "blobs")


# ═══════════════════════════════════════════════════════════════════════════════
#  BLOCKS — colourful tetrominos stacking
# ═══════════════════════════════════════════════════════════════════════════════
print("blocks launcher_icon.png")
img = new_icon()
d = ImageDraw.Draw(img)

# Background
for y in range(40):
    t = y / 39
    d.line([(0, y), (39, y)], fill=(int(6 + t * 8), int(6 + t * 8), int(14 + t * 14), 255))

# Grid: 7 cols × 8 rows visible, cell = 5×5 px (with 1px gap)
def draw_cell(d, col, row, color):
    x = 1 + col * 5
    y = 1 + row * 5
    d.rectangle([x, y, x + 3, y + 3], fill=color)
    d.line([(x, y), (x + 3, y)], fill=(255, 255, 255, 100))   # top highlight
    d.line([(x, y), (x, y + 3)], fill=(255, 255, 255, 60))    # left highlight
    d.line([(x + 3, y + 3), (x, y + 3)], fill=(0, 0, 0, 100))  # bottom shadow
    d.line([(x + 3, y + 3), (x + 3, y)], fill=(0, 0, 0, 80))   # right shadow

CYAN   = (50, 220, 220, 255)
YELLOW = (230, 210, 40, 255)
RED    = (220, 55, 55, 255)
BLUE   = (55, 100, 220, 255)
ORANGE = (230, 130, 40, 255)
GREEN  = (55, 200, 80, 255)
PURPLE = (160, 60, 210, 255)

# Bottom 3 rows: packed (rows 5, 6, 7)
row5 = [RED, CYAN, CYAN, BLUE, ORANGE, GREEN, PURPLE]
row6 = [BLUE, RED, YELLOW, CYAN, GREEN, BLUE, ORANGE]
row7 = [ORANGE, PURPLE, RED, YELLOW, CYAN, RED, GREEN]
for col, c in enumerate(row5): draw_cell(d, col, 5, c)
for col, c in enumerate(row6): draw_cell(d, col, 6, c)
for col, c in enumerate(row7): draw_cell(d, col, 7, c)

# Row 4: partial
row4 = [None, RED, YELLOW, None, ORANGE, BLUE, None]
for col, c in enumerate(row4):
    if c: draw_cell(d, col, 4, c)

# Falling T-piece (cyan) rows 1-3 — centre columns 3,4,5
# T shape: row1=[4], row2=[3,4,5], row3=[]
draw_cell(d, 4, 1, CYAN)
draw_cell(d, 3, 2, CYAN)
draw_cell(d, 4, 2, CYAN)
draw_cell(d, 5, 2, CYAN)

# L-piece partial (orange) left side
draw_cell(d, 0, 2, ORANGE)
draw_cell(d, 0, 3, ORANGE)
draw_cell(d, 1, 3, ORANGE)

# S-piece partial (green) right side
draw_cell(d, 6, 1, GREEN)
draw_cell(d, 5, 2, GREEN)  # overlap redraws on top — fine
draw_cell(d, 6, 3, GREEN)

save_icon(img, "blocks")


# ═══════════════════════════════════════════════════════════════════════════════
#  MOON HERO  (1440 × 720)
# ═══════════════════════════════════════════════════════════════════════════════
print("\nmoon_hero.png")

W, H = 1440, 720
img = Image.new("RGBA", (W, H))
d = ImageDraw.Draw(img)

def glow(img, cx, cy, r, col, layers=6):
    for i in range(layers, 0, -1):
        alpha = int(55 * i / layers)
        rad = r + (layers - i) * 10
        lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ld = ImageDraw.Draw(lay)
        ld.ellipse([cx - rad, cy - rad, cx + rad, cy + rad], fill=col + (alpha,))
        img.alpha_composite(lay)

# ── Space background ──────────────────────────────────────────────────────────
for y in range(H):
    t = y / H
    r = int(0   + t * 5)
    g = int(0   + t * 8)
    b = int(10  + t * 18)
    d.line([(0, y), (W, y)], fill=(r, g, b, 255))

# ── Stars ─────────────────────────────────────────────────────────────────────
random.seed(42)
for _ in range(500):
    sx = random.randint(0, W)
    sy = random.randint(0, int(H * 0.65))
    sr = random.choice([1, 1, 1, 2])
    sa = random.randint(80, 255)
    d.ellipse([sx - sr, sy - sr, sx + sr, sy + sr], fill=(255, 255, 255, sa))

# ── Milky way stripe ──────────────────────────────────────────────────────────
for _ in range(600):
    sx = random.randint(W * 3 // 10, W * 8 // 10)
    sy = random.randint(0, int(H * 0.55))
    d.point((sx, sy), fill=(200, 200, 220, random.randint(20, 60)))

# ── Earth (upper right, large) ───────────────────────────────────────────────
ecx, ecy, er = 1280, 100, 140
glow(img, ecx, ecy, er, (50, 100, 220), layers=8)
lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
ld = ImageDraw.Draw(lay)
# Ocean base
ld.ellipse([ecx - er, ecy - er, ecx + er, ecy + er], fill=(30, 80, 200, 255))
ld.ellipse([ecx - er + 2, ecy - er + 2, ecx + er - 2, ecy + er - 2], fill=(40, 95, 215, 255))
# Continents
cont = [
    (ecx - 50, ecy - 40, ecx + 10,  ecy + 20,  (55, 155, 50)),
    (ecx + 20, ecy - 50, ecx + 80,  ecy + 10,  (60, 145, 55)),
    (ecx - 80, ecy + 20, ecx - 20,  ecy + 70,  (70, 160, 60)),
    (ecx + 40, ecy + 30, ecx + 100, ecy + 80,  (55, 150, 50)),
]
for (x0, y0, x1, y1, cc) in cont:
    ld.ellipse([x0, y0, x1, y1], fill=cc + (230,))
# Atmosphere halo
ld.arc([ecx - er - 8, ecy - er - 8, ecx + er + 8, ecy + er + 8],
       start=0, end=360, fill=(100, 160, 255, 80), width=8)
# Cloud streaks
ld.arc([ecx - 90, ecy - 30, ecx + 30, ecy + 60], start=20, end=80,
       fill=(255, 255, 255, 120), width=6)
ld.arc([ecx - 40, ecy - 80, ecx + 80, ecy + 10], start=160, end=230,
       fill=(255, 255, 255, 100), width=5)
img.alpha_composite(lay)

# ── Moon surface (lower 38%) ─────────────────────────────────────────────────
surf_y = int(H * 0.62)
# Terrain polygon
def moon_height(x):
    h = surf_y
    h += int(math.sin(x * 0.008) * 28)
    h += int(math.sin(x * 0.025) * 14)
    h += int(math.sin(x * 0.06 + 1.2) * 8)
    return h

# Fill terrain
for x in range(W + 1):
    hy = moon_height(x)
    d.line([(x, hy), (x, H)], fill=(72, 72, 72, 255))

# Surface highlight line
for x in range(W - 1):
    y1 = moon_height(x)
    y2 = moon_height(x + 1)
    d.line([(x, y1), (x + 1, y2)], fill=(115, 115, 115, 255), width=2)

# ── Craters ───────────────────────────────────────────────────────────────────
craters = [
    (180,  surf_y + 18,  55),
    (500,  surf_y + 12,  40),
    (820,  surf_y + 22,  70),
    (1100, surf_y + 15,  45),
    (1380, surf_y + 20,  60),
    (320,  surf_y + 40,  28),
    (680,  surf_y + 50,  22),
    (950,  surf_y + 35,  35),
]
for (cx2, cy2, cr2) in craters:
    lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ld = ImageDraw.Draw(lay)
    ld.ellipse([cx2 - cr2, cy2 - cr2 // 2, cx2 + cr2, cy2 + cr2 // 2],
               fill=(52, 52, 52, 255))
    ld.arc([cx2 - cr2, cy2 - cr2 // 2, cx2 + cr2, cy2 + cr2 // 2],
           start=0, end=180, fill=(95, 95, 95, 200), width=3)
    img.alpha_composite(lay)

# ── Landing pad ───────────────────────────────────────────────────────────────
pad_cx = W // 2
pad_y = moon_height(pad_cx) - 2
pad_hw = 90
lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
ld = ImageDraw.Draw(lay)
ld.rectangle([pad_cx - pad_hw, pad_y - 1, pad_cx + pad_hw, pad_y + 4],
             fill=(100, 100, 100, 255))
ld.rectangle([pad_cx - pad_hw, pad_y - 1, pad_cx + pad_hw, pad_y + 1],
             fill=(180, 180, 160, 220))
# Pad marker poles
for px_off in [-pad_hw, pad_hw]:
    ld.rectangle([pad_cx + px_off - 3, pad_y - 30, pad_cx + px_off + 3, pad_y],
                 fill=(180, 180, 140, 240))
    ld.ellipse([pad_cx + px_off - 5, pad_y - 36, pad_cx + px_off + 5, pad_y - 26],
               fill=(255, 50, 50, 255))
# Approach arrow
for i in range(3):
    ay = pad_y - 80 - i * 28
    ld.polygon([(pad_cx - 12, ay + 14), (pad_cx + 12, ay + 14), (pad_cx, ay)],
               fill=(255, 220, 40, int(200 - i * 60)))
img.alpha_composite(lay)

# ── Moon Lander ──────────────────────────────────────────────────────────────
lx, ly = W // 2, int(H * 0.30)

def draw_lander_hero(img, lx, ly, scale=1.0):
    s = scale
    lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ld = ImageDraw.Draw(lay)

    hw  = int(55 * s)   # hull half-width
    hh  = int(45 * s)   # hull height
    lh  = int(35 * s)   # leg height

    # Shadow on ground
    ld.ellipse([lx - hw - 10, pad_y - 4, lx + hw + 10, pad_y + 6],
               fill=(0, 0, 0, 80))

    # Main thruster nozzle
    noz_pts = [(lx - int(18*s), ly + hh),
               (lx + int(18*s), ly + hh),
               (lx + int(12*s), ly + hh + int(18*s)),
               (lx - int(12*s), ly + hh + int(18*s))]
    ld.polygon(noz_pts, fill=(140, 150, 165, 255))

    # Hull body
    hull_pts = [(lx - hw, ly + int(12*s)),
                (lx + hw, ly + int(12*s)),
                (lx + hw + int(8*s), ly + hh),
                (lx - hw - int(8*s), ly + hh)]
    ld.polygon(hull_pts, fill=(195, 210, 230, 255))

    # Hull top (dome / command module)
    ld.ellipse([lx - int(38*s), ly - int(8*s), lx + int(38*s), ly + int(28*s)],
               fill=(185, 200, 222, 255))

    # Thermal insulation stripes (foil pattern)
    for i in range(3):
        stripe_y = ly + int(18*s) + i * int(9*s)
        ld.rectangle([lx - hw, stripe_y, lx + hw, stripe_y + int(5*s)],
                     fill=(220, 180, 60, 180))

    # Cockpit windows
    for wx_off in [-int(22*s), int(22*s)]:
        wx = lx + wx_off
        wy = ly + int(5*s)
        ld.ellipse([wx - int(14*s), wy - int(12*s), wx + int(14*s), wy + int(12*s)],
                   fill=(20, 60, 130, 255))
        # Glass sheen
        ld.arc([wx - int(14*s), wy - int(12*s), wx + int(14*s), wy + int(12*s)],
               start=210, end=320, fill=(150, 200, 255, 180), width=3)
    # Center window
    ld.ellipse([lx - int(10*s), ly - int(5*s), lx + int(10*s), ly + int(10*s)],
               fill=(30, 80, 160, 255))
    ld.arc([lx - int(10*s), ly - int(5*s), lx + int(10*s), ly + int(10*s)],
           start=210, end=320, fill=(180, 220, 255, 200), width=2)

    # Antenna
    ld.line([(lx, ly - int(8*s)), (lx, ly - int(28*s))], fill=(200, 210, 220, 255), width=2)
    ld.ellipse([lx - int(5*s), ly - int(32*s), lx + int(5*s), ly - int(24*s)],
               fill=(180, 195, 215, 255))

    # Landing legs (4: 2 visible)
    leg_configs = [
        (-hw - int(4*s), -int(8*s),  -hw - int(38*s), lh + int(5*s),  -hw - int(52*s), -hw - int(20*s)),
        ( hw + int(4*s), -int(8*s),   hw + int(38*s), lh + int(5*s),   hw + int(20*s),  hw + int(52*s)),
    ]
    for (sx1, sy1, sx2, sy2, fx1, fx2) in leg_configs:
        # Main leg strut
        ld.line([(lx + sx1, ly + hh + sy1), (lx + sx2, ly + hh + sy2)],
                fill=(175, 190, 210, 255), width=int(6*s))
        # Diagonal brace
        ld.line([(lx + sx1 // 2, ly + hh + int(10*s)),
                 (lx + sx2, ly + hh + sy2)],
                fill=(175, 190, 210, 200), width=int(3*s))
        # Foot pad
        ld.rectangle([lx + fx1, ly + hh + lh - int(4*s),
                      lx + fx2, ly + hh + lh + int(6*s)],
                     fill=(160, 175, 200, 255))

    # Thruster flame
    for i, (fc, fa, fw) in enumerate([(( 255, 80,  10), 220, 30),
                                       (( 255,160,  20), 200, 20),
                                       (( 255,230,  60), 240, 12),
                                       (( 255,255, 200), 255,  6)]):
        fh = int((55 - i * 8) * s)
        ld.polygon([
            (lx - int(fw*s), ly + hh + int(18*s)),
            (lx + int(fw*s), ly + hh + int(18*s)),
            (lx,             ly + hh + int(18*s) + fh)
        ], fill=fc + (fa,))

    img.alpha_composite(lay)

glow(img, lx, ly + 80, 120, (255, 120, 20), layers=10)  # thruster glow
glow(img, lx, ly, 80, (180, 200, 230), layers=5)          # lander ambient
draw_lander_hero(img, lx, ly, scale=1.9)

# ── Telemetry readout (left side) ────────────────────────────────────────────
lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
ld = ImageDraw.Draw(lay)
panel_x = 55
ld.rounded_rectangle([panel_x - 10, 200, panel_x + 240, 440],
                      radius=10, fill=(10, 20, 35, 180), outline=(50, 100, 160, 140), width=1)
tf = get_font(22)
sf = get_font(18)
rows = [
    ("ALTITUDE",   "185 m",  (80, 200, 255)),
    ("V-SPEED",    "1.2 m/s",(80, 255, 140)),
    ("H-SPEED",    "0.3 m/s",(80, 255, 140)),
    ("FUEL",       "62 %",   (255, 210, 50)),
    ("GRAVITY",    "1.62 m/s²",(160, 180, 220)),
    ("STATUS",     "APPROACH",(255, 80, 80)),
]
for i, (label, val, vc) in enumerate(rows):
    ry = 215 + i * 36
    ld.text((panel_x, ry), label, font=sf, fill=(120, 150, 180, 200))
    ld.text((panel_x + 130, ry), val, font=tf, fill=vc + (255,))
img.alpha_composite(lay)

# ── Title text ────────────────────────────────────────────────────────────────
from PIL import ImageFont
d2 = ImageDraw.Draw(img)
tf2   = get_font(96)
sf2   = get_font(36)
sub_f = get_font(28)

title = "BITOCHI"
sub1  = "MOON LANDER"
sub2  = "Navigate the void. Land or die."

# BITOCHI
bb = d2.textbbox((0, 0), title, font=tf2)
tw = bb[2] - bb[0]
tx = (W - tw) // 2
ty = H - 160
d2.text((tx + 3, ty + 3), title, font=tf2, fill=(0, 0, 0, 180))
d2.text((tx, ty), title, font=tf2, fill=(200, 220, 245, 255))

# MOON LANDER
bb2 = d2.textbbox((0, 0), sub1, font=sf2)
sw2 = bb2[2] - bb2[0]
d2.text(((W - sw2) // 2 + 2, ty + 94 + 2), sub1, font=sf2, fill=(0, 0, 0, 160))
d2.text(((W - sw2) // 2, ty + 94), sub1, font=sf2, fill=(255, 220, 50, 255))

# Subtitle
bb3 = d2.textbbox((0, 0), sub2, font=sub_f)
sw3 = bb3[2] - bb3[0]
d2.text(((W - sw3) // 2, ty + 140), sub2, font=sub_f, fill=(150, 180, 210, 200))

save_logo(img, "moon_hero.png")

print("\nAll done.")
