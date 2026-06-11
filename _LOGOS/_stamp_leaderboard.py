#!/usr/bin/env python3
"""Add a colorful 'LEADERBOARD' badge to the top-left of every *_hero.png.

The badge colour is sampled from each hero's own palette (most vivid colour)
so it blends with the artwork's theme. Drawn as an overlay — original art
is preserved. Pairs with the bitochi.com stamp in the bottom-right.

Run once (not idempotent — re-running stacks badges).
"""
import colorsys
import glob
import os
from PIL import Image, ImageDraw, ImageFont

FONT_PATH = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
TEXT = "LEADERBOARD"


def vivid_accent(img):
    """Pick a saturated, bright colour from the image to theme the badge."""
    small = img.convert("RGB").resize((80, 80))
    pal = small.quantize(colors=16, method=Image.FASTOCTREE)
    palette = pal.getpalette()
    counts = pal.getcolors() or []
    best, best_score = (0, 212, 255), -1.0
    total = sum(c for c, _ in counts) or 1
    for count, idx in counts:
        r, g, b = palette[idx * 3:idx * 3 + 3]
        h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
        freq = count / total
        # Favour vivid (saturated + bright) colours, lightly weighted by area.
        score = s * (0.4 + 0.6 * v) * (0.6 + 0.4 * freq)
        if score > best_score:
            best_score, best = score, (r, g, b)
    # Punch up the colour so the badge always pops.
    h, s, v = colorsys.rgb_to_hsv(*[c / 255 for c in best])
    s = min(1.0, max(s, 0.55))
    v = min(1.0, max(v, 0.75))
    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    return (int(r * 255), int(g * 255), int(b * 255))


def text_color_for(bg):
    """Black or white text depending on badge background luminance."""
    lum = 0.299 * bg[0] + 0.587 * bg[1] + 0.114 * bg[2]
    return (10, 12, 16) if lum > 150 else (255, 255, 255)


def draw_trophy(d, cx, cy, s, color):
    """Tiny trophy glyph centred at (cx, cy), scale s ~ glyph height."""
    half = s // 2
    # Cup bowl
    d.rectangle([cx - half, cy - half, cx + half, cy - half + int(s * 0.45)], fill=color)
    d.ellipse([cx - half, cy - half + int(s * 0.30), cx + half, cy - half + int(s * 0.70)], fill=color)
    # Handles
    hw = max(2, s // 6)
    d.arc([cx - half - hw, cy - half, cx - half + hw, cy - half + int(s * 0.5)], 90, 270, fill=color, width=max(1, s // 10))
    d.arc([cx + half - hw, cy - half, cx + half + hw, cy - half + int(s * 0.5)], 270, 90, fill=color, width=max(1, s // 10))
    # Stem + base
    d.rectangle([cx - max(1, s // 8), cy + int(s * 0.05), cx + max(1, s // 8), cy + int(s * 0.30)], fill=color)
    d.rectangle([cx - half + 2, cy + int(s * 0.30), cx + half - 2, cy + int(s * 0.42)], fill=color)


def stamp(path):
    img = Image.open(path).convert("RGBA")
    W, H = img.size
    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)

    accent = vivid_accent(img)
    txt_clr = text_color_for(accent)

    font_size = max(18, int(H * 0.042))
    font = ImageFont.truetype(FONT_PATH, font_size)

    pad_x = int(font_size * 0.7)
    pad_y = int(font_size * 0.42)
    troph = int(font_size * 1.0)
    gap = int(font_size * 0.5)

    bbox = d.textbbox((0, 0), TEXT, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]

    badge_w = pad_x + troph + gap + tw + pad_x
    badge_h = pad_y + max(th, troph) + pad_y

    margin = int(H * 0.035)
    x1, y1 = margin, margin
    x2, y2 = x1 + badge_w, y1 + badge_h
    radius = badge_h // 2

    # Outer dark halo for contrast on busy art
    d.rounded_rectangle([x1 - 2, y1 - 2, x2 + 2, y2 + 2], radius=radius + 2,
                        fill=(0, 0, 0, 90))
    # Themed badge body + bright border
    d.rounded_rectangle([x1, y1, x2, y2], radius=radius,
                        fill=(accent[0], accent[1], accent[2], 235),
                        outline=(255, 255, 255, 210), width=max(2, int(font_size * 0.08)))

    cy = (y1 + y2) // 2
    draw_trophy(d, x1 + pad_x + troph // 2, cy, troph, txt_clr)

    tx = x1 + pad_x + troph + gap
    ty = cy - (bbox[3] + bbox[1]) // 2
    d.text((tx, ty), TEXT, font=font, fill=txt_clr)

    out = Image.alpha_composite(img, overlay).convert("RGB")
    out.save(path, "PNG")
    return accent


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    files = sorted(glob.glob(os.path.join(here, "*_hero.png")))
    for f in files:
        acc = stamp(f)
        print("badged", os.path.basename(f), "accent", acc)
    print(f"\nDone — {len(files)} hero images badged.")


if __name__ == "__main__":
    main()
