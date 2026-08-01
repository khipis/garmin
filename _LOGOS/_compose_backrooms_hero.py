#!/usr/bin/env python3
"""Compose the Backrooms Run store hero at 1440x720.

House layout: watch with a live gameplay face on the left, game name and
BY BITOCHI on the right, margins kept clear for the LEADERBOARD stamp (top
left) and the bitochi.com pill (bottom right), both applied afterwards by
`.cursor/skills/make-game/scripts/stamp_one.py`.

Two pieces of real artwork do the heavy lifting, matching the billiards hero:

  backrooms_bg2.png     key art the type sits on
  backrooms_watch.png   photoreal three-quarter watch, blank black screen,
                        shot against chroma green

The watch is keyed off the green, its screen is located by finding the large
dark blob inside the case, and the game frame is warped into exactly that
shape — so the display follows the real perspective of the render instead of
being a flat circle pasted on top.

    python3 _LOGOS/_compose_backrooms_hero.py [--seed N] [--no-stamp]
"""
from __future__ import annotations

import argparse
import importlib.util
import os
import subprocess
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

W, H = 1440, 720
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, ".."))
ASSETS = os.path.join(
    os.path.expanduser("~"), ".cursor/projects/Users-kkorolczuk-work-garmin/assets"
)
BG = os.path.join(ASSETS, "backrooms_bg2.png")
WATCH = os.path.join(ASSETS, "backrooms_watch.png")
OUT = os.path.join(HERE, "backrooms_hero.png")

SERIF = "/System/Library/Fonts/Supplemental/Georgia Bold.ttf"
SERIF_IT = "/System/Library/Fonts/Supplemental/Georgia Italic.ttf"
SANS = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"

TITLE = "BACKROOMS"
KICKER = "RUN"
TAGLINE = "Find the exit. Keep your mind."
BYLINE = "BY BITOCHI"

GOLD_HI = (255, 236, 168)
GOLD_LO = (188, 126, 20)
EDGE_HI = (122, 78, 10)
EDGE_LO = (58, 34, 4)


def font(path: str, size: int) -> ImageFont.FreeTypeFont:
    try:
        return ImageFont.truetype(path, size)
    except OSError:
        return ImageFont.load_default()


def cover(im: Image.Image, w: int, h: int) -> Image.Image:
    im = im.convert("RGB")
    s = max(w / im.width, h / im.height)
    im = im.resize((max(1, int(im.width * s)), max(1, int(im.height * s))), Image.LANCZOS)
    left, top = (im.width - w) // 2, (im.height - h) // 2
    return im.crop((left, top, left + w, top + h))


def vgrad(size, top_col, bot_col) -> Image.Image:
    g = Image.new("RGB", size)
    d = ImageDraw.Draw(g)
    for y in range(size[1]):
        t = y / max(1, size[1] - 1)
        d.line(
            [(0, y), (size[0], y)],
            fill=tuple(int(top_col[i] + (bot_col[i] - top_col[i]) * t) for i in range(3)),
        )
    return g


def linear_scrim(w: int, h: int, stops) -> Image.Image:
    mask = Image.new("L", (w, 1), 0)
    px = mask.load()
    for x in range(w):
        u = x / (w - 1)
        a = stops[0][1]
        for i in range(len(stops) - 1):
            x0, a0 = stops[i]
            x1, a1 = stops[i + 1]
            if x0 <= u <= x1:
                t = 0.0 if x1 == x0 else (u - x0) / (x1 - x0)
                a = a0 + (a1 - a0) * t
                break
            if u > x1:
                a = a1
        px[x, 0] = int(a)
    return mask.resize((w, h))


# ── Watch ────────────────────────────────────────────────────────────────────
def key_green(im: Image.Image) -> Image.Image:
    """Drop the chroma background and pull the green spill out of the edges."""
    im = im.convert("RGB")
    r, g, b = im.split()
    rb = ImageChops.lighter(r, b)
    greenness = ImageChops.subtract(g, rb)
    alpha = greenness.point(lambda v: 0 if v > 34 else 255)
    alpha = alpha.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.6))
    # Despill: anywhere green leads, clamp it back to the red/blue level.
    g = ImageChops.subtract(g, greenness)
    out = Image.merge("RGB", (r, g, b)).convert("RGBA")
    out.putalpha(alpha)
    return out


def screen_mask(watch: Image.Image) -> Image.Image:
    """Mask of the blank display.

    The strap is nearly as black as the screen, so thresholding on darkness
    alone selects half the watch. Instead: threshold, erode until the display
    is no longer bridged to anything, then flood fill outward from a point
    guaranteed to be inside it — the middle of the widest run of dark pixels
    across the centre of the frame — and dilate the result back.
    """
    r, g, b = watch.convert("RGB").split()
    brightest = ImageChops.lighter(ImageChops.lighter(r, g), b)
    dark = brightest.point(lambda v: 255 if v < 40 else 0)
    dark = ImageChops.multiply(
        dark, watch.split()[3].point(lambda v: 255 if v > 128 else 0)
    )
    for _ in range(4):
        dark = dark.filter(ImageFilter.MinFilter(5))

    px = dark.load()
    wd, ht = dark.size
    seed, best = None, 0
    for y in range(int(ht * 0.34), int(ht * 0.66), 3):
        run = 0
        for x in range(wd):
            if px[x, y] > 128:
                run += 1
                if run > best:
                    best, seed = run, (x - run // 2, y)
            else:
                run = 0
    if seed is None or best < 40:
        raise SystemExit("could not find the watch display")

    ImageDraw.floodfill(dark, seed, 100)
    only = dark.point(lambda v: 255 if 60 < v < 140 else 0)
    for _ in range(4):
        only = only.filter(ImageFilter.MaxFilter(5))
    return only


def build_watch(face: Image.Image, height: int):
    """Keyed watch with the game frame warped into its display."""
    w = key_green(Image.open(WATCH))
    mask = screen_mask(w)
    box = mask.getbbox()
    if box is None:
        raise SystemExit("could not find the watch display")

    x0, y0, x1, y1 = box
    # Stretch rather than crop: the game frame is a circle on black, the display
    # is that same circle seen at an angle, so mapping one onto the other is
    # exactly the perspective the render already has.
    face_fit = face.convert("RGBA").resize((x1 - x0, y1 - y0), Image.LANCZOS)
    # Feather the join so there is no hard pixel step at the bezel.
    soft = mask.crop(box).filter(ImageFilter.GaussianBlur(1.2))
    w.paste(face_fit, (x0, y0), soft)

    # Inner shadow around the rim, so the display sits under the glass.
    inner = Image.new("RGBA", w.size, (0, 0, 0, 0))
    shrunk = mask.copy()
    for _ in range(3):
        shrunk = shrunk.filter(ImageFilter.MinFilter(9))
    rim = ImageChops.subtract(mask, shrunk).filter(ImageFilter.GaussianBlur(7))
    inner.paste((0, 0, 0, 200), (0, 0), rim)
    w = Image.alpha_composite(w, inner)

    # Glass: a diagonal sheen over the upper-left of the crystal only.
    gl = Image.new("RGBA", w.size, (0, 0, 0, 0))
    ImageDraw.Draw(gl).polygon(
        [(x0 - 40, y0 + (y1 - y0) * 0.66), (x0 + (x1 - x0) * 0.80, y0 - 40),
         (x1 + 40, y0 - 40), (x0 - 40, y0 + (y1 - y0) * 1.05)],
        fill=(255, 255, 255, 30),
    )
    full = Image.new("L", w.size, 0)
    full.paste(mask, (0, 0))
    gl.putalpha(ImageChops.multiply(gl.split()[3], full))
    w = Image.alpha_composite(w, gl.filter(ImageFilter.GaussianBlur(10)))

    s = height / w.height
    w = w.resize((max(1, int(w.width * s)), height), Image.LANCZOS)
    return w, (
        int((x0 + x1) / 2 * s), int((y0 + y1) / 2 * s), int((x1 - x0) * s)
    )


def render_face(seed: int) -> Image.Image:
    spec = importlib.util.spec_from_file_location(
        "brface", os.path.join(HERE, "_compose_backrooms_face.py")
    )
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    mp = m.gen(seed, 0)
    b = m.best_view(mp)
    if b is None:
        raise SystemExit(f"seed {seed} has no usable camera")
    return m.render(mp, b[1], b[2], b[3])


# ── Type ─────────────────────────────────────────────────────────────────────
def engraved(text: str, fnt, tracking: int, stroke: int):
    """Heavy serif with a bevelled gold edge. Returns RGBA + its own mask."""
    probe = ImageDraw.Draw(Image.new("L", (1, 1)))
    widths = [probe.textlength(c, font=fnt) for c in text]
    tw = int(sum(widths) + tracking * (len(text) - 1))
    asc, desc = fnt.getmetrics()
    th = asc + desc
    pad = stroke * 3 + 14
    size = (tw + pad * 2, th + pad * 2)

    def stamp(sw):
        m = Image.new("L", size, 0)
        md = ImageDraw.Draw(m)
        x = pad
        for i, c in enumerate(text):
            md.text((x, pad), c, font=fnt, fill=255,
                    stroke_width=sw, stroke_fill=255)
            x += widths[i] + tracking
        return m

    core = stamp(0)
    outer = stamp(stroke)
    edge = ImageChops.subtract(outer, core)

    img = Image.new("RGBA", size, (0, 0, 0, 0))
    img.paste(vgrad(size, EDGE_HI, EDGE_LO), (0, 0), edge)
    img.paste(vgrad(size, GOLD_HI, GOLD_LO), (0, 0), core)

    # Bevel: the top lip of every stroke catches the light, the bottom does not.
    lip = ImageChops.subtract(core, ImageChops.offset(core, 0, 4))
    img.paste((255, 250, 224, 235), (0, 0), lip.filter(ImageFilter.GaussianBlur(1)))
    shade = ImageChops.subtract(core, ImageChops.offset(core, 0, -5))
    img.paste((120, 72, 8, 190), (0, 0), shade.filter(ImageFilter.GaussianBlur(1.4)))

    # Trim the render padding so callers can stack these by height alone.
    box = outer.getbbox()
    return img.crop(box), outer.crop(box)


def ornament(d: ImageDraw.ImageDraw, cx: int, y: int, half: int, col):
    d.line([(cx - half, y), (cx - 30, y)], fill=col, width=2)
    d.line([(cx + 30, y), (cx + half, y)], fill=col, width=2)
    for dx, r in ((-17, 5), (0, 9), (17, 5)):
        d.polygon(
            [(cx + dx, y - r), (cx + dx + r, y), (cx + dx, y + r), (cx + dx - r, y)],
            fill=col,
        )


def compose(seed: int) -> str:
    base = cover(Image.open(BG), W, H).convert("RGBA")
    base = Image.blend(base, Image.new("RGBA", (W, H), (7, 7, 5, 255)), 0.16)

    scrim = Image.new("RGBA", (W, H), (5, 5, 4, 255))
    scrim.putalpha(linear_scrim(W, H, [(0.0, 90), (0.28, 40), (0.46, 105), (1.0, 140)]))
    base = Image.alpha_composite(base, scrim)

    vig = Image.new("L", (W, H), 0)
    ImageDraw.Draw(vig).ellipse([-W // 4, -H // 2, W + W // 4, H + H // 2], fill=255)
    vig = vig.filter(ImageFilter.GaussianBlur(150))
    dark = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    dark.putalpha(ImageChops.invert(vig).point(lambda v: int(v * 0.72)))
    base = Image.alpha_composite(base, dark)

    wi, (scx, scy, sdia) = build_watch(render_face(seed), 664)
    wx, wy = 6, (H - wi.height) // 2

    # The display lights the room it is standing in.
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gcx, gcy = wx + scx, wy + scy
    for r, a in ((int(sdia * 1.5), 42), (int(sdia * 1.0), 38), (int(sdia * 0.6), 30)):
        gd.ellipse([gcx - r, gcy - r, gcx + r, gcy + r], fill=(216, 184, 72, a))
    base = Image.alpha_composite(base, glow.filter(ImageFilter.GaussianBlur(90)))
    base.paste(wi, (wx, wy), wi)

    # ── Type block, in the space the watch leaves
    left = wx + wi.width - 30
    cx = (left + W) // 2
    max_w = W - left - 96

    size = 118
    while size > 44:
        t_img, t_mask = engraved(TITLE, font(SERIF, size), 3, max(4, size // 22))
        if t_img.width <= max_w:
            break
        size -= 4
    k_img, _ = engraved(KICKER, font(SERIF, int(size * 0.60)), 18,
                        max(3, size // 30))

    tag_f = font(SERIF_IT, max(22, int(size * 0.29)))
    by_f = font(SANS, max(18, int(size * 0.20)))
    tag_h = sum(tag_f.getmetrics())
    by_h = sum(by_f.getmetrics())
    pad_x, pad_y = 28, 10
    box_h = by_h + pad_y * 2

    gaps = (18, 26, 30, 26)
    block = (t_img.height + gaps[0] + k_img.height + gaps[1] + tag_h
             + gaps[2] + 18 + gaps[3] + box_h)
    y = (H - block) // 2

    halo = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    hx = cx - t_img.width // 2
    halo.paste((255, 206, 96, 140), (hx, y), t_mask)
    base = Image.alpha_composite(base, halo.filter(ImageFilter.GaussianBlur(32)))
    drop = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    drop.paste((0, 0, 0, 225), (hx + 5, y + 9), t_mask)
    base = Image.alpha_composite(base, drop.filter(ImageFilter.GaussianBlur(7)))
    base.paste(t_img, (hx, y), t_img)
    y += t_img.height + gaps[0]

    base.paste(k_img, (cx - k_img.width // 2, y), k_img)
    y += k_img.height + gaps[1]

    d = ImageDraw.Draw(base)
    tw = d.textlength(TAGLINE, font=tag_f)
    d.text((cx - tw / 2 + 2, y + 3), TAGLINE, font=tag_f, fill=(0, 0, 0, 205))
    d.text((cx - tw / 2, y), TAGLINE, font=tag_f, fill=(244, 240, 228, 255))
    y += tag_h + gaps[2]

    ornament(d, cx, y + 9, min(250, max_w // 2 - 20), (198, 152, 58, 225))
    y += 18 + gaps[3]

    bw = d.textlength(BYLINE, font=by_f)
    d.rectangle(
        [cx - bw / 2 - pad_x, y, cx + bw / 2 + pad_x, y + box_h],
        outline=(198, 152, 58, 210), width=2,
    )
    d.text((cx - bw / 2, y + pad_y - 2), BYLINE, font=by_f, fill=(240, 236, 224, 255))

    base.convert("RGB").save(OUT, "PNG")
    return OUT


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--seed", type=int, default=311)
    ap.add_argument("--no-stamp", action="store_true")
    a = ap.parse_args()
    print("wrote", compose(a.seed))
    if not a.no_stamp:
        subprocess.run(
            [sys.executable,
             os.path.join(REPO, ".cursor/skills/make-game/scripts/stamp_one.py"),
             "backrooms"],
            check=True,
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
