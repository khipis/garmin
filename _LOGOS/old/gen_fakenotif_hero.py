#!/usr/bin/env python3
"""Generate fakenotificationescape_hero.png (1440x720) - PRO quality.
Story: boring meeting → watch vibrates → escape to freedom.
"""

import math, os, random
from PIL import Image, ImageDraw, ImageFont, ImageFilter

random.seed(42)
BASE = os.path.dirname(os.path.abspath(__file__))

def get_font(size):
    for p in ["/System/Library/Fonts/Supplemental/Impact.ttf",
              "/System/Library/Fonts/Helvetica.ttc",
              "/System/Library/Fonts/Arial.ttf"]:
        try: return ImageFont.truetype(p, size)
        except: pass
    return ImageFont.load_default()

def get_thin(size):
    for p in ["/System/Library/Fonts/Helvetica.ttc",
              "/System/Library/Fonts/Arial.ttf"]:
        try: return ImageFont.truetype(p, size)
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

# === BACKGROUND: deep dark with subtle green-tinted gradient ===
for y in range(H):
    t = y / H
    r = int(8 + 6 * math.sin(t * math.pi))
    g = int(12 + 8 * math.sin(t * math.pi))
    b = int(16 + 10 * math.sin(t * math.pi))
    d.line([(0, y), (W, y)], fill=(r, g, b))

# Subtle noise texture
noise = Image.new("RGBA", (W, H), (0, 0, 0, 0))
nd = ImageDraw.Draw(noise)
for _ in range(3000):
    nx, ny = random.randint(0, W-1), random.randint(0, H-1)
    a = random.randint(5, 15)
    nd.point((nx, ny), fill=(255, 255, 255, a))
img = Image.alpha_composite(img, noise)
d = ImageDraw.Draw(img)

# === SCENE 1 (LEFT): Boring meeting — muted gray/blue tones ===
s1_cx, s1_cy = 290, 300
# Panel with subtle gradient fill
d.rounded_rectangle([s1_cx - 210, s1_cy - 180, s1_cx + 210, s1_cy + 170],
                    radius=16, fill=(14, 14, 22))
# Panel border (subtle)
d.rounded_rectangle([s1_cx - 210, s1_cy - 180, s1_cx + 210, s1_cy + 170],
                    radius=16, outline=(30, 28, 45), width=2)

# "BORING MEETING" with glow
boring_f = get_font(22)
d.text((s1_cx, s1_cy - 155), "BORING MEETING", fill=(70, 62, 95), font=boring_f, anchor="mm")

# Conference table (3D-ish)
tw2, th2 = 160, 12
d.rounded_rectangle([s1_cx - tw2, s1_cy - th2, s1_cx + tw2, s1_cy + th2],
                    radius=5, fill=(40, 35, 55))
d.rounded_rectangle([s1_cx - tw2, s1_cy - th2, s1_cx + tw2, s1_cy + th2],
                    radius=5, outline=(55, 48, 72), width=1)
# Table shadow
d.rounded_rectangle([s1_cx - tw2 + 4, s1_cy + th2, s1_cx + tw2 - 4, s1_cy + th2 + 5],
                    radius=2, fill=(8, 8, 14))

def draw_person(draw, x, y, hr, body_len, color, arm_style="bored"):
    oc = tuple(min(255, c + 35) for c in color)
    # Head with anti-alias border
    draw.ellipse([x - hr - 1, y - hr - 1, x + hr + 1, y + hr + 1], fill=oc)
    draw.ellipse([x - hr, y - hr, x + hr, y + hr], fill=color)
    # Body
    draw.line([(x, y + hr), (x, y + hr + body_len)], fill=color, width=max(3, hr // 3))
    if arm_style == "bored":
        draw.line([(x, y + hr + body_len * 4 // 10), (x - hr * 3 // 2, y + hr + body_len * 2 // 10)], fill=color, width=max(2, hr // 4))
        draw.line([(x, y + hr + body_len * 4 // 10), (x + hr, y + hr + body_len * 6 // 10)], fill=color, width=max(2, hr // 4))
    elif arm_style == "watch":
        draw.line([(x, y + hr + body_len * 3 // 10), (x - hr * 3 // 2, y + hr + body_len * 5 // 10)], fill=color, width=max(2, hr // 4))
        draw.line([(x, y + hr + body_len * 3 // 10), (x + hr * 2, y + hr - body_len // 10)], fill=color, width=max(3, hr // 3))

# Far side people (smaller, dimmer)
for bx in [190, 290, 390]:
    draw_person(d, bx, s1_cy - 65, 12, 35, (55, 50, 75))

# Near side — bored people
draw_person(d, 190, s1_cy + 75, 14, 40, (70, 64, 95))
draw_person(d, 390, s1_cy + 75, 14, 40, (70, 64, 95))

# Protagonist — GREEN, looking at watch!
px, py = 290, s1_cy + 78
gc = (50, 200, 90)
draw_person(d, px, py, 16, 45, gc, arm_style="watch")
# Watch on raised wrist
wx, wy = px + 30, py + 2
d.rectangle([wx - 7, wy - 7, wx + 7, wy + 7], fill=(20, 200, 70), outline=(70, 255, 120), width=2)
# Watch glow
glow2 = Image.new("RGBA", (W, H), (0, 0, 0, 0))
g2d = ImageDraw.Draw(glow2)
for gr in range(25, 0, -1):
    a = int(12 * (1 - gr / 25))
    g2d.ellipse([wx - gr, wy - gr, wx + gr, wy + gr], fill=(30, 220, 80, a))
img = Image.alpha_composite(img, glow2)
d = ImageDraw.Draw(img)

# ZZZ floating
for i, (zx, zy, zs, za) in enumerate([(170, s1_cy - 90, 22, 110),
                                        (155, s1_cy - 112, 18, 85),
                                        (145, s1_cy - 130, 14, 60)]):
    d.text((zx, zy), "Z", fill=(90, 78, 120, za), font=get_font(zs), anchor="mm")

# Clock on wall
d.ellipse([s1_cx + 140, s1_cy - 170, s1_cx + 175, s1_cy - 135], outline=(45, 40, 60), width=2)
d.line([(s1_cx + 157, s1_cy - 152), (s1_cx + 157, s1_cy - 162)], fill=(60, 55, 80), width=2)
d.line([(s1_cx + 157, s1_cy - 152), (s1_cx + 165, s1_cy - 148)], fill=(60, 55, 80), width=1)

# === SCENE 2 (CENTER): Premium smartwatch ===
wcx, wcy = 720, 310
wr = 175

# Watch band top
band_w = 78
d.rounded_rectangle([wcx - band_w//2, wcy - wr - 70, wcx + band_w//2, wcy - wr + 12],
                    radius=8, fill=(30, 30, 35))
# Band texture lines
for by in range(wcy - wr - 60, wcy - wr + 5, 6):
    d.line([(wcx - band_w//2 + 6, by), (wcx + band_w//2 - 6, by)], fill=(38, 38, 44), width=1)
# Watch band bottom
d.rounded_rectangle([wcx - band_w//2, wcy + wr - 12, wcx + band_w//2, wcy + wr + 70],
                    radius=8, fill=(30, 30, 35))
for by in range(wcy + wr - 5, wcy + wr + 60, 6):
    d.line([(wcx - band_w//2 + 6, by), (wcx + band_w//2 - 6, by)], fill=(38, 38, 44), width=1)

# Watch body shadow (soft)
shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
sd = ImageDraw.Draw(shadow)
sd.ellipse([wcx - wr - 12, wcy - wr - 6, wcx + wr + 12, wcy + wr + 18], fill=(0, 0, 0, 60))
shadow = shadow.filter(ImageFilter.GaussianBlur(8))
img = Image.alpha_composite(img, shadow)
d = ImageDraw.Draw(img)

# Bezel (metallic gradient ring)
for i in range(10):
    rr = wr + 10 - i
    c = 35 + i * 10
    d.ellipse([wcx - rr, wcy - rr, wcx + rr, wcy + rr], outline=(c, c, c + 3), width=1)

# Watch face
d.ellipse([wcx - wr, wcy - wr, wcx + wr, wcy + wr], fill=(6, 6, 10))

# Side buttons
d.rounded_rectangle([wcx + wr + 4, wcy - 24, wcx + wr + 16, wcy + 24], radius=4, fill=(55, 55, 62))
d.rounded_rectangle([wcx + wr + 4, wcy + 40, wcx + wr + 14, wcy + 60], radius=3, fill=(50, 50, 56))

# === NOTIFICATION ON SCREEN ===
sr = wr - 16

# Green accent at top (thin)
d.arc([wcx - sr, wcy - sr, wcx + sr, wcy + sr], 250, 290, fill=(30, 210, 80), width=3)

# "Incoming Call" text
hf = get_thin(22)
d.text((wcx, wcy - sr + 28), "Incoming Call", fill=(30, 210, 80), font=hf, anchor="mm")

# Avatar with double ring
av_r = 32
av_y = wcy - 15
# Outer glow
for gr in range(8, 0, -1):
    a = int(20 * (1 - gr / 8))
    d.ellipse([wcx - av_r - gr, av_y - av_r - gr, wcx + av_r + gr, av_y + av_r + gr],
              outline=(30, 200, 80, a), width=1)
d.ellipse([wcx - av_r, av_y - av_r, wcx + av_r, av_y + av_r],
          fill=(8, 30, 14), outline=(30, 210, 80), width=2)
# Initial letter
d.text((wcx, av_y), "M", fill=(255, 255, 255), font=get_font(32), anchor="mm")

# Caller name
d.text((wcx, av_y + av_r + 20), "Mom", fill=(255, 255, 255), font=get_font(26), anchor="mm")
d.text((wcx, av_y + av_r + 46), "ringing...", fill=(25, 100, 40), font=get_thin(16), anchor="mm")

# Buttons
btn_r = 20
btn_y = wcy + sr - 38
dec_x = wcx - 50
acc_x = wcx + 50

# Decline (red)
d.ellipse([dec_x - btn_r - 2, btn_y - btn_r - 2, dec_x + btn_r + 2, btn_y + btn_r + 2],
          fill=(60, 10, 10))
d.ellipse([dec_x - btn_r, btn_y - btn_r, dec_x + btn_r, btn_y + btn_r], fill=(200, 35, 35))
# X
d.line([(dec_x - 8, btn_y - 8), (dec_x + 8, btn_y + 8)], fill=(255, 255, 255), width=3)
d.line([(dec_x + 8, btn_y - 8), (dec_x - 8, btn_y + 8)], fill=(255, 255, 255), width=3)

# Accept (green)
d.ellipse([acc_x - btn_r - 2, btn_y - btn_r - 2, acc_x + btn_r + 2, btn_y + btn_r + 2],
          fill=(10, 50, 15))
d.ellipse([acc_x - btn_r, btn_y - btn_r, acc_x + btn_r, btn_y + btn_r], fill=(30, 210, 70))
# Checkmark
d.line([(acc_x - 8, btn_y), (acc_x - 2, btn_y + 7)], fill=(255, 255, 255), width=3)
d.line([(acc_x - 2, btn_y + 7), (acc_x + 9, btn_y - 6)], fill=(255, 255, 255), width=3)

# Vibration waves around watch
vib = Image.new("RGBA", (W, H), (0, 0, 0, 0))
vd = ImageDraw.Draw(vib)
for wave in range(3):
    wr2 = wr + 25 + wave * 18
    a = 50 - wave * 15
    vd.arc([wcx - wr2, wcy - wr2, wcx + wr2, wcy + wr2], 200, 250, fill=(30, 210, 80, a), width=2)
    vd.arc([wcx - wr2, wcy - wr2, wcx + wr2, wcy + wr2], 20, 70, fill=(30, 210, 80, a), width=2)
img = Image.alpha_composite(img, vib)
d = ImageDraw.Draw(img)

# === SCENE 3 (RIGHT): Escape / Freedom ===
s3_cx, s3_cy = 1180, 300
d.rounded_rectangle([s3_cx - 180, s3_cy - 180, s3_cx + 180, s3_cy + 170],
                    radius=16, fill=(14, 14, 22))
d.rounded_rectangle([s3_cx - 180, s3_cy - 180, s3_cx + 180, s3_cy + 170],
                    radius=16, outline=(30, 28, 45), width=2)

# Green arrow between watch and right panel
d.line([(920, 310), (990, 310)], fill=(30, 210, 80), width=4)
d.polygon([(985, 298), (1005, 310), (985, 322)], fill=(30, 210, 80))

# Door frame (more detailed)
dx = s3_cx - 120
d.rectangle([dx, s3_cy - 155, dx + 12, s3_cy + 145], fill=(50, 44, 68))
d.rectangle([dx, s3_cy - 155, dx + 100, s3_cy - 145], fill=(50, 44, 68))
d.rectangle([dx, s3_cy + 138, dx + 100, s3_cy + 148], fill=(50, 44, 68))
# Open door (angled, with depth)
pts = [(dx + 12, s3_cy - 145), (dx + 55, s3_cy - 135),
       (dx + 55, s3_cy + 128), (dx + 12, s3_cy + 138)]
d.polygon(pts, fill=(38, 34, 52), outline=(55, 48, 72))
d.ellipse([dx + 44, s3_cy - 8, dx + 52, s3_cy + 2], fill=(180, 160, 100))

# Light beam through door (green-tinted)
beam = Image.new("RGBA", (W, H), (0, 0, 0, 0))
bd = ImageDraw.Draw(beam)
for i in range(60):
    a = int(30 * (1 - i / 60))
    bx = dx + 55 + i * 3
    bd.line([(bx, s3_cy - 130 + i), (bx, s3_cy + 125 - i)], fill=(30, 220, 80, a), width=2)
img = Image.alpha_composite(img, beam)
d = ImageDraw.Draw(img)

# Running person (big, bright green, joyful)
rx, ry = s3_cx + 55, s3_cy - 10
gc = (55, 240, 100)
gco = (100, 255, 150)
# Head
d.ellipse([rx - 24, ry - 24, rx + 24, ry + 24], fill=gc, outline=gco, width=3)
# Happy face
d.ellipse([rx - 9, ry - 10, rx - 4, ry - 5], fill=(255, 255, 255))
d.ellipse([rx + 4, ry - 10, rx + 9, ry - 5], fill=(255, 255, 255))
d.arc([rx - 12, ry - 2, rx + 12, ry + 14], 10, 170, fill=(255, 255, 255), width=3)
# Body
d.line([(rx, ry + 24), (rx - 14, ry + 82)], fill=gc, width=5)
# Arms (victory!)
d.line([(rx - 7, ry + 42), (rx + 35, ry + 15)], fill=gc, width=4)
d.line([(rx - 7, ry + 42), (rx - 38, ry + 52)], fill=gc, width=4)
# Legs
d.line([(rx - 14, ry + 82), (rx + 22, ry + 118)], fill=gc, width=4)
d.line([(rx - 14, ry + 82), (rx - 42, ry + 112)], fill=gc, width=4)

# Speed lines
for i in range(7):
    ly = ry - 22 + i * 18
    lx = rx - 58 - random.randint(0, 12)
    ll = 22 + random.randint(0, 18)
    d.line([(lx, ly), (lx - ll, ly)], fill=(30, 220, 80, 140), width=2)

# "FREEDOM!" with glow
ff = get_font(30)
# Glow
glow3 = Image.new("RGBA", (W, H), (0, 0, 0, 0))
g3d = ImageDraw.Draw(glow3)
g3d.text((rx + 5, ry - 58), "FREEDOM!", fill=(30, 200, 80, 60), font=get_font(34), anchor="mm")
glow3 = glow3.filter(ImageFilter.GaussianBlur(4))
img = Image.alpha_composite(img, glow3)
d = ImageDraw.Draw(img)
d.text((rx + 5, ry - 58), "FREEDOM!", fill=(80, 255, 140), font=ff, anchor="mm")

# === BOTTOM TITLE BAR ===
# Gradient bar
for y in range(H - 140, H):
    t = (y - (H - 140)) / 140
    c = int(8 + 4 * t)
    d.line([(0, y), (W, y)], fill=(c, c + 1, c + 3))
# Green separator line
d.line([(100, H - 140), (W - 100, H - 140)], fill=(30, 210, 80), width=2)
# Decorative dots on the line
for x in [100, W//4, W//2, W*3//4, W-100]:
    d.ellipse([x - 3, H - 143, x + 3, H - 137], fill=(30, 210, 80))

# Title
tf = get_font(54)
d.text((W//2 + 2, H - 98), "FAKE NOTIFICATION", fill=(0, 0, 0), font=tf, anchor="mm")
d.text((W//2, H - 100), "FAKE NOTIFICATION", fill=(255, 255, 255), font=tf, anchor="mm")

# Subtitle
sf = get_thin(24)
d.text((W//2, H - 56), "ESCAPE KIT", fill=(30, 210, 80), font=sf, anchor="mm")

# Tags
tagf = get_thin(15)
d.text((W//2, H - 25),
       "Call  ·  SMS  ·  WhatsApp  ·  Email  ·  Telegram  ·  PagerDuty  ·  Slack  ·  Messenger",
       fill=(55, 55, 70), font=tagf, anchor="mm")

# === VIGNETTE ===
vig = Image.new("RGBA", (W, H), (0, 0, 0, 0))
vigd = ImageDraw.Draw(vig)
for i in range(160):
    alpha = int(100 * (1 - i / 160))
    vigd.rectangle([i, i, W - i, H - i], outline=(0, 0, 0, alpha))
img = Image.alpha_composite(img, vig)

out = img.convert("RGB")
save(out, os.path.join(BASE, "fakenotificationescape", "fakenotificationescape_hero.png"))
save(out, os.path.join(BASE, "fakenotificationescape_hero.png"))
print("Done!")
