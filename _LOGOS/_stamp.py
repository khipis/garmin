#!/usr/bin/env python3
"""Add a subtle 'bitochi.com' stamp to the bottom-right of every *_hero.png.

Only overlays a badge — it never touches the underlying artwork pixels
elsewhere. Run once; safe to re-run (it re-stamps the same spot identically).
"""
import glob
import os
from PIL import Image, ImageDraw, ImageFont

FONT_PATH = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
TEXT = "bitochi.com"
ACCENT = (0, 212, 255, 255)  # cyan, matches the leaderboard accent

def stamp(path):
    img = Image.open(path).convert("RGBA")
    W, H = img.size
    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)

    # Scale everything to the image height so it looks identical on any size.
    font_size = max(18, int(H * 0.040))
    font = ImageFont.truetype(FONT_PATH, font_size)

    pad_x = int(font_size * 0.7)
    pad_y = int(font_size * 0.45)
    dot_r = max(3, int(font_size * 0.16))
    gap   = int(font_size * 0.45)

    # Measure text
    bbox = d.textbbox((0, 0), TEXT, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]

    badge_w = pad_x + dot_r * 2 + gap + tw + pad_x
    badge_h = pad_y + max(th, dot_r * 2) + pad_y

    margin = int(H * 0.035)
    x1 = W - margin - badge_w
    y1 = H - margin - badge_h
    x2 = W - margin
    y2 = H - margin
    radius = badge_h // 2

    # Pill background: translucent dark with a thin cyan border
    d.rounded_rectangle([x1, y1, x2, y2], radius=radius,
                        fill=(8, 12, 16, 175),
                        outline=(0, 212, 255, 160), width=max(1, int(font_size * 0.06)))

    # Accent dot
    cy = (y1 + y2) // 2
    dot_cx = x1 + pad_x + dot_r
    d.ellipse([dot_cx - dot_r, cy - dot_r, dot_cx + dot_r, cy + dot_r], fill=ACCENT)

    # Text (vertically centred against font metrics)
    tx = dot_cx + dot_r + gap
    ty = cy - (bbox[3] + bbox[1]) // 2
    # soft shadow for legibility
    d.text((tx + 1, ty + 1), TEXT, font=font, fill=(0, 0, 0, 150))
    d.text((tx, ty), TEXT, font=font, fill=(255, 255, 255, 235))

    out = Image.alpha_composite(img, overlay).convert("RGB")
    out.save(path, "PNG")

def main():
    here = os.path.dirname(os.path.abspath(__file__))
    files = sorted(glob.glob(os.path.join(here, "*_hero.png")))
    for f in files:
        stamp(f)
        print("stamped", os.path.basename(f))
    print(f"\nDone — {len(files)} hero images stamped.")

if __name__ == "__main__":
    main()
