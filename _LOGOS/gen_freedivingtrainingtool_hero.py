#!/usr/bin/env python3
"""Generate 1440x720 hero image for Freediving Training Tool."""

from PIL import Image, ImageDraw, ImageFont
import os, math

W, H = 1440, 720
OUT = os.path.dirname(os.path.abspath(__file__))

def get_font(size):
    for p in ["/System/Library/Fonts/Helvetica.ttc",
              "/System/Library/Fonts/SFNSMono.ttf",
              "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"]:
        if os.path.exists(p):
            try: return ImageFont.truetype(p, size)
            except: pass
    return ImageFont.load_default()

def gradient_bg(draw, c1, c2):
    for y in range(H):
        t = y / H
        r = int(c1[0]*(1-t) + c2[0]*t)
        g = int(c1[1]*(1-t) + c2[1]*t)
        b = int(c1[2]*(1-t) + c2[2]*t)
        draw.line([(0,y),(W,y)], fill=(r,g,b))

def vignette(img, strength=80):
    v = Image.new('RGBA', img.size, (0,0,0,0))
    vd = ImageDraw.Draw(v)
    cx, cy = img.size[0]//2, img.size[1]//2
    maxR = math.sqrt(cx*cx + cy*cy)
    for ring in range(int(maxR), 0, -3):
        a = int(strength * max(0, (ring/maxR - 0.5)*2)**2)
        if a > 0:
            vd.ellipse([cx-ring, cy-ring, cx+ring, cy+ring], fill=(0,0,0,a))
    return Image.alpha_composite(img.convert('RGBA'), v)

def gen():
    img = Image.new('RGB', (W,H), (0,0,0))
    draw = ImageDraw.Draw(img)
    gradient_bg(draw, (0,8,20), (0,0,0))

    cx = W // 2

    # Breathing circle animation (left side)
    bcx, bcy = 300, 260
    for ring_r in range(120, 60, -1):
        a = int(255 * (ring_r - 60) / 60)
        col = (0, int(136*a/255), int(204*a/255))
        draw.ellipse([bcx-ring_r, bcy-ring_r, bcx+ring_r, bcy+ring_r], outline=col)
    draw.ellipse([bcx-55, bcy-55, bcx+55, bcy+55], fill=(0,80,120))
    draw.text((bcx, bcy-14), "4s", fill=(255,255,255), font=get_font(36), anchor="mt")
    draw.text((bcx, bcy+18), "INHALE", fill=(170,220,255), font=get_font(16), anchor="mt")

    # Static apnea timer (center)
    acx, acy = 660, 230
    draw.text((acx, acy-80), "HOLD", fill=(34,204,85), font=get_font(20), anchor="mt")
    draw.text((acx, acy-52), "2:47", fill=(34,204,85), font=get_font(80), anchor="mt")
    arcR = 100
    draw.ellipse([acx-arcR, acy-arcR+20, acx+arcR, acy+arcR+20], outline=(26,48,64))
    pct = 270
    draw.arc([acx-arcR, acy-arcR+20, acx+arcR, acy+arcR+20], -90, -90+pct, fill=(34,204,85), width=3)
    draw.text((acx, acy+arcR+30), "PB 3:15", fill=(26,48,64), font=get_font(16), anchor="mt")

    # CO2/O2 Table (right side)
    tcx, tcy = 1060, 230
    draw.text((tcx, tcy-110), "CO2 TABLE", fill=(0,136,204), font=get_font(18), anchor="mt")
    arcR2 = 90
    draw.ellipse([tcx-arcR2, tcy-arcR2, tcx+arcR2, tcy+arcR2], outline=(51,51,51))
    draw.arc([tcx-arcR2, tcy-arcR2, tcx+arcR2, tcy+arcR2], -90, 120, fill=(0,170,136), width=3)
    draw.text((tcx, tcy-30), "HOLD", fill=(0,170,136), font=get_font(16), anchor="mt")
    draw.text((tcx, tcy-8), "0:48", fill=(0,170,136), font=get_font(44), anchor="mt")
    draw.text((tcx, tcy+55), "Round 4/8", fill=(51,51,51), font=get_font(14), anchor="mt")

    # 4-mode menu items
    modes = [
        ("BREATHE", (0,136,204)),
        ("STATIC APNEA", (34,204,85)),
        ("CO2 TABLE", (0,170,136)),
        ("O2 TABLE", (102,68,187)),
    ]
    y = 420
    for i, (m, c) in enumerate(modes):
        x = 160 + i * 310
        draw.rounded_rectangle([x, y, x+260, y+50], radius=8, fill=(12,12,12), outline=c)
        draw.text((x+130, y+14), m, fill=c, font=get_font(22), anchor="mt")

    # Decorative bubbles
    bubbles = [(80,130,6), (140,80,4), (1340,160,5), (1380,100,3),
               (180,420,3), (1300,440,4), (520,40,5), (900,60,3)]
    for bx, by, br in bubbles:
        draw.ellipse([bx-br, by-br, bx+br, by+br], outline=(0,50,80))

    # Title bar
    barH = 100
    barY = H - barH
    draw.rectangle([0, barY, W, H], fill=(0,0,0))
    draw.line([(0, barY), (W, barY)], fill=(0,136,204), width=3)
    f_title = get_font(42)
    f_sub = get_font(20)
    draw.text((cx, barY+18), "FREEDIVING TRAINING TOOL", fill=(255,255,255), font=f_title, anchor="mt")
    draw.text((cx, barY+68), "Breathe  /  Static Apnea  /  CO2 Table  /  O2 Table  /  Haptic cues",
              fill=(0,136,204), font=f_sub, anchor="mt")

    img = vignette(img)
    final = img.convert('RGB')
    out = os.path.join(OUT, "freedivingtrainingtool_hero.png")
    final.save(out, "PNG")
    print(f"  -> {out}")

if __name__ == "__main__":
    print("Generating freedivingtrainingtool hero image...")
    gen()
    print("Done!")
