#!/usr/bin/env python3
"""
Generate launcher_icon.png (40x40 RGBA) and hero (1440x720 RGB)
for Emergency Dive Quick Calculator.
"""

from PIL import Image, ImageDraw
import math

OUT_ICON = "/Users/kkorolczuk/work/garmin/quickdivecalculator/resources/launcher_icon.png"
OUT_HERO = "/Users/kkorolczuk/work/garmin/_LOGOS/quickdivecalculator_hero.png"


def make_icon():
    W, H = 40, 40
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d   = ImageDraw.Draw(img)
    cx, cy, r = W // 2, H // 2, W // 2 - 1

    # Deep dark base
    for y in range(H):
        for x in range(W):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r ** 2:
                img.putpixel((x, y), (4, 8, 18, 255))

    d.ellipse([1, 1, W - 2, H - 2], outline=(40, 130, 220, 160), width=1)

    # Split: left half green (SAFE), right half red (DANGER)
    # Left semicircle fill
    for y in range(H):
        for x in range(W // 2):
            if (x - cx) ** 2 + (y - cy) ** 2 <= (r - 2) ** 2:
                img.putpixel((x, y), (4, 30, 10, 255))
    # Right semicircle fill
    for y in range(H):
        for x in range(W // 2, W):
            if (x - cx) ** 2 + (y - cy) ** 2 <= (r - 2) ** 2:
                img.putpixel((x, y), (28, 4, 4, 255))

    # Vertical divider
    d.line([cx, 4, cx, H - 4], fill=(60, 90, 120, 200), width=1)

    # Left: "OK" check mark
    d.line([7, cy, 12, cy + 5], fill=(0, 200, 60, 230), width=2)
    d.line([12, cy + 5, 18, cy - 4], fill=(0, 200, 60, 230), width=2)

    # Right: "X" mark
    d.line([cx + 4, cy - 4, cx + 14, cy + 4], fill=(220, 40, 40, 230), width=2)
    d.line([cx + 14, cy - 4, cx + 4, cy + 4], fill=(220, 40, 40, 230), width=2)

    # "m" depth unit at top (tiny)
    d.text((cx, 3), "m", fill=(100, 160, 220, 200), anchor="mt")

    img.save(OUT_ICON)
    print(f"Icon saved: {OUT_ICON}")


def make_hero():
    W, H = 1440, 720
    img = Image.new("RGB", (W, H), (4, 8, 18))
    d   = ImageDraw.Draw(img)

    # Background gradient
    for y in range(H):
        t = y / H
        d.line([(0, y), (W, y)], fill=(int(4+t*6), int(8+t*14), int(18+t*28)))

    # Left half — SAFE state (green tint)
    for y in range(H):
        for x in range(W // 2):
            px = img.getpixel((x, y))
            img.putpixel((x, y), (px[0], min(255, px[1] + 10), px[2]))

    # Right half — DANGER state (red tint)
    for y in range(H):
        for x in range(W // 2, W):
            px = img.getpixel((x, y))
            img.putpixel((x, y), (min(255, px[0] + 18), px[1], px[2]))

    # Centre divider
    d.line([(W // 2, 0), (W // 2, H)], fill=(40, 70, 110), width=2)

    # Left — SAFE example
    lx, ly = 220, 160
    d.rectangle([lx - 10, ly - 10, lx + 340, ly + 240], fill=(5, 20, 10))
    d.text((lx, ly),        "Nitrox 32 @ 30m", fill=(80, 160, 120))
    d.text((lx, ly + 55),   "PO2: 1.28",       fill=(0, 220, 80))
    # SAFE verdict box
    d.rectangle([lx, ly + 120, lx + 180, ly + 175], fill=(0, 180, 60))
    d.text((lx + 90, ly + 135), "SAFE", fill=(0, 0, 0), anchor="mt")
    d.text((lx, ly + 195),   "MOD 33m  NDL 31min", fill=(80, 150, 100))

    # Centre — title
    d.text((W // 2, H // 2 - 100), "EMERGENCY",            fill=(80, 160, 240), anchor="mm")
    d.text((W // 2, H // 2 - 20),  "DIVE QUICK CALC",      fill=(100, 180, 255), anchor="mm")
    d.text((W // 2, H // 2 + 60),  "Instant SAFE / WARNING / DANGER",
           fill=(60, 100, 150), anchor="mm")

    # Right — DANGER example
    rx, ry = W // 2 + 220, 160
    d.rectangle([rx - 10, ry - 10, rx + 340, ry + 240], fill=(20, 5, 5))
    d.text((rx, ry),        "Nitrox 36 @ 35m", fill=(160, 80, 80))
    d.text((rx, ry + 55),   "PO2: 1.62",       fill=(255, 40, 40))
    # DANGER verdict box
    d.rectangle([rx, ry + 120, rx + 220, ry + 175], fill=(200, 30, 30))
    d.text((rx + 110, ry + 135), "DANGER", fill=(0, 0, 0), anchor="mt")
    d.text((rx, ry + 195),   "EXCEEDS LIMIT", fill=(200, 80, 80))

    # Bottom
    d.rectangle([0, H - 50, W, H], fill=(4, 8, 18))
    d.text((W // 2, H - 25),
           "No menus · Live result · 2 pages · Gas Check + Best Mix",
           fill=(50, 80, 110), anchor="mm")

    img.save(OUT_HERO)
    print(f"Hero saved: {OUT_HERO}")


if __name__ == "__main__":
    make_icon()
    make_hero()
    print("Done.")
