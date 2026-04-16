#!/usr/bin/env python3
"""
Generate launcher_icon.png (40x40 RGBA) and _hero.png (1440x720 RGB)
for Dive Gas & Planning Toolkit.
"""

from PIL import Image, ImageDraw, ImageFont
import math, os

OUT_ICON = "/Users/kkorolczuk/work/garmin/diveplantoolkit/resources/launcher_icon.png"
OUT_HERO = "/Users/kkorolczuk/work/garmin/_LOGOS/diveplantoolkit_hero.png"


# ── Launcher icon (40 × 40 RGBA) ─────────────────────────────────────────────

def make_icon():
    W, H = 40, 40
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d   = ImageDraw.Draw(img)

    # Deep ocean background — circular
    cx, cy, r = W//2, H//2, W//2 - 1
    for y in range(H):
        for x in range(W):
            if (x - cx)**2 + (y - cy)**2 <= r**2:
                # gradient: dark navy at top → deep teal at bottom
                t = y / H
                rb = int(4  + t * 4)
                gb = int(12 + t * 30)
                bb = int(40 + t * 50)
                img.putpixel((x, y), (rb, gb, bb, 255))

    # Circular border
    d.ellipse([1, 1, W-2, H-2], outline=(30, 120, 180, 220), width=1)

    # Depth gauge — outer arc ring
    d.arc([5, 5, W-6, H-6], start=-200, end=20, fill=(60, 160, 220, 200), width=2)

    # Gauge needle pointing to ~30m (roughly 45° into arc)
    angle = math.radians(-75)
    nx = cx + int(12 * math.cos(angle))
    ny = cy + int(12 * math.sin(angle))
    d.line([cx, cy, nx, ny], fill=(255, 80, 60, 255), width=1)

    # Centre dot
    d.ellipse([cx-2, cy-2, cx+2, cy+2], fill=(255, 255, 255, 220))

    # "m" text at top-centre (depth unit)
    d.text((cx, 5), "m", fill=(160, 210, 255, 220), anchor="mt")

    # Tiny bubbles bottom-right
    for bx, by, br in [(30, 32, 1), (32, 28, 1), (34, 33, 1)]:
        d.ellipse([bx-br, by-br, bx+br, by+br], outline=(100, 200, 255, 180), width=1)

    img.save(OUT_ICON)
    print(f"Icon saved: {OUT_ICON}")


# ── Hero image (1440 × 720 RGB) ───────────────────────────────────────────────

def make_hero():
    W, H = 1440, 720
    img = Image.new("RGB", (W, H), (4, 8, 20))
    d   = ImageDraw.Draw(img)

    # Underwater gradient background
    for y in range(H):
        t  = y / H
        r  = int(4  + t * 8)
        g  = int(8  + t * 40)
        b  = int(20 + t * 60)
        d.line([(0, y), (W, y)], fill=(r, g, b))

    # Caustic light rays
    for i in range(12):
        ox  = int(W * (0.2 + 0.6 * i / 11))
        ray = [(ox, 0), (ox - 40, H//2), (ox + 40, H//2)]
        d.polygon(ray, fill=(20, 60, 100, 30))

    # Left panel — large PO2 readout
    px, py = 200, 160
    d.rectangle([px-10, py-10, px+340, py+200], fill=(8, 20, 45))
    d.text((px, py),      "PO2",     fill=(80, 160, 220))
    d.text((px, py+50),   "1.28",    fill=(0, 200, 80))
    d.text((px, py+120),  "SAFE",    fill=(0, 200, 80))
    d.text((px, py+160),  "MOD: 33m", fill=(160, 200, 220))

    # Centre — app title
    d.text((W//2, H//3), "DIVE",      fill=(50, 150, 220), anchor="mm")
    d.text((W//2, H//3 + 80), "PLANNING TOOLKIT", fill=(100, 180, 240), anchor="mm")
    d.text((W//2, H//3 + 140), "Gas · NDL · SAC · EAD · Best Mix",
           fill=(80, 130, 170), anchor="mm")

    # Right panel — NDL readout
    rx, ry = W - 520, 160
    d.rectangle([rx-10, ry-10, rx+320, ry+200], fill=(8, 20, 45))
    d.text((rx, ry),      "NDL",         fill=(80, 160, 220))
    d.text((rx, ry+50),   "29min",       fill=(0, 200, 80))
    d.text((rx, ry+120),  "Nitrox 32",   fill=(160, 200, 220))
    d.text((rx, ry+160),  "25m depth",   fill=(130, 170, 200))

    # Bottom disclaimer band
    d.rectangle([0, H-60, W, H], fill=(5, 15, 35))
    d.text((W//2, H-30),
           "Not a dive computer · For planning purposes only",
           fill=(60, 90, 120), anchor="mm")

    img.save(OUT_HERO)
    print(f"Hero saved: {OUT_HERO}")


if __name__ == "__main__":
    make_icon()
    make_hero()
    print("Done.")
