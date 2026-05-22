#!/usr/bin/env python3
"""
Generate launcher_icon.png (40x40 RGBA) and hero image (1440x720 RGB)
for Cold Exposure / Recovery Timer.
"""

from PIL import Image, ImageDraw
import math

OUT_ICON = "/Users/kkorolczuk/work/garmin/recoverytimer/resources/launcher_icon.png"
OUT_HERO = "/Users/kkorolczuk/work/garmin/_LOGOS/recoverytimer_hero.png"


# ── Launcher icon (40 × 40 RGBA) ─────────────────────────────────────────────

def make_icon():
    W, H = 40, 40
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d   = ImageDraw.Draw(img)

    cx, cy, r = W // 2, H // 2, W // 2 - 1

    # Deep navy-blue ice background (circular)
    for y in range(H):
        for x in range(W):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r ** 2:
                t  = y / H
                rb = int(4  + t * 6)
                gb = int(10 + t * 20)
                bb = int(30 + t * 60)
                img.putpixel((x, y), (rb, gb, bb, 255))

    # Outer ring
    d.ellipse([1, 1, W - 2, H - 2], outline=(60, 160, 240, 200), width=1)

    # Snowflake / ice crystal — 6 lines from centre
    for i in range(6):
        a  = math.radians(i * 60)
        ex = cx + int(13 * math.cos(a))
        ey = cy + int(13 * math.sin(a))
        d.line([cx, cy, ex, ey], fill=(100, 200, 255, 200), width=1)
        # Small cross ticks on arms at 60% length
        mx  = cx + int(8 * math.cos(a))
        my  = cy + int(8 * math.sin(a))
        pa  = a + math.pi / 2
        d.line([mx + int(3 * math.cos(pa)), my + int(3 * math.sin(pa)),
                mx - int(3 * math.cos(pa)), my - int(3 * math.sin(pa))],
               fill=(80, 180, 230, 160), width=1)

    # Centre dot
    d.ellipse([cx - 2, cy - 2, cx + 2, cy + 2], fill=(180, 230, 255, 255))

    # Small timer arc at bottom-right
    d.arc([22, 22, 37, 37], start=-200, end=60, fill=(255, 200, 80, 200), width=2)

    img.save(OUT_ICON)
    print(f"Icon saved: {OUT_ICON}")


# ── Hero image (1440 × 720 RGB) ───────────────────────────────────────────────

def make_hero():
    W, H = 1440, 720
    img = Image.new("RGB", (W, H), (4, 8, 16))
    d   = ImageDraw.Draw(img)

    # Icy gradient background
    for y in range(H):
        t  = y / H
        r  = int(4  + t * 8)
        g  = int(8  + t * 24)
        b  = int(16 + t * 64)
        d.line([(0, y), (W, y)], fill=(r, g, b))

    # Ice crystal decorations
    for cx, cy in [(150, 180), (1300, 200), (800, 580), (300, 580), (1100, 480)]:
        for i in range(6):
            a  = math.radians(i * 60)
            ex = cx + int(40 * math.cos(a))
            ey = cy + int(40 * math.sin(a))
            d.line([cx, cy, ex, ey], fill=(60, 140, 200, 120), width=1)

    # Left panel — COLD timer
    px, py = 180, 160
    d.rectangle([px - 12, py - 12, px + 300, py + 180], fill=(6, 16, 36))
    d.text((px, py),       "COLD",      fill=(60, 180, 255))
    d.text((px, py + 50),  "2:00",      fill=(220, 240, 255))
    d.text((px, py + 120), "Round 1/3", fill=(80, 130, 180))

    # Centre — app title
    d.text((W // 2, H // 3),      "RECOVERY",       fill=(60, 160, 240), anchor="mm")
    d.text((W // 2, H // 3 + 80), "TIMER",          fill=(100, 190, 255), anchor="mm")
    d.text((W // 2, H // 3 + 140),
           "Cold Shower  ·  Ice Bath  ·  Sauna",     fill=(70, 110, 160), anchor="mm")

    # Right panel — REST timer
    rx, ry = W - 480, 160
    d.rectangle([rx - 12, ry - 12, rx + 300, ry + 180], fill=(8, 18, 28))
    d.text((rx, ry),       "REST",      fill=(255, 140, 60))
    d.text((rx, ry + 50),  "1:00",      fill=(255, 220, 180))
    d.text((rx, ry + 120), "Interval ×3", fill=(160, 120, 80))

    # Bottom bar
    d.rectangle([0, H - 50, W, H], fill=(4, 10, 24))
    d.text((W // 2, H - 25),
           "Vibration alerts at end · Interval mode · Not medical advice",
           fill=(50, 80, 110), anchor="mm")

    img.save(OUT_HERO)
    print(f"Hero saved: {OUT_HERO}")


if __name__ == "__main__":
    make_icon()
    make_hero()
    print("Done.")
