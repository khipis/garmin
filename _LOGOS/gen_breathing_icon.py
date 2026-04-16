#!/usr/bin/env python3
"""
Generate launcher_icon.png (40x40 RGBA) and hero (1440x720 RGB)
for Breathing Control Trainer.
"""

from PIL import Image, ImageDraw
import math

OUT_ICON = "/Users/kkorolczuk/work/garmin/breathinggascontrol/resources/launcher_icon.png"
OUT_HERO = "/Users/kkorolczuk/work/garmin/_LOGOS/breathinggascontrol_hero.png"


def make_icon():
    W, H = 40, 40
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d   = ImageDraw.Draw(img)
    cx, cy, r = W // 2, H // 2, W // 2 - 1

    # Deep dark background
    for y in range(H):
        for x in range(W):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r ** 2:
                t  = y / H
                rb = int(4  + t * 4)
                gb = int(8  + t * 12)
                bb = int(16 + t * 24)
                img.putpixel((x, y), (rb, gb, bb, 255))

    # Outer ring
    d.ellipse([1, 1, W - 2, H - 2], outline=(40, 130, 220, 180), width=1)

    # Three concentric breathing circles (inhale ripple effect)
    for i, (alpha, radius) in enumerate([(200, 14), (130, 10), (80, 6)]):
        col = (50 - i * 10, 140 + i * 20, 240 - i * 30, alpha)
        d.ellipse([cx - radius, cy - radius, cx + radius, cy + radius],
                  outline=col, width=1)

    # Central filled circle (inhale state)
    d.ellipse([cx - 6, cy - 6, cx + 6, cy + 6], fill=(60, 160, 255, 230))
    d.ellipse([cx - 2, cy - 2, cx + 2, cy + 2], fill=(200, 235, 255, 255))

    # Tiny wavy exhale line below
    for i in range(7):
        ox = cx - 7 + i * 2
        oy = cy + 12 + int(math.sin(i * 1.2) * 2)
        img.putpixel((ox, oy), (80, 160, 220, 180))

    img.save(OUT_ICON)
    print(f"Icon saved: {OUT_ICON}")


def make_hero():
    W, H = 1440, 720
    img = Image.new("RGB", (W, H), (4, 8, 16))
    d   = ImageDraw.Draw(img)

    # Dark gradient
    for y in range(H):
        t  = y / H
        d.line([(0, y), (W, y)], fill=(int(4 + t * 6), int(8 + t * 18), int(16 + t * 36)))

    # Large breathing circles in background
    for cx, cy, rmax, col in [
        (300, 360, 160, (40, 120, 220, 40)),
        (W // 2, 300, 200, (50, 160, 240, 30)),
        (1140, 360, 140, (130, 80, 240, 40)),
    ]:
        for ri in [rmax, int(rmax * 0.7), int(rmax * 0.4)]:
            d.ellipse([cx - ri, cy - ri, cx + ri, cy + ri], outline=col[:3], width=1)

    # Left — INHALE state
    px, py = 160, 180
    d.rectangle([px - 12, py - 12, px + 310, py + 180], fill=(6, 14, 28))
    d.text((px, py),        "INHALE",        fill=(50, 160, 255))
    d.text((px, py + 60),   "4s",            fill=(180, 220, 255))
    d.text((px, py + 120),  "Relax Mode",    fill=(60, 110, 160))

    # Centre — title
    d.text((W // 2, H // 3),       "BREATHING",        fill=(50, 160, 240), anchor="mm")
    d.text((W // 2, H // 3 + 75),  "CONTROL TRAINER",  fill=(80, 180, 255), anchor="mm")
    d.text((W // 2, H // 3 + 140), "Improve SAC · Box Breathing · Pre-Dive Calm",
           fill=(60, 100, 150), anchor="mm")

    # Right — EXHALE state
    rx, ry = W - 480, 180
    d.rectangle([rx - 12, ry - 12, rx + 310, ry + 180], fill=(8, 12, 28))
    d.text((rx, ry),        "EXHALE",       fill=(140, 80, 240))
    d.text((rx, ry + 60),   "6s",           fill=(200, 170, 255))
    d.text((rx, ry + 120),  "~6 bpm",       fill=(100, 80, 160))

    # Bottom bar
    d.rectangle([0, H - 50, W, H], fill=(4, 8, 20))
    d.text((W // 2, H - 25),
           "Vibration cues · Relax · Training · Pre-Dive modes · Custom cadence",
           fill=(50, 80, 110), anchor="mm")

    img.save(OUT_HERO)
    print(f"Hero saved: {OUT_HERO}")


if __name__ == "__main__":
    make_icon()
    make_hero()
    print("Done.")
