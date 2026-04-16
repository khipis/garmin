#!/usr/bin/env python3
"""
Generate launcher_icon.png (40x40 RGBA) and hero (1440x720 RGB)
for Dive Risk Indicator.
"""

from PIL import Image, ImageDraw
import math

OUT_ICON = "/Users/kkorolczuk/work/garmin/diveriskindicator/resources/launcher_icon.png"
OUT_HERO = "/Users/kkorolczuk/work/garmin/_LOGOS/diveriskindicator_hero.png"


def make_icon():
    W, H = 40, 40
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d   = ImageDraw.Draw(img)
    cx, cy, r = W // 2, H // 2, W // 2 - 1

    # Deep neutral dark background
    for y in range(H):
        for x in range(W):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r ** 2:
                img.putpixel((x, y), (4, 8, 18, 255))

    d.ellipse([1, 1, W - 2, H - 2], outline=(50, 100, 160, 180), width=1)

    # Risk gauge arc (bottom half, left=green, right=red)
    # Green arc left side
    d.arc([5, 5, W - 6, H - 6], start=180, end=270, fill=(0, 200, 60, 220), width=3)
    # Orange arc middle
    d.arc([5, 5, W - 6, H - 6], start=270, end=315, fill=(255, 160, 0, 220), width=3)
    # Red arc right side
    d.arc([5, 5, W - 6, H - 6], start=315, end=360, fill=(220, 40, 40, 220), width=3)

    # Needle pointing to ~high-medium (orange zone, ~280°)
    angle = math.radians(285)
    nx = cx + int(11 * math.cos(angle))
    ny = cy + int(11 * math.sin(angle))
    d.line([cx, cy, nx, ny], fill=(255, 255, 255, 220), width=1)

    # Centre dot
    d.ellipse([cx - 2, cy - 2, cx + 2, cy + 2], fill=(220, 220, 240, 255))

    # Score "67" text (small, white) — shows a HIGH score
    d.text((cx, cy - 10), "67", fill=(220, 80, 80, 210), anchor="mm")

    img.save(OUT_ICON)
    print(f"Icon saved: {OUT_ICON}")


def make_hero():
    W, H = 1440, 720
    img = Image.new("RGB", (W, H), (4, 8, 18))
    d   = ImageDraw.Draw(img)

    # Gradient
    for y in range(H):
        t = y / H
        d.line([(0, y), (W, y)], fill=(int(4+t*6), int(8+t*12), int(18+t*28)))

    # Large gauge arc in background
    cx, cy = W // 2, H // 2 + 80
    R = 320
    d.arc([cx-R, cy-R, cx+R, cy+R], start=180, end=270, fill=(0, 180, 60, 40), width=40)
    d.arc([cx-R, cy-R, cx+R, cy+R], start=270, end=320, fill=(255, 140, 0, 40), width=40)
    d.arc([cx-R, cy-R, cx+R, cy+R], start=320, end=360, fill=(200, 40, 40, 40), width=40)

    # Left — LOW score example
    lx, ly = 180, 180
    d.rectangle([lx - 10, ly - 10, lx + 300, ly + 220], fill=(4, 18, 8))
    d.text((lx, ly),        "30m / 15min",    fill=(60, 160, 100))
    d.text((lx, ly + 55),   "Nitrox 32",      fill=(60, 160, 100))
    d.text((lx, ly + 110),  "23",             fill=(0, 220, 80))
    d.text((lx, ly + 165),  "LOW RISK",       fill=(0, 180, 60))
    d.text((lx, ly + 195),  "Safe dive",      fill=(40, 100, 60))

    # Centre — title
    d.text((W // 2, H // 2 - 140), "DIVE RISK",        fill=(80, 150, 230), anchor="mm")
    d.text((W // 2, H // 2 - 60),  "INDICATOR",        fill=(100, 170, 255), anchor="mm")
    d.text((W // 2, H // 2 + 20),  "Score 0–100  ·  LOW / MEDIUM / HIGH",
           fill=(60, 100, 150), anchor="mm")
    d.text((W // 2, H // 2 + 100), "Depth · Time · Gas · Repetitive dive",
           fill=(50, 80, 120), anchor="mm")

    # Right — HIGH score example
    rx, ry = W - 460, 180
    d.rectangle([rx - 10, ry - 10, rx + 300, ry + 220], fill=(20, 4, 4))
    d.text((rx, ry),        "40m / 9min",     fill=(180, 80, 80))
    d.text((rx, ry + 55),   "Air · Repet.",   fill=(180, 80, 80))
    d.text((rx, ry + 110),  "78",             fill=(255, 40, 40))
    d.text((rx, ry + 165),  "HIGH RISK",      fill=(220, 30, 30))
    d.text((rx, ry + 195),  "High risk profile", fill=(140, 60, 60))

    d.rectangle([0, H - 50, W, H], fill=(4, 8, 18))
    d.text((W // 2, H - 25),
           "Simplified model · Not a dive computer · For assessment purposes only",
           fill=(50, 80, 110), anchor="mm")

    img.save(OUT_HERO)
    print(f"Hero saved: {OUT_HERO}")


if __name__ == "__main__":
    make_icon()
    make_hero()
    print("Done.")
