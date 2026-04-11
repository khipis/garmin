#!/usr/bin/env python3
"""Generate minigolf launcher_icon.png (40×40) and minigolf_hero.png (1440×720)."""
from PIL import Image, ImageDraw, ImageFont
import os, math

BASE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(BASE)

def circle_crop(img):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).ellipse([0, 0, img.size[0]-1, img.size[1]-1], fill=255)
    img.putalpha(mask)
    return img

# ── Launcher icon ─────────────────────────────────────────────────────────────
def make_icon():
    img = Image.new("RGBA", (40, 40), (0,0,0,0))
    d = ImageDraw.Draw(img)
    d.ellipse([0,0,39,39], fill=(14,50,22,255))
    d.ellipse([2,2,37,37], fill=(22,90,40,255))
    # Fairway rough border
    d.rounded_rectangle([5,5,34,34], radius=6, fill=(18,70,32), outline=(30,110,55), width=1)
    # Hole cup
    d.ellipse([22,22,30,30], fill=(5,10,5))
    d.ellipse([23,22,30,29], outline=(50,80,50), width=1)
    # Flag
    d.line([(26,22),(26,10)], fill=(140,100,50), width=1)
    d.polygon([(26,10),(34,13),(26,16)], fill=(220,40,20))
    # Ball
    d.ellipse([7,22,17,32], fill=(240,240,240))
    d.ellipse([9,23,13,27], fill=(255,255,255))  # gloss
    return circle_crop(img)

# ── Hero image ────────────────────────────────────────────────────────────────
def make_hero():
    W, H = 1440, 720
    img = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(img)
    # Sky gradient
    for y in range(H):
        t = y/H
        r = int(20+t*5); g = int(40+t*15); b = int(20+t*5)
        d.line([(0,y),(W,y)], fill=(r,g,b))

    # Course
    bx, by, bw, bh = W//2-420, H//2-200, 840, 420
    # Green
    d.rounded_rectangle([bx-10,by-10,bx+bw+10,by+bh+10], radius=30, fill=(12,38,18))
    d.rounded_rectangle([bx,by,bx+bw,by+bh], radius=20, fill=(25,115,55))
    # Fairway stripe
    for i in range(0, bw, 60):
        c = (30,130,60) if (i//60)%2==0 else (22,105,48)
        d.rectangle([bx+i,by,bx+i+60,by+bh], fill=c)
    d.rounded_rectangle([bx,by,bx+bw,by+bh], radius=20, outline=(15,60,30), width=3)

    # Water hazard
    d.ellipse([bx+380,by+160,bx+520,by+270], fill=(20,80,180))
    d.ellipse([bx+382,by+162,bx+518,by+268], outline=(40,130,220), width=2)

    # Obstacle blocks
    for ox,oy,ow,oh in [(bx+180,by+120,40,90),(bx+660,by+210,40,90)]:
        d.rounded_rectangle([ox,oy,ox+ow,oy+oh], radius=5, fill=(100,65,35))
        d.rounded_rectangle([ox,oy,ox+ow,oy+oh], radius=5, outline=(140,90,50), width=2)

    # Hole cup + flag
    hx, hy = bx+bw-100, by+bh//2
    d.ellipse([hx-18,hy-18,hx+18,hy+18], fill=(5,10,4))
    d.ellipse([hx-16,hy-16,hx+16,hy+16], outline=(40,80,40), width=2)
    d.line([(hx,hy),(hx,hy-100)], fill=(140,100,50), width=3)
    d.polygon([(hx,hy-100),(hx+40,hy-85),(hx,hy-70)], fill=(220,40,20))

    # Ball
    bsx, bsy = bx+100, by+bh//2
    d.ellipse([bsx-18,bsy-18,bsx+18,bsy+18], fill=(0,0,0,100))
    d.ellipse([bsx-18,bsy-20,bsx+18,bsy+18], fill=(240,240,240))
    d.ellipse([bsx-8,bsy-12,bsx+2,bsy], fill=(255,255,255))

    # Aim arrow
    ex, ey = bsx+80, bsy
    for i in range(3):
        c = (255,220,50,180-i*50)
        d.line([(bsx+i*2,bsy),(ex+i*2,ey)], fill=(255,220,50), width=3-i)
    d.polygon([(ex,ey),(ex-14,ey-8),(ex-14,ey+8)], fill=(255,220,50))

    # Title
    try:
        tf = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 80)
        sf = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 36)
    except:
        tf = sf = ImageFont.load_default()
    title = "BITOCHI MINIGOLF"
    for dx in range(-3,4):
        for dy in range(-3,4):
            d.text((W//2-240+dx, H*5//100+dy), title, font=tf, fill=(0,0,0))
    d.text((W//2-240, H*5//100), title, font=tf, fill=(68,255,140))
    d.text((W//2-220, H*18//100), "9 holes  ·  Aim, power & shoot  ·  3 difficulties",
           font=sf, fill=(160,220,160))

    path = os.path.join(BASE, "minigolf_hero.png")
    img.save(path)
    print(f"  saved {path}  {img.size}")

print("Generating minigolf assets…")
icon = make_icon()
icon_path = os.path.join(ROOT, "minigolf", "resources", "launcher_icon.png")
icon.save(icon_path)
print(f"  saved {icon_path}  {icon.size}")
make_hero()
print("Done.")
