#!/usr/bin/env python3
"""Compose the Mines hero (1440x720) from the carved-title key art.

The generated art carries the big "MINES" slab; this adds the caption block
underneath it. Stamps (LEADERBOARD / bitochi.com) are applied afterwards by
.cursor/skills/make-game/scripts/stamp_one.py.
"""
from __future__ import annotations

import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1440, 720
REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(REPO, "_LOGOS", "mines_hero.png")

BOLD = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
SERIF = "/System/Library/Fonts/Supplemental/Georgia Bold.ttf"

CX = 1000
TAGLINE = "DIG DEEPER EVERY DAY"


def text_width(d: ImageDraw.ImageDraw, s: str, f: ImageFont.FreeTypeFont, tracking: int) -> int:
    return int(sum(d.textlength(ch, font=f) + tracking for ch in s) - tracking)


def draw_tracked(d: ImageDraw.ImageDraw, xy, s, f, fill, tracking: int) -> None:
    x, y = xy
    for ch in s:
        d.text((x, y), ch, font=f, fill=fill)
        x += d.textlength(ch, font=f) + tracking


def base_art(src_path: str) -> Image.Image:
    src = Image.open(src_path).convert("RGB")
    sw, sh = src.size
    target_h = sw // 2
    top = int((sh - target_h) * 0.35)  # keep the watch fully, trim the ceiling
    return src.crop((0, top, sw, top + target_h)).resize((W, H), Image.LANCZOS).convert("RGBA")


def scrim(img: Image.Image, cx: int, cy: int, rx: int, ry: int, strength: int) -> Image.Image:
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=(4, 4, 6, strength))
    return Image.alpha_composite(img, layer.filter(ImageFilter.GaussianBlur(70)))


def compose(src_path: str, caption_y: int) -> str:
    img = base_art(src_path)
    img = scrim(img, CX, caption_y + 60, 400, 110, 165)
    d = ImageDraw.Draw(img)

    # by Bitochi — small serif signature on a hairline rule
    f_by = ImageFont.truetype(SERIF, 40)
    by_a, by_b = "by ", "Bitochi"
    wa = d.textlength(by_a, font=f_by)
    wb = d.textlength(by_b, font=f_by)
    bx = CX - int(wa + wb) // 2
    d.text((bx + 2, caption_y + 2), by_a, font=f_by, fill=(0, 0, 0, 170))
    d.text((bx, caption_y), by_a, font=f_by, fill=(214, 198, 168, 245))
    d.text((bx + wa + 2, caption_y + 2), by_b, font=f_by, fill=(0, 0, 0, 170))
    d.text((bx + wa, caption_y), by_b, font=f_by, fill=(246, 236, 214, 255))

    rule_y = caption_y + 26
    rule_pad = 22
    for sign in (-1, 1):
        x_in = CX + sign * (int(wa + wb) // 2 + rule_pad)
        x_out = CX + sign * (int(wa + wb) // 2 + rule_pad + 70)
        d.line([(x_in, rule_y), (x_out, rule_y)], fill=(198, 156, 84, 200), width=3)
        d.polygon(
            [(x_out, rule_y - 7), (x_out + sign * 12, rule_y), (x_out, rule_y + 7)],
            fill=(198, 156, 84, 210),
        )

    # DIG DEEPER EVERY DAY — letterspaced gold caps
    tr = 8
    f_tag = ImageFont.truetype(BOLD, 42)
    tw = text_width(d, TAGLINE, f_tag, tr)
    tx = CX - tw // 2
    ty = caption_y + 76
    draw_tracked(d, (tx + 3, ty + 3), TAGLINE, f_tag, (0, 0, 0, 190), tr)
    draw_tracked(d, (tx, ty), TAGLINE, f_tag, (233, 199, 130, 255), tr)

    img.convert("RGB").save(OUT, "PNG")
    return OUT


if __name__ == "__main__":
    src = sys.argv[1] if len(sys.argv) > 1 else ""
    if not os.path.isfile(src):
        print("usage: _compose_mines_hero.py <mines_art.png> [caption_y]", file=sys.stderr)
        raise SystemExit(1)
    cap_y = int(sys.argv[2]) if len(sys.argv) > 2 else 470
    print("wrote", compose(src, cap_y))
