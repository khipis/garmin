#!/usr/bin/env python3
"""Compose a 1440x720 store hero from cinematic key art + a typeset title block.

The key art must already contain the watch on the left and empty-ish scenery on
the right; this lays the gradient title, subtitle, rule and signature over the
right two thirds. Stamps (LEADERBOARD / bitochi.com) are applied afterwards by
.cursor/skills/make-game/scripts/stamp_one.py.

Usage:
  _compose_epic_hero.py <slug> <keyart.png> --title "DUNGEON|MASTER" \
      --sub "WATCH CRAWLER RPG" --top RRGGBB --bot RRGGBB --sub-col RRGGBB \
      --glow RRGGBB --accent RRGGBB [--bias 0.6] [--cx 1015] [--cy 330]
"""
from __future__ import annotations

import argparse
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1440, 720
LOGOS = os.path.dirname(os.path.abspath(__file__))

BLACK_F = "/System/Library/Fonts/Supplemental/Arial Black.ttf"
BOLD_F = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"


def rgb(s: str):
    s = s.lstrip("#")
    return tuple(int(s[i : i + 2], 16) for i in (0, 2, 4))


def tracked_width(d, s, f, tr):
    return int(sum(d.textlength(ch, font=f) + tr for ch in s) - tr)


def draw_tracked(d, xy, s, f, fill, tr):
    x, y = xy
    for ch in s:
        d.text((x, y), ch, font=f, fill=fill)
        x += d.textlength(ch, font=f) + tr


def fit_font(path, text, tr_ratio, target_w, hi=200, lo=20):
    """Largest size whose letterspaced width still fits target_w."""
    probe = ImageDraw.Draw(Image.new("L", (8, 8)))
    best = lo
    while lo <= hi:
        mid = (lo + hi) // 2
        f = ImageFont.truetype(path, mid)
        if tracked_width(probe, text, f, int(mid * tr_ratio)) <= target_w:
            best, lo = mid, mid + 1
        else:
            hi = mid - 1
    return ImageFont.truetype(path, best), int(best * tr_ratio)


def crop_2x1(src_path: str, bias: float) -> Image.Image:
    src = Image.open(src_path).convert("RGB")
    sw, sh = src.size
    th = sw // 2
    if th <= sh:
        top = int((sh - th) * bias)
        src = src.crop((0, top, sw, top + th))
    else:  # too flat already — pad-crop horizontally instead
        tw = sh * 2
        left = int((sw - tw) * 0.5)
        src = src.crop((left, 0, left + tw, sh))
    return src.resize((W, H), Image.LANCZOS).convert("RGBA")


def scrim(img, cx, cy, rx, ry, strength):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).ellipse(
        [cx - rx, cy - ry, cx + rx, cy + ry], fill=(3, 4, 7, strength)
    )
    return Image.alpha_composite(img, layer.filter(ImageFilter.GaussianBlur(90)))


def gradient_text(img, x, y, text, font, tr, c_top, c_bot, glow, glow_r=18):
    """Letterspaced text filled with a vertical gradient, plus glow + shadow."""
    mask = Image.new("L", img.size, 0)
    draw_tracked(ImageDraw.Draw(mask), (x, y), text, font, 255, tr)
    bbox = mask.getbbox()
    if bbox is None:
        return
    y0, y1 = bbox[1], bbox[3]

    grad = Image.new("RGBA", img.size)
    gd = ImageDraw.Draw(grad)
    span = max(1, y1 - y0)
    for gy in range(y0, y1 + 1):
        t = (gy - y0) / span
        col = tuple(int(c_top[i] + (c_bot[i] - c_top[i]) * t) for i in range(3))
        gd.line([(0, gy), (img.size[0], gy)], fill=(*col, 255))

    halo = Image.new("RGBA", img.size, (*glow, 0))
    halo.putalpha(mask.filter(ImageFilter.GaussianBlur(glow_r)).point(lambda v: int(v * 0.85)))
    img.alpha_composite(halo)

    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    shadow.paste((0, 0, 0, 190), (0, 0), mask.filter(ImageFilter.GaussianBlur(5)))
    img.alpha_composite(shadow.transform(
        img.size, Image.AFFINE, (1, 0, -5, 0, 1, -6), resample=Image.BILINEAR))

    img.paste(grad, (0, 0), mask)


def compose(a) -> str:
    img = crop_2x1(a.art, a.bias)
    lines = [s for s in a.title.split("|") if s]

    box = int(W * a.box)
    fonts = [fit_font(BLACK_F, s, 0.055, box) for s in lines]
    f_sub, tr_sub = fit_font(BOLD_F, a.sub, 0.34, int(box * 0.88))
    f_by = ImageFont.truetype(BOLD_F, 46)

    line_h = [int(f.size * 0.95) for f, _ in fonts]
    sub_h = int(f_sub.size * 1.9)
    block_h = sum(line_h) + sub_h + 150
    top = a.cy - block_h // 2

    img = scrim(img, a.cx, a.cy, int(box * 0.72), block_h // 2 + 40, a.scrim)
    d = ImageDraw.Draw(img)

    y = top
    for (f, tr), s, lh in zip(fonts, lines, line_h):
        x = a.cx - tracked_width(d, s, f, tr) // 2
        gradient_text(img, x, y - int(f.size * 0.22), s, f, tr,
                      rgb(a.top), rgb(a.bot), rgb(a.glow))
        y += lh
    d = ImageDraw.Draw(img)

    y += int(f_sub.size * 0.35)
    sw = tracked_width(d, a.sub, f_sub, tr_sub)
    sx = a.cx - sw // 2
    draw_tracked(d, (sx + 3, y + 3), a.sub, f_sub, (0, 0, 0, 190), tr_sub)
    draw_tracked(d, (sx, y), a.sub, f_sub, (*rgb(a.sub_col), 255), tr_sub)
    y += int(f_sub.size * 1.55)

    accent = rgb(a.accent)
    half, dia = int(box * 0.34), 11
    d.line([(a.cx - half, y), (a.cx - dia - 14, y)], fill=(*accent, 170), width=3)
    d.line([(a.cx + dia + 14, y), (a.cx + half, y)], fill=(*accent, 170), width=3)
    d.polygon([(a.cx, y - dia), (a.cx + dia, y), (a.cx, y + dia), (a.cx - dia, y)],
              fill=(*accent, 240))
    y += 40

    by_a, by_b = "by ", "Bitochi"
    wa, wb = d.textlength(by_a, font=f_by), d.textlength(by_b, font=f_by)
    bx = a.cx - int(wa + wb) // 2
    d.text((bx + 3, y + 3), by_a, font=f_by, fill=(0, 0, 0, 190))
    d.text((bx, y), by_a, font=f_by, fill=(238, 238, 242, 255))
    d.text((bx + wa + 3, y + 3), by_b, font=f_by, fill=(0, 0, 0, 190))
    d.text((bx + wa, y), by_b, font=f_by, fill=(*accent, 255))

    out = os.path.join(LOGOS, f"{a.slug}_hero.png")
    img.convert("RGB").save(out, "PNG")
    return out


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("slug")
    p.add_argument("art")
    p.add_argument("--title", required=True, help="pipe-separated lines")
    p.add_argument("--sub", required=True)
    p.add_argument("--top", default="FFE9A8")
    p.add_argument("--bot", default="E07A1F")
    p.add_argument("--sub-col", dest="sub_col", default="E9DCBE")
    p.add_argument("--glow", default="8A3A08")
    p.add_argument("--accent", default="F0A83C")
    p.add_argument("--bias", type=float, default=0.6)
    p.add_argument("--box", type=float, default=0.52)
    p.add_argument("--cx", type=int, default=990)
    p.add_argument("--cy", type=int, default=330)
    p.add_argument("--scrim", type=int, default=170)
    a = p.parse_args()
    print("wrote", compose(a))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
