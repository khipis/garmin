#!/usr/bin/env python3
"""
Generate launcher_icon.png (40×40 RGBA) and hero images (1440×720 RGB)
for: timer, intervalbeeper, meetingescape, dungeon
"""
import math, os, random
from PIL import Image, ImageDraw, ImageFont

random.seed(99)

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
            return ImageFont.truetype(path, size)
        except:
            pass
    return ImageFont.load_default()


# ═══════════════════════════════════════════════════════════════════════════════
#  TIMER (Sparing Timer) — boxing bell / fight timer
#  Red-green split with bold clock hands
# ═══════════════════════════════════════════════════════════════════════════════
print("timer launcher_icon.png")
img = new_icon()
d = ImageDraw.Draw(img)

# Split background: green top-left, red bottom-right
for y in range(40):
    for x in range(40):
        if x + y < 40:
            d.point((x, y), fill=(0, 140, 0, 255))
        else:
            d.point((x, y), fill=(180, 0, 0, 255))

# Dark circle background for clock face
cx, cy, cr = 20, 20, 14
d.ellipse([cx-cr-1, cy-cr-1, cx+cr+1, cy+cr+1], fill=(0, 0, 0, 200))
d.ellipse([cx-cr, cy-cr, cx+cr, cy+cr], fill=(20, 20, 30, 255))
d.ellipse([cx-cr+1, cy-cr+1, cx+cr-1, cy+cr-1], fill=(15, 15, 25, 255))

# Clock face ring
d.arc([cx-cr, cy-cr, cx+cr, cy+cr], 0, 360, fill=(200, 200, 200, 255), width=2)

# Hour markers (12 dots)
for i in range(12):
    a = math.radians(i * 30 - 90)
    mx = cx + int(math.cos(a) * (cr - 3))
    my = cy + int(math.sin(a) * (cr - 3))
    d.point((mx, my), fill=(255, 255, 255, 200))

# Clock hands: minute at ~2 o'clock, hour at ~10
# Minute hand (long, white)
ma = math.radians(60 - 90)
d.line([(cx, cy), (cx + int(math.cos(ma)*11), cy + int(math.sin(ma)*11))],
       fill=(255, 255, 255, 255), width=1)
# Hour hand (short, white)
ha = math.radians(300 - 90)
d.line([(cx, cy), (cx + int(math.cos(ha)*7), cy + int(math.sin(ha)*7))],
       fill=(255, 255, 255, 230), width=2)

# Center dot
d.ellipse([cx-1, cy-1, cx+1, cy+1], fill=(255, 80, 80, 255))

# Boxing glove hint (top-right corner)
d.ellipse([30, 2, 38, 10], fill=(220, 50, 50, 220))
d.ellipse([31, 3, 37, 8], fill=(240, 80, 70, 200))

save_icon(img, "timer")


# ═══════════════════════════════════════════════════════════════════════════════
#  INTERVAL BEEPER — minimalist pulse/wave on black
# ═══════════════════════════════════════════════════════════════════════════════
print("intervalbeeper launcher_icon.png")
img = new_icon()
d = ImageDraw.Draw(img)

# Pure black background
d.rectangle([0, 0, 39, 39], fill=(0, 0, 0, 255))

# Sound wave / pulse rings emanating from center-left
cx, cy = 12, 20

# Pulse arcs (white, fading outward)
for i, (r, alpha) in enumerate([(6, 220), (11, 160), (16, 100), (22, 50)]):
    d.arc([cx-r, cy-r, cx+r, cy+r], -60, 60, fill=(255, 255, 255, alpha), width=2)

# Central vibration dot
d.ellipse([cx-3, cy-3, cx+3, cy+3], fill=(255, 255, 255, 255))
d.ellipse([cx-2, cy-2, cx+2, cy+2], fill=(200, 200, 200, 255))

# Small stopwatch at top-right
sw_cx, sw_cy = 32, 10
d.ellipse([sw_cx-5, sw_cy-5, sw_cx+5, sw_cy+5], fill=(30, 30, 30, 255))
d.arc([sw_cx-5, sw_cy-5, sw_cx+5, sw_cy+5], 0, 360, fill=(150, 150, 150, 200), width=1)
# Stopwatch hand
d.line([(sw_cx, sw_cy), (sw_cx+2, sw_cy-3)], fill=(255, 255, 255, 200), width=1)
# Top button
d.rectangle([sw_cx-1, sw_cy-7, sw_cx+1, sw_cy-5], fill=(150, 150, 150, 200))

# "HIIT" text hint at bottom
d.rectangle([8, 33, 32, 38], fill=(30, 30, 30, 255))
d.line([(8, 33), (32, 33)], fill=(100, 100, 100, 150))
# Horizontal bars (like equalizer)
for bx in range(10, 31, 5):
    bh = random.randint(1, 4)
    d.rectangle([bx, 37-bh, bx+3, 37], fill=(255, 255, 255, 180))

save_icon(img, "intervalbeeper")


# ═══════════════════════════════════════════════════════════════════════════════
#  MEETING ESCAPE — door/exit icon, dark and discreet
# ═══════════════════════════════════════════════════════════════════════════════
print("meetingescape launcher_icon.png")
img = new_icon()
d = ImageDraw.Draw(img)

# Very dark background
for y in range(40):
    t = y / 39
    d.line([(0, y), (39, y)], fill=(int(8+t*4), int(8+t*4), int(12+t*6), 255))

# Door frame (right side, slightly ajar)
door_l, door_t, door_r, door_b = 14, 4, 34, 36
# Wall
d.rectangle([door_l-4, door_t-2, door_l, door_b+2], fill=(40, 40, 50, 255))
# Door (angled to show it's opening)
d.polygon([(door_l, door_t), (door_r-2, door_t+2), (door_r-2, door_b-2), (door_l, door_b)],
          fill=(50, 55, 65, 255))
# Door edge highlight (the gap where light comes through)
d.line([(door_r-2, door_t+2), (door_r-2, door_b-2)], fill=(220, 200, 120, 200), width=2)
# Light spill from door gap
for i in range(5):
    alpha = 60 - i * 10
    d.line([(door_r-1+i, door_t+4+i*2), (door_r-1+i, door_b-4-i*2)],
           fill=(255, 240, 180, max(alpha, 10)))

# Door handle
d.ellipse([door_l+4, 18, door_l+7, 22], fill=(180, 160, 80, 255))

# Running person silhouette (left side, heading toward door)
px, py = 8, 18
# Head
d.ellipse([px-2, py-6, px+2, py-2], fill=(200, 200, 200, 230))
# Body
d.line([(px, py-2), (px, py+4)], fill=(200, 200, 200, 220), width=2)
# Legs (running pose)
d.line([(px, py+4), (px-3, py+9)], fill=(200, 200, 200, 200), width=1)
d.line([(px, py+4), (px+3, py+9)], fill=(200, 200, 200, 200), width=1)
# Arms
d.line([(px, py), (px+3, py+3)], fill=(200, 200, 200, 180), width=1)
d.line([(px, py), (px-3, py-1)], fill=(200, 200, 200, 180), width=1)

# Arrow pointing right (toward door)
for i in range(3):
    ax = px + 4 + i
    d.point((ax, py-1), fill=(255, 255, 255, 120-i*30))
    d.point((ax, py), fill=(255, 255, 255, 150-i*30))
    d.point((ax, py+1), fill=(255, 255, 255, 120-i*30))

save_icon(img, "meetingescape")


# ═══════════════════════════════════════════════════════════════════════════════
#  DUNGEON — dark RPG dungeon entrance, torch, sword
# ═══════════════════════════════════════════════════════════════════════════════
print("dungeon launcher_icon.png")
img = new_icon()
d = ImageDraw.Draw(img)

# Stone wall background
for y in range(40):
    t = y / 39
    r = int(25 + t * 10 + random.randint(-3, 3))
    g = int(22 + t * 8  + random.randint(-3, 3))
    b = int(18 + t * 6  + random.randint(-3, 3))
    d.line([(0, y), (39, y)], fill=(r, g, b, 255))

# Stone brick pattern
for by in range(0, 40, 8):
    d.line([(0, by), (39, by)], fill=(15, 12, 10, 180))
    offset = 10 if (by // 8) % 2 == 0 else 0
    for bx in range(offset, 40, 20):
        d.line([(bx, by), (bx, by+7)], fill=(15, 12, 10, 150))

# Dark archway (dungeon entrance)
arch_cx, arch_w, arch_top, arch_bot = 20, 11, 8, 38
d.rectangle([arch_cx-arch_w, arch_top+arch_w, arch_cx+arch_w, arch_bot],
            fill=(5, 3, 8, 255))
d.pieslice([arch_cx-arch_w, arch_top, arch_cx+arch_w, arch_top+arch_w*2],
           180, 360, fill=(5, 3, 8, 255))
# Arch stone border
d.arc([arch_cx-arch_w, arch_top, arch_cx+arch_w, arch_top+arch_w*2],
      180, 360, fill=(60, 55, 45, 255), width=2)
d.line([(arch_cx-arch_w, arch_top+arch_w), (arch_cx-arch_w, arch_bot)],
       fill=(60, 55, 45, 255), width=2)
d.line([(arch_cx+arch_w, arch_top+arch_w), (arch_cx+arch_w, arch_bot)],
       fill=(60, 55, 45, 255), width=2)

# Left torch
tx, ty = 6, 12
d.rectangle([tx-1, ty, tx+1, ty+10], fill=(80, 50, 20, 255))
# Flame
d.polygon([(tx-2, ty), (tx+2, ty), (tx, ty-5)], fill=(255, 160, 30, 255))
d.polygon([(tx-1, ty-1), (tx+1, ty-1), (tx, ty-4)], fill=(255, 230, 60, 255))
# Glow
for gr in range(5, 0, -1):
    d.ellipse([tx-gr*2, ty-gr*2-2, tx+gr*2, ty+gr*2-2],
              fill=(255, 120, 20, int(20*gr/5)))

# Right torch
tx2 = 34
d.rectangle([tx2-1, ty, tx2+1, ty+10], fill=(80, 50, 20, 255))
d.polygon([(tx2-2, ty), (tx2+2, ty), (tx2, ty-5)], fill=(255, 160, 30, 255))
d.polygon([(tx2-1, ty-1), (tx2+1, ty-1), (tx2, ty-4)], fill=(255, 230, 60, 255))
for gr in range(5, 0, -1):
    d.ellipse([tx2-gr*2, ty-gr*2-2, tx2+gr*2, ty+gr*2-2],
              fill=(255, 120, 20, int(20*gr/5)))

# Skull in archway darkness
d.ellipse([17, 26, 23, 32], fill=(60, 55, 50, 200))
d.point((18, 28), fill=(200, 30, 30, 200))  # left eye
d.point((22, 28), fill=(200, 30, 30, 200))  # right eye

save_icon(img, "dungeon")


# ═══════════════════════════════════════════════════════════════════════════════
#  HERO IMAGES (1440×720) — new apps only
# ═══════════════════════════════════════════════════════════════════════════════
W, H = 1440, 720

def draw_hero_bg_gradient(d, top_col, bot_col):
    for y in range(H):
        t = y / H
        r = int(top_col[0] + (bot_col[0] - top_col[0]) * t)
        g = int(top_col[1] + (bot_col[1] - top_col[1]) * t)
        b = int(top_col[2] + (bot_col[2] - top_col[2]) * t)
        d.line([(0, y), (W, y)], fill=(r, g, b, 255))

def draw_title(d, title, subtitle, tagline, title_col, sub_col, tag_col):
    tf = get_font(96)
    sf = get_font(42)
    tgf = get_font(28)
    bb = d.textbbox((0,0), title, font=tf)
    tw = bb[2]-bb[0]
    tx = (W-tw)//2; ty = H-170
    d.text((tx+3, ty+3), title, font=tf, fill=(0,0,0,180))
    d.text((tx, ty), title, font=tf, fill=title_col+(255,))
    bb2 = d.textbbox((0,0), subtitle, font=sf)
    sw = bb2[2]-bb2[0]
    d.text(((W-sw)//2+2, ty+98), subtitle, font=sf, fill=(0,0,0,150))
    d.text(((W-sw)//2, ty+96), subtitle, font=sf, fill=sub_col+(255,))
    bb3 = d.textbbox((0,0), tagline, font=tgf)
    d.text(((W-bb3[2]+bb3[0])//2, ty+148), tagline, font=tgf, fill=tag_col+(200,))


# ── TIMER HERO ──────────────────────────────────────────────────────────────
print("\ntimer_hero.png")
img = Image.new("RGBA", (W, H))
d = ImageDraw.Draw(img)

# Split diagonal: green top-left → red bottom-right
for y in range(H):
    for x in range(0, W, 4):
        diag = x / W + y / H
        if diag < 1.0:
            t = diag
            r = int(0 + t * 60)
            g = int(120 + (1.0-t) * 80)
            b = int(0 + t * 10)
        else:
            t = diag - 1.0
            r = int(160 + t * 60)
            g = int(20 - t * 15)
            b = int(10 - t * 5)
        d.rectangle([x, y, x+3, y], fill=(max(0,min(r,255)), max(0,min(g,255)), max(0,min(b,255)), 255))

# Large clock face center
ccx, ccy, ccr = W//2, H//2-60, 200
# Glow
for i in range(8, 0, -1):
    d.ellipse([ccx-ccr-i*15, ccy-ccr-i*15, ccx+ccr+i*15, ccy+ccr+i*15],
              fill=(0, 0, 0, int(30*i/8)))
d.ellipse([ccx-ccr, ccy-ccr, ccx+ccr, ccy+ccr], fill=(15, 15, 25, 250))
d.arc([ccx-ccr, ccy-ccr, ccx+ccr, ccy+ccr], 0, 360, fill=(200, 200, 200, 255), width=6)

# Hour markers
for i in range(12):
    a = math.radians(i*30 - 90)
    for t in range(15, 25):
        mx = ccx + int(math.cos(a) * (ccr - t))
        my = ccy + int(math.sin(a) * (ccr - t))
        d.ellipse([mx-3, my-3, mx+3, my+3], fill=(255, 255, 255, 200))

# Clock hands
ma = math.radians(60-90)
d.line([(ccx, ccy), (ccx+int(math.cos(ma)*160), ccy+int(math.sin(ma)*160))],
       fill=(255, 255, 255, 255), width=6)
ha = math.radians(300-90)
d.line([(ccx, ccy), (ccx+int(math.cos(ha)*110), ccy+int(math.sin(ha)*110))],
       fill=(255, 255, 255, 230), width=10)
d.ellipse([ccx-12, ccy-12, ccx+12, ccy+12], fill=(255, 80, 80, 255))

# Boxing gloves on sides
for gx, gy, flip in [(200, 300, 1), (W-200, 300, -1)]:
    d.ellipse([gx-60, gy-50, gx+60, gy+50], fill=(200, 40, 40, 220))
    d.ellipse([gx-50, gy-40, gx+50, gy+35], fill=(220, 60, 50, 220))
    d.ellipse([gx-30, gy-25, gx+30, gy+20], fill=(240, 80, 60, 180))

draw_title(d, "BITOCHI", "SPARING TIMER", "BJJ \u2022 Boxing \u2022 MMA",
           (230, 230, 240), (255, 80, 80), (180, 200, 180))
save_logo(img, "timer_hero.png")


# ── INTERVAL BEEPER HERO ────────────────────────────────────────────────────
print("\nintervalbeeper_hero.png")
img = Image.new("RGBA", (W, H))
d = ImageDraw.Draw(img)

# Pure black bg
d.rectangle([0, 0, W, H], fill=(0, 0, 0, 255))

# Pulse wave across center
wave_y = H // 2 - 60
for x in range(W):
    # Flat line with sharp spikes at intervals
    phase = (x - W//4) / 120.0
    if abs(phase - round(phase)) < 0.08:
        spike = 120
    elif abs(phase - round(phase)) < 0.15:
        spike = 60
    else:
        spike = 0
    spike_dir = 1 if int(round(phase)) % 2 == 0 else -1
    y1 = wave_y - spike * spike_dir
    y2 = wave_y
    if spike > 0:
        d.line([(x, y2), (x, y1)], fill=(255, 255, 255, 255), width=3)
    else:
        d.rectangle([x, wave_y-1, x, wave_y+1], fill=(60, 60, 60, 255))

# Sound wave arcs from center
arc_cx = W // 2
for i, (r, alpha) in enumerate([(80, 200), (140, 140), (200, 80), (270, 40)]):
    d.arc([arc_cx-r, wave_y-r, arc_cx+r, wave_y+r], -50, 50,
          fill=(255, 255, 255, alpha), width=4)

# Stopwatch icon top-right
sw_cx, sw_cy, sw_r = W-200, 120, 70
d.ellipse([sw_cx-sw_r, sw_cy-sw_r, sw_cx+sw_r, sw_cy+sw_r], fill=(20, 20, 20, 255))
d.arc([sw_cx-sw_r, sw_cy-sw_r, sw_cx+sw_r, sw_cy+sw_r], 0, 360,
      fill=(150, 150, 150, 200), width=3)
d.line([(sw_cx, sw_cy), (sw_cx+30, sw_cy-40)], fill=(255, 255, 255, 220), width=4)
d.rectangle([sw_cx-8, sw_cy-sw_r-20, sw_cx+8, sw_cy-sw_r], fill=(150, 150, 150, 200))

draw_title(d, "BITOCHI", "INTERVAL BEEPER", "Train by feel, not by sight.",
           (255, 255, 255), (200, 200, 200), (100, 100, 100))
save_logo(img, "intervalbeeper_hero.png")


# ── MEETING ESCAPE HERO ─────────────────────────────────────────────────────
print("\nmeetingescape_hero.png")
img = Image.new("RGBA", (W, H))
d = ImageDraw.Draw(img)

# Dark office gradient
draw_hero_bg_gradient(d, (12, 12, 18), (6, 6, 10))

# Office door (large, center-right, slightly ajar with light)
door_l, door_t = W//2 - 80, 40
door_w, door_h = 320, 500
# Wall
d.rectangle([0, 0, door_l-20, H], fill=(25, 25, 35, 255))
d.rectangle([door_l+door_w+20, 0, W, H], fill=(25, 25, 35, 255))
# Door
d.rectangle([door_l, door_t, door_l+door_w, door_t+door_h], fill=(45, 48, 58, 255))
# Door panels
for py in [door_t+40, door_t+200, door_t+360]:
    d.rectangle([door_l+30, py, door_l+door_w-30, py+80], fill=(38, 40, 50, 255))
    d.rectangle([door_l+30, py, door_l+door_w-30, py+80], outline=(55, 58, 68, 200))
# Handle
d.ellipse([door_l+door_w-60, door_t+240, door_l+door_w-40, door_t+270],
          fill=(180, 160, 80, 255))

# Light beam from gap (right edge of door)
gap_x = door_l + door_w
for i in range(40):
    alpha = 80 - i * 2
    d.line([(gap_x+i, door_t+20+i), (gap_x+i, door_t+door_h-20-i)],
           fill=(255, 240, 180, max(alpha, 2)))

# Running figure silhouette
fx, fy = door_l - 120, door_t + 180
# Head
d.ellipse([fx-20, fy-50, fx+20, fy-10], fill=(180, 180, 180, 220))
# Body
d.rectangle([fx-15, fy-10, fx+15, fy+60], fill=(180, 180, 180, 200))
# Legs (running)
d.line([(fx-5, fy+60), (fx-30, fy+120)], fill=(180, 180, 180, 180), width=8)
d.line([(fx+5, fy+60), (fx+30, fy+120)], fill=(180, 180, 180, 180), width=8)
# Arms
d.line([(fx-10, fy+5), (fx+25, fy+30)], fill=(180, 180, 180, 160), width=6)
d.line([(fx+10, fy+5), (fx-25, fy-15)], fill=(180, 180, 180, 160), width=6)

# EXIT sign glow above door
d.rectangle([door_l+80, door_t-50, door_l+door_w-80, door_t-10], fill=(20, 80, 20, 200))
ef = get_font(32)
bb = d.textbbox((0,0), "EXIT", font=ef)
ew = bb[2]-bb[0]
d.text((door_l + door_w//2 - ew//2, door_t-48), "EXIT", font=ef, fill=(80, 255, 80, 255))

draw_title(d, "BITOCHI", "MEETING ESCAPE", "Your discreet exit strategy.",
           (200, 200, 210), (140, 180, 140), (80, 90, 100))
save_logo(img, "meetingescape_hero.png")


# ── DUNGEON HERO ─────────────────────────────────────────────────────────────
print("\ndungeon_hero.png")
img = Image.new("RGBA", (W, H))
d = ImageDraw.Draw(img)

# Stone wall gradient
for y in range(H):
    t = y / H
    r = int(30 + t * 15 + random.randint(-2, 2))
    g = int(25 + t * 12 + random.randint(-2, 2))
    b = int(18 + t * 8  + random.randint(-2, 2))
    d.line([(0, y), (W, y)], fill=(r, g, b, 255))

# Stone brick pattern
for by in range(0, H, 60):
    d.line([(0, by), (W, by)], fill=(15, 12, 10, 150), width=2)
    offset = 80 if (by // 60) % 2 == 0 else 0
    for bx in range(offset, W, 160):
        d.line([(bx, by), (bx, by+59)], fill=(15, 12, 10, 120), width=2)

# Giant archway center
arch_cx = W // 2
arch_w = 280
arch_top = 50
arch_bot = H - 100
d.rectangle([arch_cx-arch_w, arch_top+arch_w, arch_cx+arch_w, arch_bot],
            fill=(5, 3, 8, 255))
d.pieslice([arch_cx-arch_w, arch_top, arch_cx+arch_w, arch_top+arch_w*2],
           180, 360, fill=(5, 3, 8, 255))
d.arc([arch_cx-arch_w, arch_top, arch_cx+arch_w, arch_top+arch_w*2],
      180, 360, fill=(70, 60, 50, 255), width=8)
d.line([(arch_cx-arch_w, arch_top+arch_w), (arch_cx-arch_w, arch_bot)],
       fill=(70, 60, 50, 255), width=8)
d.line([(arch_cx+arch_w, arch_top+arch_w), (arch_cx+arch_w, arch_bot)],
       fill=(70, 60, 50, 255), width=8)

# Torches on pillars
for tx in [arch_cx-arch_w-50, arch_cx+arch_w+50]:
    # Torch pole
    d.rectangle([tx-6, 120, tx+6, 350], fill=(90, 55, 25, 255))
    # Flame layers
    for fr, fc, fa in [(30, (255,80,10), 120), (22, (255,160,30), 160),
                       (14, (255,220,60), 200), (7, (255,255,180), 255)]:
        d.ellipse([tx-fr, 120-fr*2, tx+fr, 120+fr//2], fill=fc+(fa,))
    # Glow
    for gr in range(12, 0, -1):
        d.ellipse([tx-gr*20, 100-gr*18, tx+gr*20, 140+gr*12],
                  fill=(255, 120, 20, int(8*gr/12)))

# Skull and bones in darkness
sk_cx, sk_cy = arch_cx, arch_bot - 140
d.ellipse([sk_cx-30, sk_cy-35, sk_cx+30, sk_cy+15], fill=(70, 65, 55, 200))
d.ellipse([sk_cx-25, sk_cy-30, sk_cx+25, sk_cy+10], fill=(80, 75, 65, 220))
# Eye sockets
d.ellipse([sk_cx-16, sk_cy-18, sk_cx-4, sk_cy-6], fill=(200, 30, 30, 200))
d.ellipse([sk_cx+4, sk_cy-18, sk_cx+16, sk_cy-6], fill=(200, 30, 30, 200))
# Nose
d.polygon([(sk_cx-4, sk_cy-2), (sk_cx+4, sk_cy-2), (sk_cx, sk_cy+5)], fill=(40, 35, 30, 200))

# Sword stuck in ground
sw_x = arch_cx + 80
d.line([(sw_x, arch_bot-200), (sw_x, arch_bot-40)], fill=(160, 170, 190, 255), width=6)
# Crossguard
d.rectangle([sw_x-20, arch_bot-200, sw_x+20, arch_bot-192], fill=(180, 160, 60, 255))
# Handle
d.rectangle([sw_x-4, arch_bot-230, sw_x+4, arch_bot-200], fill=(120, 80, 30, 255))
# Pommel
d.ellipse([sw_x-8, arch_bot-240, sw_x+8, arch_bot-226], fill=(180, 160, 60, 255))

draw_title(d, "BITOCHI", "DUNGEON", "Descend. Fight. Survive.",
           (220, 200, 160), (255, 180, 50), (120, 110, 80))
save_logo(img, "dungeon_hero.png")


print("\nAll done!")
