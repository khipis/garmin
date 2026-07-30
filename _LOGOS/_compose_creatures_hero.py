#!/usr/bin/env python3
"""Compose the Creatures: Evolution Arena hero (1440x720).

Takes the generated arena key art, crops it to the Bitochi 2:1 hero format and
lays the title block over the dark negative space on the right. Stamps
(LEADERBOARD / bitochi.com) are applied afterwards by
.cursor/skills/make-game/scripts/stamp_one.py.
"""
from __future__ import annotations

import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1440, 720
REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(REPO, "_LOGOS", "creatures_hero.png")

BLACK = "/System/Library/Fonts/Supplemental/Arial Black.ttf"
BOLD = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"


def font(path: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(path, size)


def text_size(f: ImageFont.FreeTypeFont, s: str, tracking: int) -> tuple[int, int]:
    d = ImageDraw.Draw(Image.new("RGB", (1, 1)))
    w = 0
    for ch in s:
        w += d.textlength(ch, font=f) + tracking
    bbox = d.textbbox((0, 0), s, font=f)
    return int(w - tracking), bbox[3] - bbox[1]


def fit_font(path: str, s: str, target_w: int, tracking: int) -> ImageFont.FreeTypeFont:
    size = 20
    while size < 400:
        f = font(path, size + 4)
        if text_size(f, s, tracking)[0] > target_w:
            break
        size += 4
    return font(path, size)


def draw_tracked(d: ImageDraw.ImageDraw, xy, s, f, fill, tracking: int) -> None:
    x, y = xy
    for ch in s:
        d.text((x, y), ch, font=f, fill=fill)
        x += d.textlength(ch, font=f) + tracking


def gradient_text(
    size: tuple[int, int],
    s: str,
    f: ImageFont.FreeTypeFont,
    xy: tuple[int, int],
    tracking: int,
    c_top: tuple[int, int, int],
    c_bot: tuple[int, int, int],
) -> Image.Image:
    """Text rendered as a vertical gradient, returned as an RGBA layer."""
    mask = Image.new("L", size, 0)
    draw_tracked(ImageDraw.Draw(mask), xy, s, f, 255, tracking)
    bbox = mask.getbbox()
    grad = Image.new("RGBA", size, (0, 0, 0, 0))
    if bbox is None:
        return grad
    top, bot = bbox[1], bbox[3]
    g = ImageDraw.Draw(grad)
    for y in range(top, bot):
        t = (y - top) / max(1, bot - top - 1)
        g.line(
            [(0, y), (size[0], y)],
            fill=(
                int(c_top[0] + (c_bot[0] - c_top[0]) * t),
                int(c_top[1] + (c_bot[1] - c_top[1]) * t),
                int(c_top[2] + (c_bot[2] - c_top[2]) * t),
                255,
            ),
        )
    grad.putalpha(mask)
    return grad


def glow(layer: Image.Image, color: tuple[int, int, int], radius: int, alpha: int) -> Image.Image:
    a = layer.getchannel("A").filter(ImageFilter.GaussianBlur(radius))
    out = Image.new("RGBA", layer.size, (*color, 0))
    out.putalpha(a.point(lambda v: int(v * alpha / 255)))
    return out


def outline(layer: Image.Image, color: tuple[int, int, int], width: int) -> Image.Image:
    a = layer.getchannel("A").filter(ImageFilter.MaxFilter(width * 2 + 1))
    out = Image.new("RGBA", layer.size, (*color, 0))
    out.putalpha(a)
    return out


def base_art(src_path: str) -> Image.Image:
    src = Image.open(src_path).convert("RGB")
    sw, sh = src.size
    target_h = int(sw / 2)
    top = int((sh - target_h) * 0.58)  # keep more of the arena floor than the ceiling
    src = src.crop((0, top, sw, top + target_h)).resize((W, H), Image.LANCZOS)
    return src.convert("RGBA")


def scrim(img: Image.Image, cx: int, cy: int, rx: int, ry: int, strength: int) -> Image.Image:
    """Soft dark ellipse so the title always reads over busy art."""
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).ellipse(
        [cx - rx, cy - ry, cx + rx, cy + ry], fill=(4, 6, 14, strength)
    )
    layer = layer.filter(ImageFilter.GaussianBlur(90))
    return Image.alpha_composite(img, layer)


def compose(src_path: str) -> str:
    img = base_art(src_path)

    cx = 1005
    img = scrim(img, cx, 330, 430, 250, 190)

    # CREATURES
    tr1 = 8
    f1 = fit_font(BLACK, "CREATURES", 720, tr1)
    w1, _ = text_size(f1, "CREATURES", tr1)
    y1 = 168
    l1 = gradient_text((W, H), "CREATURES", f1, (cx - w1 // 2, y1), tr1, (150, 245, 255), (168, 85, 247))
    img = Image.alpha_composite(img, glow(l1, (80, 200, 255), 26, 190))
    img = Image.alpha_composite(img, outline(l1, (6, 10, 24), 3))
    img = Image.alpha_composite(img, l1)

    # EVOLUTION ARENA
    tr2 = 14
    f2 = fit_font(BOLD, "EVOLUTION ARENA", 640, tr2)
    w2, _ = text_size(f2, "EVOLUTION ARENA", tr2)
    y2 = y1 + 132
    l2 = gradient_text((W, H), "EVOLUTION ARENA", f2, (cx - w2 // 2, y2), tr2, (255, 226, 140), (255, 122, 69))
    img = Image.alpha_composite(img, glow(l2, (255, 160, 60), 20, 170))
    img = Image.alpha_composite(img, outline(l2, (10, 6, 4), 3))
    img = Image.alpha_composite(img, l2)

    # Divider with a diamond, echoing the in-watch VS marker
    d = ImageDraw.Draw(img)
    dy = y2 + 96
    half = w2 // 2
    d.line([(cx - half, dy), (cx - 26, dy)], fill=(120, 190, 235, 170), width=2)
    d.line([(cx + 26, dy), (cx + half, dy)], fill=(120, 190, 235, 170), width=2)
    d.polygon([(cx, dy - 11), (cx + 11, dy), (cx, dy + 11), (cx - 11, dy)], fill=(0, 212, 255, 235))

    # by Bitochi
    f3 = font(BOLD, 44)
    by_a, by_b = "by ", "Bitochi"
    wa = d.textlength(by_a, font=f3)
    wb = d.textlength(by_b, font=f3)
    bx = cx - int(wa + wb) // 2
    by_y = dy + 28
    d.text((bx + 2, by_y + 2), by_a, font=f3, fill=(0, 0, 0, 160))
    d.text((bx, by_y), by_a, font=f3, fill=(206, 216, 232, 245))
    d.text((bx + wa + 2, by_y + 2), by_b, font=f3, fill=(0, 0, 0, 160))
    d.text((bx + wa, by_y), by_b, font=f3, fill=(0, 212, 255, 255))

    img.convert("RGB").save(OUT, "PNG")
    return OUT


if __name__ == "__main__":
    src = sys.argv[1] if len(sys.argv) > 1 else ""
    if not os.path.isfile(src):
        print("usage: _compose_creatures_hero.py <arena_art.png>", file=sys.stderr)
        raise SystemExit(1)
    print("wrote", compose(src))
