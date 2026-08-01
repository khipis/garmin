#!/usr/bin/env python3
"""Stamp a single _LOGOS/<slug>_hero.png with LEADERBOARD (TL) + bitochi.com (BR).

Unlike _LOGOS/_stamp*.py (whole folder), this only touches one file.
LEADERBOARD badge is NOT idempotent — do not run twice on the same hero.
"""
from __future__ import annotations

import colorsys
import os
import sys

from PIL import Image, ImageDraw, ImageFont

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
LOGOS = os.path.join(REPO, "_LOGOS")
FONT = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"


def _font(size: int) -> ImageFont.FreeTypeFont:
    try:
        return ImageFont.truetype(FONT, size)
    except OSError:
        return ImageFont.load_default()


def vivid_accent(img: Image.Image):
    small = img.convert("RGB").resize((80, 80))
    pal = small.quantize(colors=16, method=Image.FASTOCTREE)
    palette = pal.getpalette() or []
    counts = pal.getcolors() or []
    best, best_score = (0, 212, 255), -1.0
    total = sum(c for c, _ in counts) or 1
    for count, idx in counts:
        r, g, b = palette[idx * 3 : idx * 3 + 3]
        h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
        score = s * (0.4 + 0.6 * v) * (0.6 + 0.4 * count / total)
        if score > best_score:
            best_score, best = score, (r, g, b)
    h, s, v = colorsys.rgb_to_hsv(*[c / 255 for c in best])
    s, v = min(1.0, max(s, 0.55)), min(1.0, max(v, 0.75))
    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    return int(r * 255), int(g * 255), int(b * 255)


def text_color_for(bg):
    lum = 0.299 * bg[0] + 0.587 * bg[1] + 0.114 * bg[2]
    return (10, 12, 16) if lum > 150 else (255, 255, 255)


def draw_trophy(d, cx, cy, s, color):
    half = s // 2
    d.rectangle([cx - half, cy - half, cx + half, cy - half + int(s * 0.45)], fill=color)
    d.ellipse(
        [cx - half, cy - half + int(s * 0.30), cx + half, cy - half + int(s * 0.70)],
        fill=color,
    )
    hw = max(2, s // 6)
    d.arc(
        [cx - half - hw, cy - half, cx - half + hw, cy - half + int(s * 0.5)],
        90, 270, fill=color, width=max(1, s // 10),
    )
    d.arc(
        [cx + half - hw, cy - half, cx + half + hw, cy - half + int(s * 0.5)],
        270, 90, fill=color, width=max(1, s // 10),
    )
    d.rectangle(
        [cx - max(1, s // 8), cy + int(s * 0.05), cx + max(1, s // 8), cy + int(s * 0.30)],
        fill=color,
    )
    d.rectangle(
        [cx - half + 2, cy + int(s * 0.30), cx + half - 2, cy + int(s * 0.42)],
        fill=color,
    )


def stamp_leaderboard(path: str) -> None:
    img = Image.open(path).convert("RGBA")
    W, H = img.size
    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    accent = vivid_accent(img)
    txt = text_color_for(accent)
    font_size = max(18, int(H * 0.042))
    font = _font(font_size)
    pad_x = int(font_size * 0.7)
    pad_y = int(font_size * 0.42)
    troph = int(font_size * 1.0)
    gap = int(font_size * 0.5)
    TEXT = "LEADERBOARD"
    bbox = d.textbbox((0, 0), TEXT, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    badge_w = pad_x + troph + gap + tw + pad_x
    badge_h = pad_y + max(th, troph) + pad_y
    margin = int(H * 0.035)
    x1, y1 = margin, margin
    x2, y2 = margin + badge_w, margin + badge_h
    d.rounded_rectangle(
        [x1, y1, x2, y2],
        radius=badge_h // 2,
        fill=(*accent, 230),
        outline=(255, 255, 255, 40),
        width=max(1, int(font_size * 0.05)),
    )
    cy = (y1 + y2) // 2
    draw_trophy(d, x1 + pad_x + troph // 2, cy, troph, txt)
    tx = x1 + pad_x + troph + gap
    ty = cy - (bbox[3] + bbox[1]) // 2
    d.text((tx, ty), TEXT, font=font, fill=txt)
    Image.alpha_composite(img, overlay).convert("RGB").save(path, "PNG")


def stamp_bitochi(path: str) -> None:
    img = Image.open(path).convert("RGBA")
    W, H = img.size
    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    TEXT = "bitochi.com"
    ACCENT = (0, 212, 255, 255)
    font_size = max(18, int(H * 0.040))
    font = _font(font_size)
    pad_x = int(font_size * 0.7)
    pad_y = int(font_size * 0.45)
    dot_r = max(3, int(font_size * 0.16))
    gap = int(font_size * 0.45)
    bbox = d.textbbox((0, 0), TEXT, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    badge_w = pad_x + dot_r * 2 + gap + tw + pad_x
    badge_h = pad_y + max(th, dot_r * 2) + pad_y
    margin = int(H * 0.035)
    x1 = W - margin - badge_w
    y1 = H - margin - badge_h
    x2, y2 = W - margin, H - margin
    d.rounded_rectangle(
        [x1, y1, x2, y2],
        radius=badge_h // 2,
        fill=(8, 12, 16, 175),
        outline=(0, 212, 255, 160),
        width=max(1, int(font_size * 0.06)),
    )
    cy = (y1 + y2) // 2
    dot_cx = x1 + pad_x + dot_r
    d.ellipse([dot_cx - dot_r, cy - dot_r, dot_cx + dot_r, cy + dot_r], fill=ACCENT)
    tx = dot_cx + dot_r + gap
    ty = cy - (bbox[3] + bbox[1]) // 2
    d.text((tx + 1, ty + 1), TEXT, font=font, fill=(0, 0, 0, 150))
    d.text((tx, ty), TEXT, font=font, fill=(255, 255, 255, 235))
    Image.alpha_composite(img, overlay).convert("RGB").save(path, "PNG")


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: stamp_one.py <slug> [<slug2> ...]", file=sys.stderr)
        return 1
    for slug in sys.argv[1:]:
        path = os.path.join(LOGOS, f"{slug}_hero.png")
        if not os.path.isfile(path):
            print("missing", path, file=sys.stderr)
            return 1
        stamp_leaderboard(path)
        stamp_bitochi(path)
        print("stamped", path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
