#!/usr/bin/env python3
"""Generate angrypomodoro_hero.png (1440x720) - premium quality."""

import math, os, random
from PIL import Image, ImageDraw, ImageFont, ImageFilter

random.seed(42)
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

def get_thin(size):
    for path in [
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

W, H = 1440, 720
img = Image.new("RGBA", (W, H))
d = ImageDraw.Draw(img)

# === BACKGROUND: dark with angry red glow ===
for y in range(H):
    t = y / H
    r = int(18 - 8 * abs(t - 0.5))
    g = int(4)
    b = int(8 - 4 * abs(t - 0.5))
    d.line([(0, y), (W, y)], fill=(r, g, b))

# Center red glow
glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
gd = ImageDraw.Draw(glow)
for r in range(350, 0, -1):
    alpha = int(40 * (1 - r / 350))
    gd.ellipse([W//2 - r, H//2 - r, W//2 + r, H//2 + r],
               fill=(180, 20, 0, alpha))
img = Image.alpha_composite(img, glow)
d = ImageDraw.Draw(img)

# === LEFT: Big angry tomato ===
tx, ty = 360, 320
tr = 210

# Tomato body with gradient effect
for i in range(tr, 0, -1):
    t = i / tr
    rc = int(200 * t + 60 * (1 - t))
    gc = int(40 * t + 10 * (1 - t))
    bc = int(15 * t + 5 * (1 - t))
    d.ellipse([tx - i, ty - i, tx + i, ty + i], fill=(rc, gc, bc))

# Highlight (top-left shine)
for i in range(60, 0, -1):
    alpha = int(30 * (1 - i / 60))
    hx, hy = tx - 60, ty - 70
    d.ellipse([hx - i, hy - i, hx + i, hy + i], fill=(255, 100, 60, alpha))

# Leaf / stem
lw = 28
d.polygon([(tx - lw, ty - tr + 8), (tx - lw * 2 - 10, ty - tr - lw * 3),
           (tx + 4, ty - tr - 4)], fill=(40, 160, 30))
d.polygon([(tx + lw, ty - tr + 8), (tx + lw * 2 + 10, ty - tr - lw * 3),
           (tx - 4, ty - tr - 4)], fill=(55, 180, 40))
# Stem
d.rectangle([tx - 5, ty - tr - lw, tx + 5, ty - tr + 8], fill=(80, 50, 20))

# --- Angry face ---
eo = tr * 28 // 100  # eye offset
eyy = ty - tr * 8 // 100
eyr = tr * 14 // 100

# Angry eyebrows (thick, angled)
bw = 5
d.polygon([(tx - eo - eyr - 12, eyy - eyr - 22),
           (tx - eo + eyr + 4, eyy - eyr - 4),
           (tx - eo + eyr + 4, eyy - eyr + 4),
           (tx - eo - eyr - 12, eyy - eyr - 10)], fill=(60, 0, 0))
d.polygon([(tx + eo - eyr - 4, eyy - eyr - 4),
           (tx + eo + eyr + 12, eyy - eyr - 22),
           (tx + eo + eyr + 12, eyy - eyr - 10),
           (tx + eo - eyr - 4, eyy - eyr + 4)], fill=(60, 0, 0))

# Eye sockets (dark)
d.ellipse([tx - eo - eyr - 2, eyy - eyr - 2, tx - eo + eyr + 2, eyy + eyr + 2],
          fill=(30, 0, 0))
d.ellipse([tx + eo - eyr - 2, eyy - eyr - 2, tx + eo + eyr + 2, eyy + eyr + 2],
          fill=(30, 0, 0))

# Glowing red pupils
pr = eyr * 7 // 10
d.ellipse([tx - eo - pr, eyy - pr, tx - eo + pr, eyy + pr], fill=(240, 20, 0))
d.ellipse([tx + eo - pr, eyy - pr, tx + eo + pr, eyy + pr], fill=(240, 20, 0))
# Pupil highlight
d.ellipse([tx - eo - pr//3 + 4, eyy - pr//3 - 2, tx - eo + pr//3 + 4, eyy + pr//3 - 2],
          fill=(255, 120, 80))
d.ellipse([tx + eo - pr//3 + 4, eyy - pr//3 - 2, tx + eo + pr//3 + 4, eyy + pr//3 - 2],
          fill=(255, 120, 80))

# Gritted teeth mouth
mw = tr * 50 // 100
mh = tr * 20 // 100
my = ty + tr * 28 // 100
# Mouth opening
d.rounded_rectangle([tx - mw, my, tx + mw, my + mh], radius=8, fill=(30, 0, 0))
# Teeth
tw = mw * 2 // 4
for i in range(4):
    tx1 = tx - mw + 4 + i * tw
    tx2 = tx1 + tw - 6
    d.rounded_rectangle([tx1, my + 3, tx2, my + mh * 50 // 100],
                        radius=3, fill=(255, 255, 255))

# Steam puffs (rage!)
for (sx, sy, sr) in [(tx - 40, ty - tr - 50, 14), (tx - 25, ty - tr - 72, 10),
                      (tx - 15, ty - tr - 88, 7),
                      (tx + 35, ty - tr - 45, 12), (tx + 25, ty - tr - 65, 9),
                      (tx + 18, ty - tr - 80, 6)]:
    d.ellipse([sx - sr, sy - sr, sx + sr, sy + sr], fill=(255, 120, 60, 180))
    d.ellipse([sx - sr + 2, sy - sr + 2, sx + sr - 2, sy + sr - 2], fill=(255, 160, 100, 150))

# === CENTER: Timer display on dark panel ===
pcx, pcy = 720, 310
panel_r = 160

# Dark circular panel (like watch face)
d.ellipse([pcx - panel_r - 6, pcy - panel_r - 6, pcx + panel_r + 6, pcy + panel_r + 6],
          fill=(40, 8, 8))
d.ellipse([pcx - panel_r, pcy - panel_r, pcx + panel_r, pcy + panel_r],
          fill=(12, 4, 8))

# Progress arc (about 65% done)
arc_r = panel_r - 12
arc_w = 8
progress = 0.65
start_angle = -90
end_angle = start_angle + 360 * progress
# Background arc (dark)
d.arc([pcx - arc_r, pcy - arc_r, pcx + arc_r, pcy + arc_r],
      0, 360, fill=(40, 10, 10), width=arc_w)
# Progress arc (red gradient)
d.arc([pcx - arc_r, pcy - arc_r, pcx + arc_r, pcy + arc_r],
      start_angle, end_angle, fill=(220, 40, 10), width=arc_w)

# Timer text "08:45"
time_font = get_font(72)
d.text((pcx + 2, pcy - 20 + 2), "08:45", fill=(0, 0, 0), font=time_font, anchor="mm")
d.text((pcx, pcy - 20), "08:45", fill=(255, 255, 255), font=time_font, anchor="mm")

# "FOCUS" label
focus_font = get_font(24)
d.text((pcx, pcy + 35), "FOCUS", fill=(220, 50, 20), font=focus_font, anchor="mm")

# Breathing ring indicator (subtle pulsing circle)
for i in range(3):
    ring_r = arc_r + 18 + i * 3
    alpha = 60 - i * 18
    d.arc([pcx - ring_r, pcy - ring_r, pcx + ring_r, pcy + ring_r],
          0, 360, fill=(220, 40, 10, alpha), width=1)

# Small labels around the arc
tiny_font = get_thin(14)
d.text((pcx, pcy - arc_r - 18), "25:00", fill=(100, 30, 20), font=tiny_font, anchor="mm")

# === RIGHT: Calm break tomato (smaller, yellow-green) ===
rx, ry = 1100, 320
rr = 140

# Body gradient
for i in range(rr, 0, -1):
    t = i / rr
    rc = int(240 * t + 160 * (1 - t))
    gc = int(190 * t + 130 * (1 - t))
    bc = int(30 * t + 10 * (1 - t))
    d.ellipse([rx - i, ry - i, rx + i, ry + i], fill=(rc, gc, bc))

# Highlight
for i in range(40, 0, -1):
    alpha = int(25 * (1 - i / 40))
    d.ellipse([rx - 40 - i, ry - 50 - i, rx - 40 + i, ry - 50 + i],
              fill=(255, 240, 100, alpha))

# Leaf
lw2 = 18
d.polygon([(rx - lw2, ry - rr + 5), (rx - lw2 * 2 - 6, ry - rr - lw2 * 2 - 4),
           (rx + 3, ry - rr - 2)], fill=(50, 170, 40))
d.polygon([(rx + lw2, ry - rr + 5), (rx + lw2 * 2 + 6, ry - rr - lw2 * 2 - 4),
           (rx - 3, ry - rr - 2)], fill=(60, 185, 50))
d.rectangle([rx - 4, ry - rr - lw2 + 4, rx + 4, ry - rr + 6], fill=(80, 50, 20))

# Calm face - closed eyes (relaxed), small smile
ceo = rr * 28 // 100
ceyy = ry - rr * 6 // 100
ceyr = rr * 10 // 100

# Closed eyes (arcs)
d.arc([rx - ceo - ceyr - 4, ceyy - 4, rx - ceo + ceyr + 4, ceyy + ceyr + 8],
      0, 180, fill=(60, 40, 0), width=3)
d.arc([rx + ceo - ceyr - 4, ceyy - 4, rx + ceo + ceyr + 4, ceyy + ceyr + 8],
      0, 180, fill=(60, 40, 0), width=3)

# Gentle smile
smw = rr * 22 // 100
smy = ry + rr * 24 // 100
d.arc([rx - smw, smy - smw // 2, rx + smw, smy + smw // 2],
      10, 170, fill=(120, 70, 0), width=3)

# "BREAK" label under calm tomato
break_font = get_thin(22)
d.text((rx, ry + rr + 28), "BREAK", fill=(180, 150, 40), font=break_font, anchor="mm")

# "FOCUS" label under angry tomato
d.text((tx, ty + tr + 28), "FOCUS", fill=(200, 50, 20), font=break_font, anchor="mm")

# Arrow between them
for phase_label, ax, ay, arrow_dir in [(">>", 560, 280, 1), ("<<", 880, 360, -1)]:
    arr_c = (180, 40, 10) if arrow_dir > 0 else (180, 150, 40)
    d.line([(ax, ay), (ax + 60 * arrow_dir, ay)], fill=arr_c, width=3)
    if arrow_dir > 0:
        d.polygon([(ax + 55, ay - 8), (ax + 70, ay), (ax + 55, ay + 8)], fill=arr_c)
    else:
        d.polygon([(ax - 55, ay - 8), (ax - 70, ay), (ax - 55, ay + 8)], fill=arr_c)

# === BOTTOM: Title ===
d.rectangle([0, H - 120, W, H], fill=(10, 4, 8))
d.line([(0, H - 120), (W, H - 120)], fill=(200, 40, 10), width=2)

title_font = get_font(56)
sub_font = get_thin(22)

# Shadow
d.text((W // 2 + 2, H - 82), "ANGRY POMODORO", fill=(0, 0, 0), font=title_font, anchor="mm")
d.text((W // 2, H - 84), "ANGRY POMODORO", fill=(255, 255, 255), font=title_font, anchor="mm")

d.text((W // 2, H - 38), "Stay focused. Stay furious.", fill=(200, 60, 30), font=sub_font, anchor="mm")

# Clock presets
preset_font = get_thin(16)
d.text((W // 2, H - 12), "10 min  ·  25 min  ·  45 min", fill=(80, 40, 30), font=preset_font, anchor="mm")

# === Vignette ===
vig = Image.new("RGBA", (W, H), (0, 0, 0, 0))
vd = ImageDraw.Draw(vig)
for i in range(140):
    alpha = int(100 * (1 - i / 140))
    vd.rectangle([i, i, W - i, H - i], outline=(0, 0, 0, alpha))
img = Image.alpha_composite(img, vig)

out = img.convert("RGB")
save(out, os.path.join(BASE, "angrypomodoro", "angrypomodoro_hero.png"))
save(out, os.path.join(BASE, "angrypomodoro_hero.png"))
print("Done!")
