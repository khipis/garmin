#!/usr/bin/env python3
"""Compose a Bitochi store hero: watch (left) + title / By Bitochi (right).

Output: <repo>/_LOGOS/<slug>_hero.png at 1440×720.

Usage:
  python3 gen_hero.py --slug bomb --title "Bomb" --screen face.png
  python3 gen_hero.py --slug bomb --title "Bomb" --screen face.png --stamp
"""
from __future__ import annotations

import argparse
import colorsys
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1440, 720
REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
LOGOS = os.path.join(REPO, "_LOGOS")

FONT_BOLD = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
FONT_REG = "/System/Library/Fonts/Supplemental/Arial.ttf"


def _font(path: str, size: int) -> ImageFont.FreeTypeFont:
    try:
        return ImageFont.truetype(path, size)
    except OSError:
        return ImageFont.load_default()


def _fit_cover(im: Image.Image, size: int) -> Image.Image:
    im = im.convert("RGBA")
    tw, th = im.size
    scale = max(size / tw, size / th)
    nw, nh = max(1, int(tw * scale)), max(1, int(th * scale))
    im = im.resize((nw, nh), Image.LANCZOS)
    left = (nw - size) // 2
    top = (nh - size) // 2
    return im.crop((left, top, left + size, top + size))


def _circular(im: Image.Image) -> Image.Image:
    size = im.size[0]
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, size - 1, size - 1), fill=255)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(im, (0, 0))
    out.putalpha(mask)
    return out


def _watch(screen: Image.Image, face: int = 420) -> Image.Image:
    """Round Garmin-like bezel with circular game face."""
    face_im = _circular(_fit_cover(screen, face))
    bezel = int(face * 0.11)
    outer = face + bezel * 2
    canvas = Image.new("RGBA", (outer + 24, outer + 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(canvas)
    ox = oy = 12
    # soft drop shadow
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.ellipse([ox + 8, oy + 14, ox + outer + 8, oy + outer + 14], fill=(0, 0, 0, 110))
    shadow = shadow.filter(ImageFilter.GaussianBlur(12))
    canvas = Image.alpha_composite(canvas, shadow)
    d = ImageDraw.Draw(canvas)
    # metal ring
    d.ellipse([ox, oy, ox + outer, oy + outer], fill=(28, 30, 34, 255))
    d.ellipse(
        [ox + 3, oy + 3, ox + outer - 3, oy + outer - 3],
        fill=(55, 58, 64, 255),
        outline=(120, 124, 130, 255),
        width=2,
    )
    # inner black
    inner = [ox + bezel - 4, oy + bezel - 4, ox + outer - bezel + 4, oy + outer - bezel + 4]
    d.ellipse(inner, fill=(8, 8, 10, 255))
    # crown (right)
    cx = ox + outer + 2
    cy = oy + outer // 2
    d.rounded_rectangle([cx, cy - 18, cx + 14, cy + 18], radius=4, fill=(70, 74, 80, 255))
    canvas.paste(face_im, (ox + bezel, oy + bezel), face_im)
    return canvas


def _bg(accent: tuple[int, int, int]) -> Image.Image:
    img = Image.new("RGB", (W, H))
    px = img.load()
    r0, g0, b0 = 10, 12, 18
    r1, g1, b1 = accent[0] // 5, accent[1] // 5, accent[2] // 5
    for y in range(H):
        t = y / (H - 1)
        # slight radial feel: left darker for watch, right richer for title
        for x in range(W):
            u = x / (W - 1)
            k = 0.55 * t + 0.35 * u
            r = int(r0 + (r1 - r0) * k)
            g = int(g0 + (g1 - g0) * k)
            b = int(b0 + (b1 - b0) * k)
            px[x, y] = (r, g, b)
    return img.convert("RGBA")


def _sample_accent(screen: Image.Image) -> tuple[int, int, int]:
    small = screen.convert("RGB").resize((64, 64))
    pal = small.quantize(colors=12, method=Image.FASTOCTREE)
    palette = pal.getpalette() or []
    counts = pal.getcolors() or []
    best, score = (0, 212, 255), -1.0
    total = sum(c for c, _ in counts) or 1
    for count, idx in counts:
        r, g, b = palette[idx * 3 : idx * 3 + 3]
        h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
        sc = s * (0.4 + 0.6 * v) * (0.5 + 0.5 * count / total)
        if sc > score:
            score, best = sc, (r, g, b)
    h, s, v = colorsys.rgb_to_hsv(*[c / 255 for c in best])
    s, v = min(1.0, max(s, 0.5)), min(1.0, max(v, 0.7))
    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    return int(r * 255), int(g * 255), int(b * 255)


def compose(slug: str, title: str, screen_path: str, out_path: str | None = None) -> str:
    screen = Image.open(screen_path).convert("RGBA")
    accent = _sample_accent(screen)
    base = _bg(accent)
    watch = _watch(screen)
    # place watch on left
    wx = 90
    wy = (H - watch.size[1]) // 2
    base.paste(watch, (wx, wy), watch)

    d = ImageDraw.Draw(base)
    # title block on right
    right_cx = int(W * 0.72)
    title_font = _font(FONT_BOLD, 72 if len(title) < 12 else 56 if len(title) < 18 else 44)
    by_font = _font(FONT_REG, 36)
    # wrap title roughly
    lines = [title.upper()]
    if len(title) > 16 and " " in title:
        parts = title.upper().split()
        mid = max(1, len(parts) // 2)
        lines = [" ".join(parts[:mid]), " ".join(parts[mid:])]

    y = H // 2 - (len(lines) * 80) // 2 - 20
    for line in lines:
        bbox = d.textbbox((0, 0), line, font=title_font)
        tw = bbox[2] - bbox[0]
        x = right_cx - tw // 2
        d.text((x + 2, y + 2), line, font=title_font, fill=(0, 0, 0, 160))
        d.text((x, y), line, font=title_font, fill=(245, 248, 252, 255))
        y += bbox[3] - bbox[1] + 18

    by = "By Bitochi"
    bbox = d.textbbox((0, 0), by, font=by_font)
    tw = bbox[2] - bbox[0]
    d.text((right_cx - tw // 2, y + 12), by, font=by_font, fill=(accent[0], accent[1], accent[2], 230))

    out = out_path or os.path.join(LOGOS, f"{slug}_hero.png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    base.convert("RGB").save(out, "PNG")
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description="Compose Bitochi 1440×720 hero")
    ap.add_argument("--slug", required=True)
    ap.add_argument("--title", required=True)
    ap.add_argument("--screen", required=True, help="Gameplay screenshot / face crop")
    ap.add_argument("--out", default=None)
    ap.add_argument("--stamp", action="store_true", help="Apply LEADERBOARD + bitochi.com via stamp_one.py")
    args = ap.parse_args()
    if not os.path.isfile(args.screen):
        print("screen not found:", args.screen, file=sys.stderr)
        return 1
    path = compose(args.slug, args.title, args.screen, args.out)
    print("wrote", path)
    if args.stamp:
        stamp_one = os.path.join(os.path.dirname(__file__), "stamp_one.py")
        os.execv(sys.executable, [sys.executable, stamp_one, args.slug])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
