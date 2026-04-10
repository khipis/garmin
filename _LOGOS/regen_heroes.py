#!/usr/bin/env python3
"""Regenerate specific hero images: run, pets, 8ball, arcade, blobs, boxing"""
import math, random, os
from PIL import Image, ImageDraw, ImageFont

W, H = 1440, 720
OUT = os.path.dirname(os.path.abspath(__file__))
random.seed(42)

# ── helpers ──────────────────────────────────────────────────────────────────

def save(img, name):
    rgb = img.convert("RGB")
    path = os.path.join(OUT, name)
    rgb.save(path, "PNG", optimize=True)
    kb = os.path.getsize(path) // 1024
    print(f"  {name}  {kb} KB")

def grad_bg(img, top, bot):
    d = ImageDraw.Draw(img)
    for y in range(H):
        t = y / H
        r = int(top[0] + (bot[0]-top[0])*t)
        g = int(top[1] + (bot[1]-top[1])*t)
        b = int(top[2] + (bot[2]-top[2])*t)
        d.line([(0,y),(W,y)], fill=(r,g,b,255))

def glow(img, cx, cy, r, col, layers=6):
    for i in range(layers, 0, -1):
        alpha = int(60 * i / layers)
        rad = r + (layers - i) * 8
        lay = Image.new("RGBA", (W, H), (0,0,0,0))
        ld = ImageDraw.Draw(lay)
        ld.ellipse([cx-rad, cy-rad, cx+rad, cy+rad], fill=col+(alpha,))
        img.alpha_composite(lay)

def get_font(size):
    candidates = [
        "/System/Library/Fonts/Supplemental/Impact.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/Arial.ttf",
        "/Library/Fonts/Arial.ttf",
    ]
    for p in candidates:
        try:
            return ImageFont.truetype(p, size)
        except:
            pass
    return ImageFont.load_default()

def add_title(img, title, subtitle, col, title_size=90, sub_size=34):
    d = ImageDraw.Draw(img)
    tf = get_font(title_size)
    sf = get_font(sub_size)
    # shadow
    bb = d.textbbox((0,0), title, font=tf)
    tw = bb[2]-bb[0]; th = bb[3]-bb[1]
    tx = (W - tw) // 2; ty = H - 155
    d.text((tx+3, ty+3), title, font=tf, fill=(0,0,0,180))
    d.text((tx, ty), title, font=tf, fill=col+(255,))
    # subtitle
    bb2 = d.textbbox((0,0), subtitle, font=sf)
    sw = bb2[2]-bb2[0]
    d.text(((W-sw)//2, ty+th+8), subtitle, font=sf, fill=(200,200,200,210))

def overlay(img, lay):
    img.alpha_composite(lay)

# ══════════════════════════════════════════════════════════════════════════════
# RUN — bloody demon chasing player in dungeon
# ══════════════════════════════════════════════════════════════════════════════
print("run_hero.png")
img = Image.new("RGBA", (W, H))
grad_bg(img, (10, 2, 2), (40, 5, 5))
d = ImageDraw.Draw(img)

# dungeon stone floor tiles
for tx in range(0, W, 80):
    for ty in range(H//2, H, 40):
        shade = random.randint(18, 32)
        d.rectangle([tx, ty, tx+78, ty+38], fill=(shade,shade,shade,255))
        d.rectangle([tx, ty, tx+78, ty+1], fill=(50,50,50,255))
        d.rectangle([tx, ty, tx+1, ty+38], fill=(50,50,50,255))

# dungeon walls with torches
for wx in range(0, W, 180):
    d.rectangle([wx, 60, wx+10, H//2], fill=(25,20,18,255))
    # torch flame
    fx = wx + 5
    for fi in range(8):
        fy = 50 - fi*4
        alpha = 200 - fi*20
        rad = 14 - fi
        lay = Image.new("RGBA", (W, H), (0,0,0,0))
        ld = ImageDraw.Draw(lay)
        ld.ellipse([fx-rad, fy-rad, fx+rad, fy+rad], fill=(255, 120+fi*10, 0, alpha))
        img.alpha_composite(lay)

# blood splatters on floor / wall
for _ in range(40):
    bx = random.randint(0, W)
    by = random.randint(H//3, H)
    br = random.randint(4, 18)
    lay = Image.new("RGBA", (W, H), (0,0,0,0))
    ld = ImageDraw.Draw(lay)
    ld.ellipse([bx-br, by-br, bx+br, by+br], fill=(180, 10, 10, 200))
    img.alpha_composite(lay)
    # splatter streaks
    for _ in range(3):
        ex = bx + random.randint(-30, 30)
        ey = by + random.randint(-20, 20)
        d.line([(bx, by), (ex, ey)], fill=(160, 8, 8, 180), width=2)

# --- DEMON (right side, large, menacing) ---
dx, dy = 1100, 180  # demon center top

def draw_demon(img, cx, cy, scale=1.0):
    lay = Image.new("RGBA", (W, H), (0,0,0,0))
    ld = ImageDraw.Draw(lay)
    s = scale

    # body — dark crimson
    body_w, body_h = int(180*s), int(240*s)
    ld.ellipse([cx-body_w//2, cy, cx+body_w//2, cy+body_h],
               fill=(120, 10, 10, 240))
    # abs ridges
    for i in range(3):
        ry = cy + int(60*s) + i*int(30*s)
        ld.arc([cx-int(40*s), ry, cx+int(40*s), ry+int(20*s)],
               start=0, end=180, fill=(170, 20, 20, 180), width=3)

    # head
    head_r = int(80*s)
    hx, hy = cx, cy - int(20*s)
    ld.ellipse([hx-head_r, hy-head_r, hx+head_r, hy+head_r],
               fill=(140, 12, 12, 250))
    # jaw / snout
    ld.ellipse([hx-int(45*s), hy+int(20*s), hx+int(45*s), hy+int(70*s)],
               fill=(110, 8, 8, 240))
    # teeth
    for ti in range(5):
        tx2 = hx - int(30*s) + ti*int(15*s)
        ld.polygon([(tx2, hy+int(55*s)), (tx2+int(8*s), hy+int(55*s)),
                    (tx2+int(4*s), hy+int(75*s))],
                   fill=(240, 240, 240, 250))

    # GLOWING EYES (yellow/red)
    for ex_off, eyecol in [(-int(32*s), (255, 60, 0)), (int(32*s), (255, 80, 0))]:
        ex2 = hx + ex_off; ey2 = hy - int(10*s)
        # glow
        for gi in range(5):
            gr = int((18+gi*6)*s)
            ga = 80 - gi*12
            ld.ellipse([ex2-gr, ey2-gr, ex2+gr, ey2+gr],
                       fill=eyecol+(ga,))
        ld.ellipse([ex2-int(14*s), ey2-int(10*s), ex2+int(14*s), ey2+int(10*s)],
                   fill=(255, 200, 0, 255))
        ld.ellipse([ex2-int(7*s), ey2-int(5*s), ex2+int(7*s), ey2+int(5*s)],
                   fill=(0, 0, 0, 255))

    # horns
    horn_pts = [
        [(hx-int(50*s), hy-int(40*s)), (hx-int(70*s), hy-int(120*s)), (hx-int(30*s), hy-int(30*s))],
        [(hx+int(50*s), hy-int(40*s)), (hx+int(70*s), hy-int(120*s)), (hx+int(30*s), hy-int(30*s))],
    ]
    for hp in horn_pts:
        ld.polygon(hp, fill=(80, 5, 5, 255))

    # claws / arms
    arm_left = [(cx-int(90*s), cy+int(60*s)), (cx-int(160*s), cy+int(130*s)),
                (cx-int(180*s), cy+int(110*s)), (cx-int(100*s), cy+int(80*s))]
    arm_right = [(cx+int(90*s), cy+int(60*s)), (cx+int(160*s), cy+int(130*s)),
                 (cx+int(180*s), cy+int(110*s)), (cx+int(100*s), cy+int(80*s))]
    for arm in [arm_left, arm_right]:
        ld.polygon(arm, fill=(120, 10, 10, 230))
    # claw tips right
    for ci in range(4):
        clx = cx + int(160*s) + ci*int(8*s)
        cly = cy + int(125*s) + ci*int(5*s)
        ld.polygon([(clx, cly), (clx+int(6*s), cly), (clx+int(3*s), cly+int(20*s))],
                   fill=(220, 220, 200, 240))

    # wings
    wing_l = [(cx-int(50*s), cy+int(20*s)), (cx-int(250*s), cy-int(80*s)),
              (cx-int(200*s), cy+int(80*s)), (cx-int(80*s), cy+int(100*s))]
    wing_r = [(cx+int(50*s), cy+int(20*s)), (cx+int(250*s), cy-int(80*s)),
              (cx+int(200*s), cy+int(80*s)), (cx+int(80*s), cy+int(100*s))]
    for wing, a in [(wing_l, 180), (wing_r, 180)]:
        ld.polygon(wing, fill=(60, 3, 3, a))

    # outline / highlight
    ld.arc([hx-head_r, hy-head_r, hx+head_r, hy+head_r], 200, 340,
           fill=(200, 60, 60, 140), width=3)

    img.alpha_composite(lay)

draw_demon(img, dx, dy, scale=1.3)

# red atmospheric glow behind demon
glow(img, dx, dy+160, 220, (200, 10, 10), layers=8)

# --- RUNNING PLAYER (small, left, fleeing) ---
def draw_runner(img, cx, cy, frame=0):
    lay = Image.new("RGBA", (W, H), (0,0,0,0))
    ld = ImageDraw.Draw(lay)
    # body
    ld.ellipse([cx-15, cy-10, cx+15, cy+30], fill=(60, 100, 180, 240))
    # head
    ld.ellipse([cx-12, cy-35, cx+12, cy-10], fill=(220, 180, 140, 255))
    # legs (running pose)
    leg_off = 10 if frame == 0 else -10
    ld.line([(cx, cy+30), (cx-12+leg_off, cy+65)], fill=(50, 80, 160, 240), width=7)
    ld.line([(cx, cy+30), (cx+12-leg_off, cy+65)], fill=(50, 80, 160, 240), width=7)
    # arms
    ld.line([(cx-10, cy+5), (cx-28, cy+25+leg_off//2)], fill=(50, 80, 160, 220), width=5)
    ld.line([(cx+10, cy+5), (cx+20, cy+30-leg_off//2)], fill=(50, 80, 160, 220), width=5)
    img.alpha_composite(lay)

draw_runner(img, 180, 380, 0)
draw_runner(img, 320, 360, 1)
draw_runner(img, 460, 375, 0)

# speed lines
for sl in range(12):
    sy = random.randint(300, 550)
    sx = random.randint(50, 600)
    d.line([(sx, sy), (sx-random.randint(40,120), sy+random.randint(-10,10))],
           fill=(255, 255, 255, 60), width=2)

# blood drips from demon
for _ in range(8):
    bx = random.randint(950, 1250)
    by = random.randint(350, 650)
    for seg in range(random.randint(3,8)):
        d.line([(bx, by+seg*12), (bx+random.randint(-3,3), by+(seg+1)*12)],
               fill=(200, 10, 10, 200), width=3)

add_title(img, "BITOCHI RUN", "Escape the demon. Run or die.", (255, 60, 60))
save(img, "run_hero.png")


# ══════════════════════════════════════════════════════════════════════════════
# PETS — beautiful pixel puppy
# ══════════════════════════════════════════════════════════════════════════════
print("pets_hero.png")
img = Image.new("RGBA", (W, H))
grad_bg(img, (20, 60, 120), (140, 210, 255))
d = ImageDraw.Draw(img)

# sunny meadow
# sky clouds
for cx2, cy2, cr in [(200,120,60),(350,90,80),(550,140,50),(900,100,70),(1150,130,65),(1350,110,55)]:
    for c_off in [(-40,10),(0,0),(40,10)]:
        lay = Image.new("RGBA", (W, H), (0,0,0,0))
        ld = ImageDraw.Draw(lay)
        ld.ellipse([cx2+c_off[0]-cr, cy2+c_off[1]-cr//2,
                    cx2+c_off[0]+cr, cy2+c_off[1]+cr//2], fill=(255,255,255,210))
        img.alpha_composite(lay)

# sun
glow(img, 1300, 80, 60, (255, 220, 50), layers=8)
lay = Image.new("RGBA", (W, H), (0,0,0,0))
ld = ImageDraw.Draw(lay)
ld.ellipse([1240, 20, 1360, 140], fill=(255, 235, 60, 255))
img.alpha_composite(lay)

# grass
for gx in range(W+1):
    t = gx / W
    gr = int(40 + t * 20)
    gg = int(160 + t * 30)
    gb = 60
    d.line([(gx, H*2//3), (gx, H)], fill=(gr, gg, gb, 255))

# flowers
for fx, fy in [(100,450),(250,460),(400,445),(600,455),(750,440),(950,450),(1100,445),(1280,455),(1380,450)]:
    fc = random.choice([(255,80,80),(255,200,50),(200,100,255),(255,255,255)])
    lay = Image.new("RGBA", (W, H), (0,0,0,0))
    ld = ImageDraw.Draw(lay)
    for ang in range(0,360,60):
        prad = math.radians(ang)
        px2 = fx + int(math.cos(prad)*12)
        py2 = fy + int(math.sin(prad)*12)
        ld.ellipse([px2-7, py2-7, px2+7, py2+7], fill=fc+(230,))
    ld.ellipse([fx-5, fy-5, fx+5, fy+5], fill=(255,220,50,255))
    img.alpha_composite(lay)

# ── PIXEL DOG — golden retriever style, center ──
def draw_pixel_dog(img, cx, cy, pixel=8):
    lay = Image.new("RGBA", (W, H), (0,0,0,0))
    ld = ImageDraw.Draw(lay)
    p = pixel

    def px(col, gx, gy, w=1, h=1):
        ld.rectangle([cx+gx*p, cy+gy*p, cx+(gx+w)*p-1, cy+(gy+h)*p-1], fill=col)

    FUR  = (210, 150, 60, 255)
    DARK = (140,  90, 30, 255)
    NOSE = (40,   30, 25, 255)
    EYE  = (40,   30, 20, 255)
    ELEG = (80,   60, 200, 255)   # collar
    WHT  = (245, 220, 180, 255)

    # BODY
    for gx in range(-5, 6):
        for gy in range(0, 8):
            px(FUR, gx, gy)
    # belly lighter
    for gx in range(-3, 4):
        for gy in range(2, 7):
            px(WHT, gx, gy)

    # NECK
    for gx in range(-2, 3):
        px(FUR, gx, -2)
    for gx in range(-2, 3):
        px(FUR, gx, -1)

    # collar
    for gx in range(-3, 4):
        px(ELEG, gx, -2)

    # HEAD
    for gx in range(-4, 5):
        for gy in range(-8, -2):
            px(FUR, gx, gy)
    # snout
    for gx in range(-2, 3):
        for gy in range(-5, -2):
            px(WHT, gx, gy)

    # nose
    px(NOSE, -1, -5, 2, 1)
    px(NOSE, 0, -6, 1, 1)

    # EYES — big cute
    px(EYE, -3, -7, 2, 2)
    px(EYE,  1, -7, 2, 2)
    # eye whites / shine
    px((255,255,255,255), -3, -8, 1, 1)
    px((255,255,255,255), 1, -8, 1, 1)
    px((100,180,255,220), -4, -7, 1, 1)
    px((100,180,255,220),  2, -7, 1, 1)

    # EARS — floppy
    for gx in range(-6, -3):
        for gy in range(-9, -4):
            px(DARK, gx, gy)
    for gx in range(3, 7):
        for gy in range(-9, -4):
            px(DARK, gx, gy)

    # TONGUE
    px((230, 80, 100, 250), -1, -3, 2, 2)
    px((200, 60, 80, 250), 0, -2, 1, 1)

    # LEGS
    for gx, base in [(-4,8),(-2,8),(1,8),(3,8)]:
        for gy in range(0, 5):
            px(FUR, gx, base+gy)
        px(DARK, gx, base+4)  # paw

    # TAIL
    for i, (tx2, ty2) in enumerate([(6,1),(7,0),(8,-1),(9,-2),(8,-3)]):
        px(FUR, tx2, ty2)
    px(WHT, 8, -3)

    img.alpha_composite(lay)

draw_pixel_dog(img, W//2 - 100, H//2 - 20, pixel=10)

# sparkle / hearts around dog
for hx2, hy2 in [(580, 260), (820, 240), (720, 320), (650, 450), (790, 440)]:
    lay = Image.new("RGBA", (W, H), (0,0,0,0))
    ld = ImageDraw.Draw(lay)
    ld.text((hx2, hy2), "♥", font=get_font(36), fill=(255, 80, 120, 200))
    img.alpha_composite(lay)

# paw prints on ground
for px3, py3 in [(300,560),(350,580),(400,560),(800,565),(860,580),(920,560)]:
    lay = Image.new("RGBA", (W, H), (0,0,0,0))
    ld = ImageDraw.Draw(lay)
    ld.ellipse([px3-10, py3-8, px3+10, py3+8], fill=(180,120,60,160))
    for toe in [(-8,-12),(-4,-15),(4,-15),(8,-12)]:
        ld.ellipse([px3+toe[0]-5, py3+toe[1]-5, px3+toe[0]+5, py3+toe[1]+5],
                   fill=(180,120,60,140))
    img.alpha_composite(lay)

add_title(img, "BITOCHI PETS", "Your pixel companion on the wrist", (255, 230, 60))
save(img, "pets_hero.png")


# ══════════════════════════════════════════════════════════════════════════════
# 8BALL — magic fortune telling 8-ball, mystical
# ══════════════════════════════════════════════════════════════════════════════
print("8ball_hero.png")
img = Image.new("RGBA", (W, H))
grad_bg(img, (5, 0, 20), (15, 5, 50))
d = ImageDraw.Draw(img)

# star field
random.seed(7)
for _ in range(300):
    sx = random.randint(0, W)
    sy = random.randint(0, H)
    sr = random.choice([1,1,1,2])
    alpha = random.randint(100, 255)
    d.ellipse([sx-sr, sy-sr, sx+sr, sy+sr], fill=(255,255,255,alpha))

# mystical rays from center
ball_cx, ball_cy = W//2, H//2 - 20
for ang in range(0, 360, 15):
    rad = math.radians(ang)
    x2 = ball_cx + int(math.cos(rad) * 500)
    y2 = ball_cy + int(math.sin(rad) * 500)
    lay = Image.new("RGBA", (W, H), (0,0,0,0))
    ld = ImageDraw.Draw(lay)
    ld.line([(ball_cx, ball_cy), (x2, y2)], fill=(80, 20, 160, 18), width=3)
    img.alpha_composite(lay)

# purple/violet atmospheric glow
glow(img, ball_cx, ball_cy, 280, (120, 0, 200), layers=10)

# THE BALL — large, shiny black sphere
ball_r = 240
lay = Image.new("RGBA", (W, H), (0,0,0,0))
ld = ImageDraw.Draw(lay)
# shadow
ld.ellipse([ball_cx-ball_r+20, ball_cy-ball_r+30,
            ball_cx+ball_r+20, ball_cy+ball_r+30], fill=(0,0,0,120))
# main ball
ld.ellipse([ball_cx-ball_r, ball_cy-ball_r, ball_cx+ball_r, ball_cy+ball_r],
           fill=(8, 5, 15, 255))
# glossy highlight (top left)
for gi in range(8):
    gr2 = int((90-gi*10) * 0.8)
    ga2 = 180 - gi*20
    ld.ellipse([ball_cx-int(ball_r*0.55)+gi*4, ball_cy-int(ball_r*0.65)+gi*4,
                ball_cx-int(ball_r*0.55)+gr2*2+gi*4, ball_cy-int(ball_r*0.65)+gr2+gi*4],
               fill=(255,255,255,ga2))
# inner circle (white triangle area)
ic_r = 100
ld.ellipse([ball_cx-ic_r, ball_cy-ic_r, ball_cx+ic_r, ball_cy+ic_r],
           fill=(20, 15, 40, 255))
ld.ellipse([ball_cx-ic_r, ball_cy-ic_r, ball_cx+ic_r, ball_cy+ic_r],
           outline=(100, 60, 200, 200), width=3)
# the "8"
img.alpha_composite(lay)
d2 = ImageDraw.Draw(img)
f8 = get_font(120)
bb = d2.textbbox((0,0), "8", font=f8)
tw = bb[2]-bb[0]; th = bb[3]-bb[1]
d2.text((ball_cx - tw//2 + 2, ball_cy - th//2 + 2), "8", font=f8, fill=(0,0,0,200))
d2.text((ball_cx - tw//2, ball_cy - th//2), "8", font=f8, fill=(255,255,255,255))

# mystical symbols floating around
symbols = ["✦", "☽", "✧", "⊛", "◈", "⋆", "❋", "✦"]
sym_pos = [(180,150),(280,90),(420,200),(1000,130),(1150,200),(1260,100),(1350,180),(900,180)]
for sym, (sx2,sy2) in zip(symbols, sym_pos):
    alpha = random.randint(120,200)
    fsz = random.choice([28,36,44])
    lay = Image.new("RGBA", (W, H), (0,0,0,0))
    ld = ImageDraw.Draw(lay)
    ld.text((sx2, sy2), sym, font=get_font(fsz), fill=(180, 100, 255, alpha))
    img.alpha_composite(lay)

# fortune message window at bottom of ball
d2.rounded_rectangle([ball_cx-180, ball_cy+120, ball_cx+180, ball_cy+200],
                       radius=8, fill=(20,10,50,230), outline=(120,60,220,200), width=2)
fmsg = get_font(28)
msg = "Ask & receive the truth"
bb3 = d2.textbbox((0,0), msg, font=fmsg)
mw = bb3[2]-bb3[0]
d2.text((ball_cx-mw//2, ball_cy+140), msg, font=fmsg, fill=(180,140,255,230))

add_title(img, "BITOCHI 8BALL", "Shake for destiny", (160, 80, 255))
save(img, "8ball_hero.png")


# ══════════════════════════════════════════════════════════════════════════════
# ARCADE — axe / knife throwing at target board
# ══════════════════════════════════════════════════════════════════════════════
print("arcade_hero.png")
img = Image.new("RGBA", (W, H))
grad_bg(img, (10, 8, 5), (35, 22, 12))
d = ImageDraw.Draw(img)

# wooden plank background texture
for px4 in range(0, W, 120):
    shade = random.randint(28, 45)
    d.rectangle([px4, 0, px4+118, H], fill=(shade, int(shade*0.7), int(shade*0.4), 255))
    d.line([(px4, 0), (px4, H)], fill=(10, 7, 3, 200), width=2)
for py4 in range(0, H, 60):
    d.line([(0, py4), (W, py4)], fill=(15,10,5,80), width=1)

# grain lines
random.seed(13)
for _ in range(80):
    gx1 = random.randint(0, W)
    gy1 = random.randint(0, H)
    d.line([(gx1, gy1), (gx1+random.randint(30,120), gy1+random.randint(-5,5))],
           fill=(60,40,20,50), width=1)

# TARGET LOG — center-left
def draw_target(img, cx, cy, r_max):
    lay = Image.new("RGBA", (W, H), (0,0,0,0))
    ld = ImageDraw.Draw(lay)
    colors = [(180,100,50),(220,60,50),(220,60,50),(255,255,255),(255,255,255),
              (220,60,50),(220,60,50),(180,100,50)]
    rings = 8
    for i in range(rings, 0, -1):
        r = int(r_max * i / rings)
        ld.ellipse([cx-r, cy-r, cx+r, cy+r], fill=colors[i-1]+(240,))
    # center dot
    ld.ellipse([cx-12, cy-12, cx+12, cy+12], fill=(255,230,50,255))
    # log texture rings
    for i in range(1, rings+1):
        r = int(r_max * i / rings)
        ld.ellipse([cx-r, cy-r, cx+r, cy+r], outline=(0,0,0,100), width=2)
    # wood grain radial
    for ang2 in range(0, 360, 30):
        rad2 = math.radians(ang2)
        ld.line([(cx, cy), (cx+int(math.cos(rad2)*r_max), cy+int(math.sin(rad2)*r_max))],
                fill=(0,0,0,30), width=1)
    img.alpha_composite(lay)

draw_target(img, 480, H//2-20, 260)
draw_target(img, 1100, H//2+40, 180)

# AXES — embedded in targets and flying
def draw_axe(img, cx, cy, angle_deg, size=1.0):
    lay = Image.new("RGBA", (W, H), (0,0,0,0))
    ld = ImageDraw.Draw(lay)
    s = size
    ang = math.radians(angle_deg)

    # handle
    hlen = int(120*s)
    hend_x = cx + int(math.cos(ang) * hlen)
    hend_y = cy + int(math.sin(ang) * hlen)
    ld.line([(cx, cy), (hend_x, hend_y)], fill=(100, 65, 30, 255), width=int(10*s))
    # grip wrap
    for gi2 in range(3):
        gpt = int(hlen * (0.3 + gi2*0.2))
        gx3 = cx + int(math.cos(ang)*gpt)
        gy3 = cy + int(math.sin(ang)*gpt)
        perp = ang + math.pi/2
        ld.line([(gx3+int(math.cos(perp)*8*s), gy3+int(math.sin(perp)*8*s)),
                 (gx3-int(math.cos(perp)*8*s), gy3-int(math.sin(perp)*8*s))],
                fill=(60,30,10,200), width=int(4*s))

    # axe head (perpendicular to handle direction)
    perp2 = ang - math.pi/2
    # blade shape
    bx1 = cx - int(math.cos(ang)*20*s)
    by1 = cy - int(math.sin(ang)*20*s)
    blade = [
        (bx1 + int(math.cos(perp2)*50*s), by1 + int(math.sin(perp2)*50*s)),
        (bx1 - int(math.cos(perp2)*20*s), by1 - int(math.sin(perp2)*20*s)),
        (bx1 + int(math.cos(ang)*35*s) - int(math.cos(perp2)*20*s),
         by1 + int(math.sin(ang)*35*s) - int(math.sin(perp2)*20*s)),
        (bx1 + int(math.cos(ang)*35*s) + int(math.cos(perp2)*55*s),
         by1 + int(math.sin(ang)*35*s) + int(math.sin(perp2)*55*s)),
    ]
    ld.polygon(blade, fill=(180, 190, 200, 255))
    # blade edge highlight
    ld.line([blade[0], blade[3]], fill=(230,240,250,255), width=int(3*s))
    # axe eye hole
    hole_cx = bx1 + int(math.cos(perp2)*15*s)
    hole_cy = by1 + int(math.sin(perp2)*15*s)
    ld.ellipse([hole_cx-int(8*s), hole_cy-int(5*s), hole_cx+int(8*s), hole_cy+int(5*s)],
               fill=(60,40,20,200))

    img.alpha_composite(lay)

def draw_knife(img, cx, cy, angle_deg, size=1.0):
    lay = Image.new("RGBA", (W, H), (0,0,0,0))
    ld = ImageDraw.Draw(lay)
    s = size
    ang = math.radians(angle_deg)
    klen = int(100*s)
    # blade
    blade_tip = (cx + int(math.cos(ang)*klen), cy + int(math.sin(ang)*klen))
    perp3 = ang + math.pi/2
    blade_pts = [
        blade_tip,
        (cx - int(math.cos(perp3)*7*s), cy - int(math.sin(perp3)*7*s)),
        (cx + int(math.cos(perp3)*3*s), cy + int(math.sin(perp3)*3*s)),
    ]
    ld.polygon(blade_pts, fill=(200, 210, 220, 255))
    ld.line([blade_tip, blade_pts[1]], fill=(240,245,255,255), width=2)
    # guard
    gx4 = cx + int(math.cos(ang-math.pi)*5*s)
    gy4 = cy + int(math.sin(ang-math.pi)*5*s)
    ld.line([(gx4+int(math.cos(perp3)*18*s), gy4+int(math.sin(perp3)*18*s)),
             (gx4-int(math.cos(perp3)*18*s), gy4-int(math.sin(perp3)*18*s))],
            fill=(160,130,80,255), width=int(6*s))
    # handle
    hend2 = (cx - int(math.cos(ang)*50*s), cy - int(math.sin(ang)*50*s))
    ld.line([(cx, cy), hend2], fill=(80, 50, 20, 255), width=int(9*s))
    img.alpha_composite(lay)

# axes stuck in big target
draw_axe(img, 480, H//2-20, -90, size=1.2)  # top center
draw_axe(img, 480, H//2-20, 10, size=1.1)   # slight right
draw_knife(img, 480, H//2-20, -45, size=1.0)
draw_knife(img, 480, H//2-20, -135, size=1.0)

# axes stuck in small target
draw_axe(img, 1100, H//2+40, -90, size=0.9)
draw_knife(img, 1100, H//2+40, 30, size=0.85)

# FLYING AXE — motion blur
for fi3 in range(5):
    draw_axe(img, 870-fi3*25, 280+fi3*8, -80-fi3*5, size=1.15)
lay_blur = Image.new("RGBA", (W, H), (0,0,0,0))
ld_blur = ImageDraw.Draw(lay_blur)
ld_blur.line([(650,250),(870,285)], fill=(255,255,255,40), width=4)
img.alpha_composite(lay_blur)

# score flash
d.text((420, 90), "+500", font=get_font(60), fill=(255,220,50,220))
d.text((1050, 200), "+300", font=get_font(44), fill=(255,220,50,180))

add_title(img, "BITOCHI ARCADE", "Stick the axe. Beat the record.", (255, 200, 80))
save(img, "arcade_hero.png")


# ══════════════════════════════════════════════════════════════════════════════
# BLOBS — angry eyes, bazookas, explosions
# ══════════════════════════════════════════════════════════════════════════════
print("blobs_hero.png")
img = Image.new("RGBA", (W, H))
grad_bg(img, (5, 15, 5), (20, 45, 15))
d = ImageDraw.Draw(img)

# cratered terrain
for tx3 in range(0, W, 8):
    h_terrain = H//2 + int(math.sin(tx3*0.03)*30) + int(math.sin(tx3*0.07)*15)
    d.line([(tx3, h_terrain), (tx3, H)], fill=(30, 70, 25, 255))
# surface line
for tx3 in range(0, W-1):
    h1 = H//2 + int(math.sin(tx3*0.03)*30) + int(math.sin(tx3*0.07)*15)
    h2 = H//2 + int(math.sin((tx3+1)*0.03)*30) + int(math.sin((tx3+1)*0.07)*15)
    d.line([(tx3, h1), (tx3+1, h2)], fill=(50, 120, 40, 255), width=3)

# craters
for crx, cry, crr in [(300, H//2+10, 45), (700, H//2+20, 35), (1100, H//2+15, 50)]:
    lay = Image.new("RGBA", (W, H), (0,0,0,0))
    ld = ImageDraw.Draw(lay)
    ld.ellipse([crx-crr, cry-crr//2, crx+crr, cry+crr//2], fill=(15,40,12,240))
    ld.arc([crx-crr, cry-crr//2, crx+crr, cry+crr//2], 180, 360,
           fill=(60,140,50,180), width=3)
    img.alpha_composite(lay)

# EXPLOSIONS
def draw_explosion(img, cx, cy, size=1.0):
    s = size
    # outer blast
    glow(img, cx, cy, int(100*s), (255, 120, 0), layers=8)
    glow(img, cx, cy, int(50*s), (255, 220, 50), layers=6)
    lay = Image.new("RGBA", (W, H), (0,0,0,0))
    ld = ImageDraw.Draw(lay)
    # core white
    ld.ellipse([cx-int(30*s), cy-int(30*s), cx+int(30*s), cy+int(30*s)],
               fill=(255, 255, 220, 250))
    # rays
    for ri in range(12):
        rang = math.radians(ri * 30)
        rlen = random.randint(int(70*s), int(130*s))
        ex3 = cx + int(math.cos(rang)*rlen)
        ey3 = cy + int(math.sin(rang)*rlen)
        col_ray = random.choice([(255,180,0),(255,100,0),(255,220,50)])
        ld.line([(cx,cy),(ex3,ey3)], fill=col_ray+(200,), width=random.randint(3,8))
    # smoke wisps
    for si in range(8):
        sang = math.radians(si*45 + 15)
        sr2 = random.randint(int(80*s), int(140*s))
        ld.ellipse([cx+int(math.cos(sang)*sr2)-int(20*s), cy+int(math.sin(sang)*sr2)-int(20*s),
                    cx+int(math.cos(sang)*sr2)+int(20*s), cy+int(math.sin(sang)*sr2)+int(20*s)],
                   fill=(80,80,70,160))
    img.alpha_composite(lay)

draw_explosion(img, 720, 260, size=1.4)
draw_explosion(img, 280, 320, size=0.9)
draw_explosion(img, 1180, 300, size=1.0)

# BLOB CHARACTERS
def draw_blob(img, cx, cy, col, size=1.0, angry=True, has_bazooka=False, direction=1):
    lay = Image.new("RGBA", (W, H), (0,0,0,0))
    ld = ImageDraw.Draw(lay)
    s = size

    # glow aura
    for gi3 in range(4):
        gr3 = int((60+gi3*15)*s)
        ga3 = 40 - gi3*8
        ld.ellipse([cx-gr3, cy-gr3, cx+gr3, cy+gr3], fill=col+(ga3,))

    # body
    br = int(55*s)
    pts_body = []
    for ang3 in range(0, 360, 15):
        r3 = br + random.randint(-int(6*s), int(6*s))
        bx5 = cx + int(math.cos(math.radians(ang3))*r3)
        by5 = cy + int(math.sin(math.radians(ang3))*r3)
        pts_body.append((bx5, by5))
    ld.polygon(pts_body, fill=col+(235,))

    # highlight
    ld.ellipse([cx-int(25*s), cy-int(30*s), cx-int(5*s), cy-int(12*s)],
               fill=(255,255,255,80))

    if angry:
        # ANGRY EYES — slanted, glowing
        for ex_off, slant in [(-int(22*s), -1), (int(22*s), 1)]:
            ex4 = cx + ex_off; ey4 = cy - int(18*s)
            # eye white
            ld.ellipse([ex4-int(14*s), ey4-int(10*s), ex4+int(14*s), ey4+int(10*s)],
                       fill=(255,255,255,240))
            # angry brow
            brow_x1 = ex4 - int(16*s)
            brow_x2 = ex4 + int(16*s)
            brow_y = ey4 - int(12*s) + slant*int(8*s)
            ld.line([(brow_x1, brow_y+slant*int(6*s)), (brow_x2, brow_y-slant*int(6*s))],
                    fill=(0,0,0,255), width=int(5*s))
            # pupil (red glowing)
            ld.ellipse([ex4-int(7*s), ey4-int(5*s), ex4+int(7*s), ey4+int(5*s)],
                       fill=(220,30,30,255))
            ld.ellipse([ex4-int(3*s), ey4-int(3*s), ex4+int(3*s), ey4+int(3*s)],
                       fill=(0,0,0,255))
            # glow ring
            ld.arc([ex4-int(14*s), ey4-int(10*s), ex4+int(14*s), ey4+int(10*s)],
                   0, 360, fill=(255,60,60,200), width=2)

        # gritted teeth / snarl
        for ti2 in range(4):
            tx5 = cx - int(18*s) + ti2*int(12*s)
            ty5 = cy + int(10*s)
            ld.rectangle([tx5, ty5, tx5+int(9*s), ty5+int(12*s)], fill=(240,240,240,230))
            ld.rectangle([tx5, ty5, tx5+int(9*s), ty5+int(2*s)], fill=(180,180,180,200))
    else:
        # normal eyes
        for ex_off in [-int(18*s), int(18*s)]:
            ex4 = cx + ex_off; ey4 = cy - int(15*s)
            ld.ellipse([ex4-int(10*s), ey4-int(8*s), ex4+int(10*s), ey4+int(8*s)],
                       fill=(40,40,40,255))
            ld.ellipse([ex4-int(3*s), ey4-int(3*s), ex4+int(3*s), ey4+int(3*s)],
                       fill=(255,255,255,200))

    # BAZOOKA
    if has_bazooka:
        baz_dir = direction
        arm_x = cx + int(45*s)*baz_dir
        arm_y = cy + int(5*s)
        baz_len = int(100*s)
        # tube
        ld.line([(arm_x, arm_y), (arm_x + baz_len*baz_dir, arm_y)],
                fill=(60,60,70,255), width=int(18*s))
        # muzzle (normalised so x0 <= x1)
        mx0 = arm_x + baz_len*baz_dir - int(5*s)*baz_dir
        mx1 = arm_x + baz_len*baz_dir + int(8*s)*baz_dir
        if mx0 > mx1: mx0, mx1 = mx1, mx0
        ld.rectangle([mx0, arm_y-int(12*s), mx1, arm_y+int(12*s)], fill=(40,40,50,255))
        # sight on top (normalised)
        sx0 = arm_x + int(30*s)*baz_dir
        sx1 = arm_x + int(50*s)*baz_dir
        if sx0 > sx1: sx0, sx1 = sx1, sx0
        ld.rectangle([sx0, arm_y-int(22*s), sx1, arm_y-int(14*s)], fill=(80,80,90,255))
        # muzzle flash
        glow(img, arm_x+int((baz_len+15)*s)*baz_dir, arm_y, int(20*s), (255,180,0), layers=3)
    img.alpha_composite(lay)

# place blobs
draw_blob(img, 220, 440, (60,180,60), size=1.1, angry=True, has_bazooka=True, direction=1)
draw_blob(img, 1200, 430, (60,80,220), size=1.0, angry=True, has_bazooka=True, direction=-1)
draw_blob(img, 550, 490, (200,80,60), size=0.75, angry=True)
draw_blob(img, 900, 480, (180,60,200), size=0.75, angry=True)

# rocket between blobs
lay_rocket = Image.new("RGBA", (W, H), (0,0,0,0))
ld_rocket = ImageDraw.Draw(lay_rocket)
# rocket body
ld_rocket.ellipse([580, 350, 670, 390], fill=(220,60,60,240))
ld_rocket.polygon([(670,365),(700,355),(700,385)], fill=(240,180,50,240))  # nose
# exhaust
for ei in range(6):
    ld_rocket.ellipse([558-ei*12, 358+ei*2, 582-ei*12, 382-ei*2],
                      fill=(255,150,0,200-ei*30))
img.alpha_composite(lay_rocket)

# comic-book BOOM text
boom_f = get_font(110)
d.text((582, 130), "BOOM!", font=boom_f, fill=(0,0,0,200))
d.text((580, 128), "BOOM!", font=boom_f, fill=(255,220,50,255))
d.text((180, 200), "FIRE!", font=get_font(70), fill=(255,100,0,220))

add_title(img, "BITOCHI BLOBS", "Artillery chaos — aim & destroy", (80, 255, 100))
save(img, "blobs_hero.png")


# ══════════════════════════════════════════════════════════════════════════════
# BOXING — improved, intense boxing scene
# ══════════════════════════════════════════════════════════════════════════════
print("boxing_hero.png")
img = Image.new("RGBA", (W, H))
grad_bg(img, (15, 5, 5), (50, 10, 10))
d = ImageDraw.Draw(img)

# boxing ring ropes
rope_y = [160, 260, 360]
for ry in rope_y:
    for segment in range(0, W, 80):
        sag = int(math.sin(segment*0.05)*4)
        d.line([(segment, ry+sag), (min(segment+82, W), ry + int(math.sin((segment+82)*0.05)*4))],
               fill=(220, 60, 60, 200), width=5)
# ring posts
for px5 in [100, W-100]:
    d.rectangle([px5-8, 100, px5+8, H-100], fill=(200,180,140,255))
    d.ellipse([px5-16, 95, px5+16, 130], fill=(220,200,160,255))

# crowd silhouettes (background)
for ci2 in range(80):
    cx3 = random.randint(0, W)
    cy3 = random.randint(520, 660)
    cr2 = random.randint(12, 22)
    lay = Image.new("RGBA", (W, H), (0,0,0,0))
    ld = ImageDraw.Draw(lay)
    ld.ellipse([cx3-cr2, cy3-cr2, cx3+cr2, cy3+cr2], fill=(30,20,20,180))
    ld.ellipse([cx3-cr2//2, cy3-cr2-cr2//2, cx3+cr2//2, cy3-cr2//2], fill=(30,20,20,150))
    img.alpha_composite(lay)

# spotlight
glow(img, W//2, H//2, 300, (255,200,100), layers=6)

# FIGHTER LEFT — red corner, punching
def draw_boxer(img, cx, cy, col_shorts, direction=1, punching=False, size=1.0):
    lay = Image.new("RGBA", (W, H), (0,0,0,0))
    ld = ImageDraw.Draw(lay)
    s = size
    skin = (220, 170, 120, 255)
    glove_col = col_shorts

    # legs
    leg_splay = int(25*s)
    for lx, ldir in [(-leg_splay, -1), (leg_splay, 1)]:
        ld.polygon([(cx+lx-int(16*s), cy+int(100*s)),
                    (cx+lx+int(16*s), cy+int(100*s)),
                    (cx+lx+int(12*s)*ldir, cy+int(200*s)),
                    (cx+lx-int(12*s)*ldir, cy+int(200*s))],
                   fill=col_shorts+(240,))
        # shoes
        ld.ellipse([cx+lx-int(20*s), cy+int(188*s), cx+lx+int(20*s), cy+int(215*s)],
                   fill=(30,30,30,255))

    # torso
    ld.polygon([(cx-int(40*s), cy), (cx+int(40*s), cy),
                (cx+int(32*s), cy+int(100*s)), (cx-int(32*s), cy+int(100*s))],
               fill=skin)
    # shorts
    ld.polygon([(cx-int(35*s), cy+int(70*s)), (cx+int(35*s), cy+int(70*s)),
                (cx+int(32*s), cy+int(100*s)), (cx-int(32*s), cy+int(100*s))],
               fill=col_shorts+(255,))
    # belt stripe
    ld.rectangle([cx-int(35*s), cy+int(68*s), cx+int(35*s), cy+int(76*s)],
                 fill=(255,255,255,200))

    # arms
    if punching:
        # extended punch arm
        punch_dir = direction
        ld.polygon([(cx+int(35*s)*punch_dir, cy+int(20*s)),
                    (cx+int(35*s)*punch_dir, cy+int(50*s)),
                    (cx+int(130*s)*punch_dir, cy+int(35*s)),
                    (cx+int(130*s)*punch_dir, cy+int(20*s))],
                   fill=skin)
        # glove (big fist)
        gx5 = cx+int(130*s)*punch_dir; gy5 = cy+int(27*s)
        ld.ellipse([gx5-int(28*s), gy5-int(20*s), gx5+int(28*s), gy5+int(28*s)],
                   fill=glove_col+(255,))
        # glove highlight
        ld.arc([gx5-int(22*s), gy5-int(16*s), gx5+int(22*s), gy5+int(22*s)],
               start=200, end=320, fill=(255,255,255,120), width=4)
        # guard arm (bent)
        ld.polygon([(cx-int(35*s)*punch_dir, cy+int(20*s)),
                    (cx-int(35*s)*punch_dir, cy+int(55*s)),
                    (cx-int(10*s)*punch_dir, cy+int(65*s)),
                    (cx-int(10*s)*punch_dir, cy+int(30*s))],
                   fill=skin)
        ld.ellipse([cx-int(25*s)*punch_dir-int(22*s), cy+int(45*s),
                    cx-int(25*s)*punch_dir+int(22*s), cy+int(90*s)],
                   fill=glove_col+(255,))
    else:
        # guard stance
        for arm_dir in [-1, 1]:
            ld.polygon([(cx+int(30*s)*arm_dir, cy+int(20*s)),
                        (cx+int(30*s)*arm_dir, cy+int(55*s)),
                        (cx+int(55*s)*arm_dir, cy+int(65*s)),
                        (cx+int(55*s)*arm_dir, cy+int(30*s))],
                       fill=skin)
            ld.ellipse([cx+int(40*s)*arm_dir-int(22*s), cy+int(45*s),
                        cx+int(40*s)*arm_dir+int(22*s), cy+int(90*s)],
                       fill=glove_col+(255,))

    # neck
    ld.rectangle([cx-int(12*s), cy-int(20*s), cx+int(12*s), cy], fill=skin)
    # HEAD
    ld.ellipse([cx-int(38*s), cy-int(85*s), cx+int(38*s), cy-int(15*s)], fill=skin)
    # headgear
    ld.arc([cx-int(40*s), cy-int(88*s), cx+int(40*s), cy-int(40*s)],
           start=180, end=360, fill=col_shorts+(230,), width=int(14*s))
    ld.rectangle([cx-int(40*s), cy-int(68*s), cx-int(26*s), cy-int(40*s)],
                 fill=col_shorts+(230,))
    ld.rectangle([cx+int(26*s), cy-int(68*s), cx+int(40*s), cy-int(40*s)],
                 fill=col_shorts+(230,))
    # face
    ld.ellipse([cx-int(8*s), cy-int(65*s), cx-int(2*s), cy-int(55*s)], fill=(40,40,40,220))
    ld.ellipse([cx+int(2*s), cy-int(65*s), cx+int(8*s), cy-int(55*s)], fill=(40,40,40,220))
    # mouthguard
    ld.rectangle([cx-int(12*s), cy-int(38*s), cx+int(12*s), cy-int(26*s)],
                 fill=(240,240,240,230))

    img.alpha_composite(lay)

draw_boxer(img, 420, 280, (200,30,30), direction=1, punching=True, size=1.15)
draw_boxer(img, 1020, 280, (30,30,200), direction=-1, punching=False, size=1.1)

# impact flash / stars
glow(img, 720, 310, 60, (255, 230, 50), layers=6)
lay_impact = Image.new("RGBA", (W, H), (0,0,0,0))
ld_impact = ImageDraw.Draw(lay_impact)
for star_i in range(8):
    sang2 = math.radians(star_i * 45)
    sx3 = 720 + int(math.cos(sang2)*70)
    sy3 = 310 + int(math.sin(sang2)*50)
    ld_impact.text((sx3-10, sy3-10), "✦", font=get_font(28), fill=(255,220,50,220))
# POW!
ld_impact.text((653, 195), "POW!", font=get_font(80), fill=(0,0,0,220))
ld_impact.text((650, 192), "POW!", font=get_font(80), fill=(255,60,60,255))
img.alpha_composite(lay_impact)

# sweat drops
for sx4, sy4 in [(360,250),(400,210),(1060,230),(1090,260)]:
    lay = Image.new("RGBA", (W, H), (0,0,0,0))
    ld = ImageDraw.Draw(lay)
    ld.ellipse([sx4-4, sy4-4, sx4+4, sy4+8], fill=(150,200,255,180))
    img.alpha_composite(lay)

add_title(img, "BITOCHI BOXING", "Step in the ring. Hit first.", (255, 80, 80))
save(img, "boxing_hero.png")

print("\nAll done.")
