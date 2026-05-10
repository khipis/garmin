#!/usr/bin/env python3
"""
Generate edgesurvivor_hero.png (1440×720) — store hero image.

Shows a dramatic top-down gameplay snapshot of the circular arena:
  • Player (white glowing dot) on the edge with a motion trail
  • Rotating laser beam from the centre
  • Arc wall (partial ring) with a gap the player navigated through
  • Blue expanding ring with gap
  • Radial bullets flying outward
  • Neon edge ring + depth rings

Title "EDGE SURVIVOR" + short tagline on the left.
"""
from PIL import Image, ImageDraw, ImageFont
import math, random, os

W, H = 1440, 720
OUT  = os.path.join(os.path.dirname(__file__), "edgesurvivor_hero.png")
random.seed(7)

img  = Image.new("RGB", (W, H), (4, 4, 14))
draw = ImageDraw.Draw(img)

# ── helpers ───────────────────────────────────────────────────────────────────
def font(size, bold=True):
    candidates = [
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/Arial Bold.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
    ]
    for p in candidates:
        try: return ImageFont.truetype(p, size)
        except: pass
    return ImageFont.load_default()

def polar(cx, cy, r, deg):
    a = math.radians(deg)
    return (cx + math.cos(a) * r, cy + math.sin(a) * r)

def glowing_circle(d, cx, cy, r, color, layers=6, width=2):
    for i in range(layers, 0, -1):
        alpha = i / layers
        gc = tuple(int(c * alpha * 0.6) for c in color)
        ri = r + (layers - i + 1) * 3
        d.ellipse([cx-ri, cy-ri, cx+ri, cy+ri], outline=gc, width=width)
    d.ellipse([cx-r, cy-r, cx+r, cy+r], outline=color, width=width)

def glow_line(d, p1, p2, color, width=3, glow_layers=4):
    for i in range(glow_layers, 0, -1):
        gc = tuple(int(c * (i / glow_layers) * 0.5) for c in color)
        d.line([p1, p2], fill=gc, width=width + (glow_layers - i) * 4)
    d.line([p1, p2], fill=color, width=width)

def glow_dot(d, cx, cy, r, color, layers=5):
    for i in range(layers, 0, -1):
        alpha = (i / layers) ** 1.5
        gc = tuple(int(c * alpha) for c in color)
        ri = int(r * (1 + (layers - i) * 0.6))
        d.ellipse([cx-ri, cy-ri, cx+ri, cy+ri], fill=gc)
    d.ellipse([cx-r, cy-r, cx+r, cy+r], fill=color)

# ── star field ────────────────────────────────────────────────────────────────
for _ in range(280):
    sx, sy = random.randint(0, W), random.randint(0, H)
    b = random.randint(12, 55)
    draw.rectangle([sx, sy, sx+1, sy+1], fill=(b, b, b + 15))

# ── arena (right-centre) ──────────────────────────────────────────────────────
CX, CY = 1010, 368
ER     = 272        # edge radius

# deep-space radial gradient background for arena
for gr in range(ER + 40, 0, -6):
    t  = gr / (ER + 40)
    gc = (int(4 + 12 * (1-t)), int(4 + 18 * (1-t)), int(14 + 40 * (1-t)))
    draw.ellipse([CX-gr, CY-gr, CX+gr, CY+gr], fill=gc)

# subtle depth rings
for frac in [0.33, 0.55, 0.75]:
    r = int(ER * frac)
    draw.ellipse([CX-r, CY-r, CX+r, CY+r], outline=(14, 20, 50), width=1)

# ── centre core glow ──────────────────────────────────────────────────────────
for cr in range(26, 0, -2):
    t  = cr / 26
    gc = (int(80 * t), int(20 * t), int(160 * t))
    draw.ellipse([CX-cr, CY-cr, CX+cr, CY+cr], fill=gc)
draw.ellipse([CX-5, CY-5, CX+5, CY+5], fill=(200, 100, 255))

# ── spinning laser (from centre, yellow-orange) ───────────────────────────────
LASER_ANG = 38
lx, ly = polar(CX, CY, ER + 10, LASER_ANG)
glow_line(draw, (CX, CY), (int(lx), int(ly)), (255, 200, 0), width=3, glow_layers=5)
# secondary laser arm (opposite-ish, dimmer)
lx2, ly2 = polar(CX, CY, ER * 0.7, LASER_ANG + 180)
glow_line(draw, (CX, CY), (int(lx2), int(ly2)), (140, 90, 0), width=2, glow_layers=3)

# ── arc wall (~65% of edge, gap at top where player is) ──────────────────────
# Gap centred around 270° (top), ±40° wide
ARC_R    = int(ER * 0.70)
GAP_CENTRE = 270
GAP_HALF   = 42
for deg in range(0, 360, 3):
    diff = abs(deg - GAP_CENTRE)
    if diff > 180: diff = 360 - diff
    if diff >= GAP_HALF:
        ax, ay = polar(CX, CY, ARC_R, deg)
        # core red dot
        draw.ellipse([ax-5, ay-5, ax+5, ay+5], fill=(210, 25, 25))
        # glow
        draw.ellipse([ax-8, ay-8, ax+8, ay+8], fill=(90, 5, 5))

# ── blue expanding ring (gap at bottom-right) ──────────────────────────────────
RING_R    = int(ER * 0.44)
RING_GAP  = 110   # gap centre deg
RING_GHALF = 36
for deg in range(0, 360, 4):
    diff = abs(deg - RING_GAP)
    if diff > 180: diff = 360 - diff
    if diff >= RING_GHALF:
        rx, ry = polar(CX, CY, RING_R, deg)
        draw.ellipse([rx-5, ry-5, rx+5, ry+5], fill=(20, 100, 240))
        draw.ellipse([rx-8, ry-8, rx+8, ry+8], fill=(5, 25, 70))

# small "safe zone" glow at ring gap
gzx, gzy = polar(CX, CY, RING_R, RING_GAP)
for gr in range(22, 0, -3):
    alpha = gr / 22
    gc = (int(0 * alpha), int(200 * alpha), int(60 * alpha))
    draw.ellipse([gzx-gr, gzy-gr, gzx+gr, gzy+gr], fill=gc)

# ── radial bullets (red, flying outward from centre) ──────────────────────────
BULLETS = [(130, 0.52), (195, 0.68), (315, 0.81), (55, 0.39), (160, 0.88)]
for ang_d, frac in BULLETS:
    bx, by = polar(CX, CY, ER * frac, ang_d)
    # tail (motion blur toward centre)
    tail_x, tail_y = polar(CX, CY, ER * frac * 0.72, ang_d)
    draw.line([(int(tail_x), int(tail_y)), (int(bx), int(by))],
              fill=(120, 10, 10), width=3)
    glow_dot(draw, int(bx), int(by), 8, (255, 55, 20), layers=4)

# ── player trail + dot ────────────────────────────────────────────────────────
PLAYER_ANG = 270   # top (12 o'clock)
TRAIL_STEPS = 7
for i, trail_ang in enumerate([282, 279, 276, 274, 272, 271, 270]):
    tx, ty = polar(CX, CY, ER, trail_ang)
    r_t = max(2, 8 - i)
    alpha = (TRAIL_STEPS - i) / TRAIL_STEPS
    tc = (int(60 * alpha), int(100 * alpha), int(220 * alpha))
    draw.ellipse([tx-r_t, ty-r_t, tx+r_t, ty+r_t], fill=tc)

px, py = polar(CX, CY, ER, PLAYER_ANG)
px, py = int(px), int(py)
# outer glow
for gr in range(20, 0, -3):
    alpha = (gr / 20) ** 2
    gc = (int(80 * alpha), int(130 * alpha), int(255 * alpha))
    draw.ellipse([px-gr, py-gr, px+gr, py+gr], fill=gc)
draw.ellipse([px-10, py-10, px+10, py+10], fill=(230, 240, 255))
draw.ellipse([px-5,  py-5,  px+5,  py+5],  fill=(255, 255, 255))

# ── neon edge ring (main) ─────────────────────────────────────────────────────
glowing_circle(draw, CX, CY, ER, (30, 60, 200), layers=8, width=3)

# ── title + text (left side) ──────────────────────────────────────────────────
LX = 68    # left text origin x

# "EDGE" big neon
TITLE1_Y = 100
draw.text((LX, TITLE1_Y), "EDGE", font=font(148), fill=(20, 80, 220))
# neon glow duplicate (blurred by layering)
for off in [(3,3),(2,2),(1,1),(-1,-1)]:
    draw.text((LX+off[0], TITLE1_Y+off[1]), "EDGE",
              font=font(148), fill=(10, 40, 100))
draw.text((LX, TITLE1_Y), "EDGE", font=font(148), fill=(80, 140, 255))

# "SURVIVOR" bold white
TITLE2_Y = TITLE1_Y + 160
draw.text((LX, TITLE2_Y), "SURVIVOR", font=font(98), fill=(220, 228, 255))

# accent line
draw.rectangle([LX, TITLE2_Y + 108, LX + 530, TITLE2_Y + 114], fill=(30, 70, 220))
draw.rectangle([LX, TITLE2_Y + 116, LX + 220, TITLE2_Y + 120], fill=(200, 40, 40))
draw.rectangle([LX + 230, TITLE2_Y + 116, LX + 380, TITLE2_Y + 120], fill=(255, 190, 0))
draw.rectangle([LX + 390, TITLE2_Y + 116, LX + 530, TITLE2_Y + 120], fill=(20, 100, 240))

# tagline
draw.text((LX, TITLE2_Y + 136), "Stay on the edge. Dodge everything.",
          font=font(32), fill=(110, 140, 210))

# feature bullets
FEATURES = [
    ("●  Radial bullets",    (220, 50, 50)),
    ("●  Rotating laser",    (220, 180, 0)),
    ("●  Arc walls",         (200, 40, 40)),
    ("●  Expanding rings",   (30, 110, 240)),
    ("●  Dash ability",      (100, 160, 255)),
]
fy = TITLE2_Y + 196
for (txt, col) in FEATURES:
    draw.text((LX + 6, fy), txt, font=font(28), fill=col)
    fy += 42

# ── developer tag (bottom-left) ───────────────────────────────────────────────
draw.text((LX, H - 36), "BITOCHI  •  Garmin Connect IQ",
          font=font(22), fill=(44, 55, 100))

img.save(OUT)
print(f"Saved → {OUT}")
