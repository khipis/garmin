#!/usr/bin/env python3
"""Generate checkers launcher_icon.png (40x40) and checkers_hero.png (1440x720)."""

from PIL import Image, ImageDraw, ImageFont
import os, math

BASE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(BASE)

def circle_crop(img):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).ellipse([0, 0, img.size[0]-1, img.size[1]-1], fill=255)
    img.putalpha(mask)
    return img

def draw_checker(d, cx, cy, r, white):
    # Shadow
    d.ellipse([cx-r+1, cy-r+2, cx+r+1, cy+r+2], fill=(0,0,0,120))
    # Outer ring
    ring = (238,153,85) if white else (170,34,0)
    d.ellipse([cx-r, cy-r, cx+r, cy+r], fill=ring)
    # Body
    body = (245,221,176) if white else (204,51,17)
    d.ellipse([cx-r+2, cy-r+2, cx+r-2, cy+r-2], fill=body)
    # Gloss
    gloss = (255,255,238,160) if white else (255,119,85,160)
    d.ellipse([cx-r//2, cy-r//2, cx, cy], fill=gloss)

# ── Launcher icon ─────────────────────────────────────────────────────────────
def make_icon():
    img = Image.new("RGBA", (40, 40), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Dark board
    d.ellipse([0,0,39,39], fill=(12, 8, 4, 255))
    # 2x2 checkerboard squares
    for row in range(4):
        for col in range(4):
            light = (row + col) % 2 == 0
            c = (212, 176, 119) if light else (122, 64, 32)
            d.rectangle([col*10, row*10, col*10+9, row*10+9], fill=c)
    # Two pieces
    draw_checker(d, 11, 28, 7, True)   # white bottom
    draw_checker(d, 28, 12, 7, False)  # black top
    return circle_crop(img)

# ── Hero image ────────────────────────────────────────────────────────────────
def make_hero():
    W, H = 1440, 720
    img = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(img)

    for y in range(H):
        t = y / H
        r = int(10 + t*8); g = int(6 + t*5); b = int(3 + t*3)
        d.line([(0,y),(W,y)], fill=(r,g,b))

    SQ = 70; BW = SQ*8; BH = SQ*8
    bx = W//2 - BW//2; by = H//2 - BH//2

    light = (212,176,119); dark = (122,64,32); border = (70,40,15)
    d.rectangle([bx-8,by-8,bx+BW+8,by+BH+8], fill=border)
    for row in range(8):
        for col in range(8):
            c = light if (row+col)%2==0 else dark
            d.rectangle([bx+col*SQ, by+row*SQ, bx+col*SQ+SQ-1, by+row*SQ+SQ-1], fill=c)

    # Starting position
    for row in range(8):
        for col in range(8):
            if (row+col)%2 == 0: continue  # only dark squares
            if row < 3:
                px = bx + col*SQ + SQ//2; py = by + (7-row)*SQ + SQ//2
                draw_checker(d, px, py, SQ*38//100, True)
            elif row > 4:
                px = bx + col*SQ + SQ//2; py = by + (7-row)*SQ + SQ//2
                draw_checker(d, px, py, SQ*38//100, False)

    # Title
    try:
        tf = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 72)
        sf = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 36)
    except:
        tf = sf = ImageFont.load_default()

    title = "BITOCHI CHECKERS"
    for dx in range(-3,4):
        for dy in range(-3,4):
            d.text((W//2-230+dx, H*6//100+dy), title, font=tf, fill=(0,0,0))
    d.text((W//2-230, H*6//100), title, font=tf, fill=(255,102,51))
    d.text((W//2-200, H*18//100), "Play checkers vs AI  ·  Easy / Normal / Hard", font=sf, fill=(180,140,100))

    path = os.path.join(BASE, "checkers_hero.png")
    img.save(path)
    print(f"  saved {path}  {img.size}")

print("Generating checkers assets…")
icon = make_icon()
icon_path = os.path.join(ROOT, "checkers", "resources", "launcher_icon.png")
icon.save(icon_path)
print(f"  saved {icon_path}  {icon.size}")
make_hero()
print("Done.")
