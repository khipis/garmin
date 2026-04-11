#!/usr/bin/env python3
"""Generate JazzBall launcher_icon.png (40×40) and jazzball_hero.png (1440×720)."""
from PIL import Image, ImageDraw, ImageFont
import os, math

BASE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(BASE)

def circle_crop(img):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).ellipse([0, 0, img.size[0]-1, img.size[1]-1], fill=255)
    img.putalpha(mask)
    return img

def draw_ball(d, cx, cy, r, color):
    d.ellipse([cx-r+1, cy-r+2, cx+r+1, cy+r+2], fill=(0,0,0,100))
    d.ellipse([cx-r, cy-r, cx+r, cy+r], fill=color)
    d.ellipse([cx-r//2, cy-r//2, cx, cy], fill=(255,255,255,140))

# ── Launcher icon ─────────────────────────────────────────────────────────────
def make_icon():
    img = Image.new("RGBA", (40, 40), (0,0,0,0))
    d = ImageDraw.Draw(img)
    # Dark field
    d.ellipse([0,0,39,39], fill=(8,12,24,255))
    d.ellipse([2,2,37,37], fill=(12,18,36,255))
    # Filled wall area (top-right quadrant)
    d.rectangle([20,2,37,19], fill=(42,60,102,220))
    # Wall lines
    d.line([(20,2),(20,37)], fill=(68,136,204), width=1)
    d.line([(2,20),(37,20)], fill=(255,220,80), width=1)
    # Balls
    draw_ball(d, 10, 10, 5, (255, 68, 34))
    draw_ball(d, 28, 28, 5, (68, 255, 136))
    draw_ball(d, 12, 30, 4, (255, 180, 50))
    return circle_crop(img)

# ── Hero image ────────────────────────────────────────────────────────────────
def make_hero():
    W, H = 1440, 720
    img = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(img)
    # Background
    for y in range(H):
        t = y/H
        d.line([(0,y),(W,y)], fill=(int(6+t*6), int(8+t*12), int(18+t*20)))

    # Game field
    fx, fy, fw, fh = 320, 60, 800, 600
    d.rectangle([fx-4,fy-4,fx+fw+4,fy+fh+4], fill=(15,22,44))
    d.rectangle([fx,fy,fx+fw,fy+fh], fill=(10,14,28))

    # Filled area (top-right ~40%)
    d.rectangle([fx+fw//2,fy,fx+fw,fy+fh//2], fill=(42,60,102))
    d.rectangle([fx,fy,fx+fw//3,fy+fh], fill=(35,50,85))

    # Active growing wall (H) - cyan
    wy = fy + fh*2//3
    d.rectangle([fx+fw//4, wy-3, fx+fw*2//3, wy+3], fill=(68,200,240))

    # Active growing wall (V) - yellow
    vx = fx + fw//2 + 60
    d.rectangle([vx-3, fy+fh//3, vx+3, fy+fh*3//4], fill=(255,220,60))

    # Wall borders
    d.line([(fx+fw//2,fy),(fx+fw//2,fy+fh//2)], fill=(68,136,204,200), width=2)
    d.line([(fx,fy+fh//2),(fx+fw//2,fy+fh//2)], fill=(68,136,204,200), width=2)

    # Grid lines (subtle)
    cell = fw//30
    for i in range(31):
        dc = 30 if i % 5 == 0 else 18
        d.line([(fx+i*cell,fy),(fx+i*cell,fy+fh)], fill=(dc,dc+8,dc+20), width=1)
    cell2 = fh//30
    for i in range(31):
        dc = 30 if i % 5 == 0 else 18
        d.line([(fx,fy+i*cell2),(fx+fw,fy+i*cell2)], fill=(dc,dc+8,dc+20), width=1)

    # Balls
    balls = [
        (fx+120,fy+fh-200,18,(255,68,34)),
        (fx+350,fy+200,16,(255,140,0)),
        (fx+fw-200,fy+fh-150,18,(68,255,136)),
        (fx+fw-120,fy+300,16,(68,170,255)),
        (fx+200,fy+fh//2,15,(255,68,170)),
    ]
    for (bx,by,br,bc) in balls:
        d.ellipse([bx-br+2,by-br+3,bx+br+2,by+br+3], fill=(0,0,0,120))
        d.ellipse([bx-br,by-br,bx+br,by+br], fill=bc)
        d.ellipse([bx-br//2,by-br//2,bx,by], fill=(255,255,255,150))

    # Fill % badge
    d.rounded_rectangle([fx+fw+20, fy+40, fx+fw+220, fy+130], radius=12, fill=(20,30,60))
    d.rounded_rectangle([fx+fw+20, fy+40, fx+fw+220, fy+130], radius=12, outline=(68,136,204), width=2)

    # Title
    try:
        tf = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 80)
        sf = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 36)
    except:
        tf = sf = ImageFont.load_default()
    title = "BITOCHI JAZZBALL"
    for dx in range(-3,4):
        for dy in range(-3,4):
            d.text((W//2-250+dx, H*3//100+dy), title, font=tf, fill=(0,0,0))
    d.text((W//2-250, H*3//100), title, font=tf, fill=(68,170,255))
    d.text((W//2-230, H*16//100), "Draw walls · Trap balls · Cover 75% of the field",
           font=sf, fill=(140,180,220))

    path = os.path.join(BASE, "jazzball_hero.png")
    img.save(path)
    print(f"  saved {path}  {img.size}")

print("Generating JazzBall assets…")
icon = make_icon()
icon_path = os.path.join(ROOT, "jazzball", "resources", "launcher_icon.png")
icon.save(icon_path)
print(f"  saved {icon_path}  {icon.size}")
make_hero()
print("Done.")
