#!/usr/bin/env python3
"""Compose the DAILY SPORT CHALLENGE hero (1440x720).

Three layers, in the house style: cinematic key art, a real fēnix render with a
real frame of the game on its screen, and the title block on the right.

The watch is the simulator's own device render with the display swapped for a
captured gameplay frame, so what the store page shows is genuinely what the
game draws — no mockup, no re-illustration.

Stamps (LEADERBOARD / bitochi.com) are applied afterwards by
.cursor/skills/make-game/scripts/stamp_one.py.
"""
from __future__ import annotations

import os
import sys

from PIL import (Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter,
                 ImageFont)

W, H = 1440, 720
REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(REPO, "_LOGOS", "dailysport_hero.png")

BOLD = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
BLACK = "/System/Library/Fonts/Supplemental/Arial Black.ttf"

# Geometry of the simulator window, as fractions of the grab.
#
# DISP_* is the square _drive.py crops. GLASS_* is the lit disc inside it,
# measured off the game's own clock ring — it is a few pixels up and left of
# the crop centre, because the crop square was eyeballed and the display is
# not quite where it looks. Pasting the frame masked to the true glass keeps
# the device's real bezel instead of laying a second, misaligned copy on top.
DISP_CX, DISP_CY, DISP_R = 0.519, 0.490, 0.372
GLASS_CX, GLASS_CY, GLASS_R = 0.5148, 0.4843, 0.3282


# ── Watch ───────────────────────────────────────────────────────────────────
def build_watch(window_png: str, face_png: str) -> Image.Image:
    """Device render with the gameplay frame dropped into the display and the
    simulator's white page keyed out."""
    win = Image.open(window_png).convert("RGBA")
    w, h = win.size
    cx, cy = int(DISP_CX * w), int(DISP_CY * h)
    r = int(DISP_R * w)

    # The simulator renders the panel through a matte film that flattens it.
    # A touch of contrast and saturation puts the screen back where a real
    # MIP display sits in daylight.
    face = Image.open(face_png).convert("RGB")
    face = ImageEnhance.Contrast(face).enhance(1.16)
    face = ImageEnhance.Color(face).enhance(1.22)
    face = face.convert("RGBA").resize((2 * r, 2 * r), Image.LANCZOS)

    gr = GLASS_R * w
    gx = GLASS_CX * w - (cx - r)          # glass centre inside the face square
    gy = GLASS_CY * h - (cy - r)
    ss = 4
    mask = Image.new("L", (2 * r * ss, 2 * r * ss), 0)
    ImageDraw.Draw(mask).ellipse(
        [(gx - gr) * ss, (gy - gr) * ss, (gx + gr) * ss, (gy + gr) * ss], fill=255)
    mask = mask.resize((2 * r, 2 * r), Image.LANCZOS)
    win.paste(face, (cx - r, cy - r), mask)

    # Drop the window chrome: the title bar is dark and would survive any
    # brightness key, and the toolbar strip below the device is not the watch.
    win = win.crop((int(w * 0.018), int(h * 0.050),
                    int(w * 0.982), int(h * 0.942)))
    w, h = win.size

    # Key out the simulator's page — neutral and bright, unlike anything on
    # the device itself, which is graphite, rubber and a dark screen.
    px = win.load()
    for y in range(h):
        for x in range(w):
            rr, gg, bb, _ = px[x, y]
            lo = min(rr, gg, bb)
            hi = max(rr, gg, bb)
            if lo > 196 and hi - lo < 16:
                px[x, y] = (rr, gg, bb, 0)

    box = win.split()[3].getbbox()
    return win.crop(box) if box else win


def drop_shadow(img: Image.Image, blur: int, offset: tuple, strength: int):
    """Soft contact shadow, so the watch sits in the scene instead of on it."""
    a = img.split()[3].filter(ImageFilter.GaussianBlur(blur))
    a = a.point(lambda v: min(255, int(v * strength / 100)))
    sh = Image.new("RGBA", img.size, (0, 0, 0, 255))
    sh.putalpha(a)
    return sh, offset


# ── Type ────────────────────────────────────────────────────────────────────
def tracked_mask(size, text, font, tracking):
    """Render letterspaced text to an L mask, returned with its width."""
    tmp = Image.new("L", (10, 10))
    d = ImageDraw.Draw(tmp)
    width = int(sum(d.textlength(c, font=font) + tracking for c in text) - tracking)
    mask = Image.new("L", size, 0)
    md = ImageDraw.Draw(mask)
    x = (size[0] - width) // 2
    for c in text:
        md.text((x, 0), c, font=font, fill=255)
        x += d.textlength(c, font=font) + tracking
    return mask, width


def gradient(size, top, bot):
    g = Image.new("RGB", (1, size[1]))
    for y in range(size[1]):
        f = y / max(1, size[1] - 1)
        g.putpixel((0, y), tuple(int(top[i] + (bot[i] - top[i]) * f) for i in range(3)))
    return g.resize(size, Image.BILINEAR)


def glow_text(base, cx, cy, text, font, tracking, top, bot, glow, glow_r=18):
    """Gradient-filled caps with a coloured halo and a hard dark rim — the
    combination is what keeps a title legible over busy key art."""
    fh = font.size * 2
    size = (base.width, fh)
    mask, tw = tracked_mask(size, text, font, tracking)
    box = mask.getbbox()
    if box is None:
        return
    x0, y0 = cx - base.width // 2, cy - fh // 2

    halo = Image.new("RGBA", base.size, (0, 0, 0, 0))
    halo.paste(Image.new("RGBA", size, glow + (255,)), (x0, y0), mask)
    halo = halo.filter(ImageFilter.GaussianBlur(glow_r))
    base.alpha_composite(halo)
    base.alpha_composite(halo)

    rim = Image.new("RGBA", base.size, (0, 0, 0, 0))
    rim.paste(Image.new("RGBA", size, (0, 0, 0, 235)), (x0, y0), mask)
    for dx, dy in ((-3, 0), (3, 0), (0, -3), (0, 3), (-2, -2), (2, 2), (-2, 2), (2, -2)):
        base.alpha_composite(ImageChops.offset(rim, dx, dy))

    body = Image.new("RGBA", base.size, (0, 0, 0, 0))
    fill = gradient(size, top, bot).convert("RGBA")
    body.paste(fill, (x0, y0), mask)
    base.alpha_composite(body)


def scrim(img, cx, cy, rx, ry, strength, blur=90):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).ellipse([cx - rx, cy - ry, cx + rx, cy + ry],
                                  fill=(2, 2, 6, strength))
    return Image.alpha_composite(img, layer.filter(ImageFilter.GaussianBlur(blur)))


# ── Compose ─────────────────────────────────────────────────────────────────
def compose(art_png: str, window_png: str, face_png: str) -> str:
    art = Image.open(art_png).convert("RGBA")
    aw, ah = art.size
    target_h = int(aw / 2)
    if ah > target_h * 1.02:
        # Taller than 2:1 — crop rather than squash, keeping the subject high
        # in frame and trimming the floor.
        top = int((ah - target_h) * 0.30)
        art = art.crop((0, top, aw, top + target_h))
    img = art.resize((W, H), Image.LANCZOS)

    # Darken behind the title so the type never fights the crowd lights.
    img = scrim(img, 995, 360, 400, 230, 205)
    img = scrim(img, 360, 400, 330, 300, 120)

    watch = build_watch(window_png, face_png)
    wh = int(H * 0.985)
    watch = watch.resize((int(watch.width * wh / watch.height), wh), Image.LANCZOS)
    wx, wy = 355 - watch.width // 2, (H - watch.height) // 2

    # Warm backlight behind the case. The simulator renders the device as flat
    # graphite, which disappears into a black key art; a rim of stadium light
    # behind it is what separates the two.
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse(
        [wx - 60, wy - 30, wx + watch.width + 60, wy + watch.height + 30],
        fill=(255, 122, 20, 120))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(70)))

    sh, off = drop_shadow(watch, 34, (22, 26), 95)
    img.alpha_composite(sh, (wx + off[0], wy + off[1]))
    img.alpha_composite(ImageEnhance.Contrast(watch).enhance(1.10), (wx, wy))

    cx = 1000
    f_main = ImageFont.truetype(BLACK, 96)
    f_sub = ImageFont.truetype(BOLD, 52)
    f_by = ImageFont.truetype(BOLD, 40)

    glow_text(img, cx, 258, "DAILY SPORT", f_main, 4,
              (255, 236, 196), (255, 128, 12), (255, 96, 0), 22)
    glow_text(img, cx, 356, "CHALLENGE", f_sub, 16,
              (255, 226, 150), (255, 168, 30), (180, 70, 0), 14)

    d = ImageDraw.Draw(img)
    ry = 424
    d.line([(cx - 190, ry), (cx - 22, ry)], fill=(255, 150, 40, 220), width=3)
    d.line([(cx + 22, ry), (cx + 190, ry)], fill=(255, 150, 40, 220), width=3)
    d.polygon([(cx, ry - 12), (cx + 12, ry), (cx, ry + 12), (cx - 12, ry)],
              fill=(255, 190, 80, 255))

    by_a, by_b = "by ", "Bitochi"
    wa = d.textlength(by_a, font=f_by)
    wb = d.textlength(by_b, font=f_by)
    bx = cx - int(wa + wb) // 2
    d.text((bx + 2, 474), by_a, font=f_by, fill=(0, 0, 0, 180))
    d.text((bx, 472), by_a, font=f_by, fill=(226, 226, 232, 255))
    d.text((bx + wa + 2, 474), by_b, font=f_by, fill=(0, 0, 0, 180))
    d.text((bx + wa, 472), by_b, font=f_by, fill=(255, 170, 40, 255))

    # The strip has to clear the bottom-right bitochi.com stamp, so it is set
    # tighter than the title block and kept well inside the right margin.
    tag = "SIX SPORTS  ·  ONE DAILY CHALLENGE"
    f_tag = ImageFont.truetype(BOLD, 24)
    mask, tw = tracked_mask((W, 60), tag, f_tag, 2)
    tint = Image.new("RGBA", (W, 60), (198, 208, 226, 235))
    img.paste(tint, (cx - W // 2, 556), mask)

    img.convert("RGB").save(OUT, "PNG")
    return OUT


if __name__ == "__main__":
    if len(sys.argv) < 4:
        print("usage: _compose_dailysport_hero.py <art.png> <window.png> <face.png>",
              file=sys.stderr)
        raise SystemExit(1)
    print("wrote", compose(sys.argv[1], sys.argv[2], sys.argv[3]))
