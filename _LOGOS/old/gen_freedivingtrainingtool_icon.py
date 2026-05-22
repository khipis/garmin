#!/usr/bin/env python3
"""
Generate launcher_icon.png (40x40 RGBA) for Freediving Training Tool.
Combines breathing, apnea, and table training into one visual.
"""

from PIL import Image, ImageDraw
import math

OUT_ICON = "/Users/kkorolczuk/work/garmin/freedivingtrainingtool/resources/launcher_icon.png"


def make_icon():
    W, H = 40, 40
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy, r = W // 2, H // 2, W // 2 - 1

    # Deep ocean gradient background (circular)
    for y in range(H):
        for x in range(W):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r ** 2:
                t = y / H
                rb = int(0 + t * 8)
                gb = int(18 + t * 40)
                bb = int(50 + t * 60)
                img.putpixel((x, y), (rb, gb, bb, 255))

    # Outer ring — teal/cyan
    d.ellipse([1, 1, W - 2, H - 2], outline=(0, 180, 220, 200), width=1)

    # Training arc (top-right quadrant) — represents CO2/O2 table progress
    d.arc([4, 4, W - 5, H - 5], start=-120, end=30, fill=(0, 200, 170, 220), width=2)

    # Breathing circle (center) — pulsing inhale state
    for ri, alpha in [(12, 60), (9, 100), (6, 160)]:
        col = (0, int(180 + alpha * 0.3), int(230 + alpha * 0.1), alpha)
        d.ellipse([cx - ri, cy - ri, cx + ri, cy + ri], outline=col, width=1)

    # Core filled circle — bright cyan (inhale)
    d.ellipse([cx - 5, cy - 5, cx + 5, cy + 5], fill=(0, 200, 240, 230))
    d.ellipse([cx - 2, cy - 2, cx + 2, cy + 2], fill=(200, 245, 255, 255))

    # Diver silhouette hint (small figure diving down, bottom-left)
    # Head
    d.ellipse([8, 26, 12, 30], fill=(180, 220, 255, 180))
    # Body line going down
    d.line([10, 30, 10, 35], fill=(180, 220, 255, 160), width=1)
    # Fins
    d.line([10, 35, 7, 37], fill=(180, 220, 255, 140), width=1)
    d.line([10, 35, 13, 37], fill=(180, 220, 255, 140), width=1)

    # Tiny bubbles rising from diver
    for bx, by, br in [(12, 24, 1), (14, 22, 1), (11, 20, 1)]:
        d.ellipse([bx - br, by - br, bx + br, by + br],
                  outline=(140, 220, 255, 150), width=1)

    # Timer tick marks around the arc (like a stopwatch)
    for i in range(8):
        angle = math.radians(-120 + i * (150 / 7))
        ix = cx + int(16 * math.cos(angle))
        iy = cy + int(16 * math.sin(angle))
        ox = cx + int(18 * math.cos(angle))
        oy = cy + int(18 * math.sin(angle))
        d.line([ix, iy, ox, oy], fill=(0, 200, 200, 120), width=1)

    img.save(OUT_ICON)
    print(f"Icon saved: {OUT_ICON}")


if __name__ == "__main__":
    make_icon()
    print("Done.")
