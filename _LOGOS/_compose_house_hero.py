#!/usr/bin/env python3
"""Compose store heroes in the Tower Defense layout (1440x720).

That hero is the one the catalog is judged against, so this reproduces its
proportions rather than inventing new ones per game:

  left    photoreal three-quarter fēnix, ~97% of the canvas height, the game
          frame warped into the display so it follows the real perspective
  right   title in Arial Black — every line at one shared size, the largest
          that fits the block, so a short line is narrower but never taller —
          then a letterspaced subtitle, a hairline rule with a diamond, and
          "by Bitochi"

No taglines: Tower Defense, Creatures and Mines all stop at the signature, and
the extra line is what made Backrooms and Daily Sport read as a different set.

Stamps (LEADERBOARD / bitochi.com) are applied afterwards by
.cursor/skills/make-game/scripts/stamp_one.py.

    python3 _LOGOS/_compose_house_hero.py [slug ...]
"""
from __future__ import annotations

import importlib.util
import os
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1440, 720
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, ".."))
ASSETS = os.path.join(os.path.expanduser("~"),
                      ".cursor/projects/Users-kkorolczuk-work-garmin/assets")

BLACK_F = "/System/Library/Fonts/Supplemental/Arial Black.ttf"
BOLD_F = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"

# Measured off towerdefense_hero.png.
WATCH_CX, WATCH_CY, WATCH_H = 300, 360, 694
TITLE_CX, TITLE_BOX, BLOCK_CY = 1022, 790, 312

# Display disc inside a simulator window grab.
DISP_CX, DISP_CY, DISP_R = 0.519, 0.490, 0.372


def load(name: str):
    spec = importlib.util.spec_from_file_location(
        name.strip("_"), os.path.join(HERE, name + ".py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


# ── Faces ────────────────────────────────────────────────────────────────────
def face_zombiesurvival():
    return load("_compose_zombie_face").render(41)


def face_backrooms():
    # The face renderer tracks Renderer.mc; the hero script has its own older
    # copy, and heroes are supposed to show the game as it actually ships.
    return load("_compose_backrooms_face").render_face(31337)


def face_dailysport():
    """Cropped out of a simulator grab. Mid-aim rather than mid-result: the
    frames that show a score also show the miss commentary under it."""
    im = Image.open("/tmp/ds2/08_q.png").convert("RGB")
    w, h = im.size
    cx, cy, r = int(DISP_CX * w), int(DISP_CY * h), int(DISP_R * w)
    return im.crop((cx - r, cy - r, cx + r, cy + r))


GAMES = {
    "zombiesurvival": {
        "art": "zombie_keyart.png",
        "face": face_zombiesurvival,
        "bias": 0.34,
        "title": ["ZOMBIE", "SURVIVAL"],
        "sub": "LAST STAND",
        "top": (238, 255, 214),
        "bot": (58, 152, 20),
        "glow": (26, 96, 0),
        "sub_col": (255, 186, 92),
        "accent": (140, 255, 63),
    },
    "backrooms": {
        "art": "backrooms_bg2.png",
        "face": face_backrooms,
        "bias": 0.42,
        "title": ["BACKROOMS"],
        "sub": "FIND THE EXIT",
        "top": (255, 248, 214),
        "bot": (206, 152, 26),
        "glow": (92, 60, 0),
        "sub_col": (238, 214, 150),
        "accent": (240, 196, 76),
    },
    "dailysport": {
        "art": "dailysport_keyart.png",
        "face": face_dailysport,
        "bias": 0.30,
        "title": ["DAILY SPORT"],
        "sub": "CHALLENGE",
        "top": (255, 250, 236),
        "bot": (240, 122, 16),
        "glow": (128, 44, 0),
        "sub_col": (255, 208, 130),
        "accent": (255, 158, 46),
    },
}


# ── Plate ────────────────────────────────────────────────────────────────────
def crop_2x1(path: str, bias: float) -> Image.Image:
    src = Image.open(path).convert("RGB")
    sw, sh = src.size
    th = sw // 2
    if th <= sh:
        top = int((sh - th) * bias)
        src = src.crop((0, top, sw, top + th))
    else:
        tw = sh * 2
        left = (sw - tw) // 2
        src = src.crop((left, 0, left + tw, sh))
    return src.resize((W, H), Image.LANCZOS).convert("RGBA")


def scrim(img, cx, cy, rx, ry, strength, blur=90):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).ellipse([cx - rx, cy - ry, cx + rx, cy + ry],
                                  fill=(3, 4, 7, strength))
    return Image.alpha_composite(img, layer.filter(ImageFilter.GaussianBlur(blur)))


def place_watch(img, face, accent):
    br = load("_compose_backrooms_hero")
    watch, _disc = br.build_watch(face, WATCH_H)
    wx, wy = WATCH_CX - watch.width // 2, WATCH_CY - watch.height // 2

    # A wash of the game's own accent behind the case, so a black bezel does
    # not disappear into whatever the key art happens to be doing back there.
    bloom = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(bloom).ellipse(
        [WATCH_CX - 300, WATCH_CY - 300, WATCH_CX + 300, WATCH_CY + 300],
        fill=accent + (46,))
    img.alpha_composite(bloom.filter(ImageFilter.GaussianBlur(130)))

    sh = Image.new("RGBA", watch.size, (0, 0, 0, 255))
    sh.putalpha(watch.split()[3]
                .filter(ImageFilter.GaussianBlur(30))
                .point(lambda v: min(255, v * 96 // 100)))
    img.alpha_composite(sh, (wx + 20, wy + 24))
    img.alpha_composite(watch, (wx, wy))
    return img


# ── Type ─────────────────────────────────────────────────────────────────────
def tracked_width(d, s, f, tr):
    return int(sum(d.textlength(c, font=f) + tr for c in s) - tr)


def draw_tracked(d, xy, s, f, fill, tr):
    x, y = xy
    for c in s:
        d.text((x, y), c, font=f, fill=fill)
        x += d.textlength(c, font=f) + tr


def fit_size(path, texts, tr_ratio, target_w, hi=190, lo=24):
    """Largest size at which every one of texts still fits target_w."""
    probe = ImageDraw.Draw(Image.new("L", (8, 8)))
    best = lo
    while lo <= hi:
        mid = (lo + hi) // 2
        f = ImageFont.truetype(path, mid)
        tr = int(mid * tr_ratio)
        if max(tracked_width(probe, s, f, tr) for s in texts) <= target_w:
            best, lo = mid, mid + 1
        else:
            hi = mid - 1
    return ImageFont.truetype(path, best), int(best * tr_ratio)


def gradient_text(img, x, y, text, font, tr, c_top, c_bot, glow, glow_r=20):
    mask = Image.new("L", img.size, 0)
    draw_tracked(ImageDraw.Draw(mask), (x, y), text, font, 255, tr)
    box = mask.getbbox()
    if box is None:
        return
    y0, y1 = box[1], box[3]

    halo = Image.new("RGBA", img.size, glow + (0,))
    halo.putalpha(mask.filter(ImageFilter.GaussianBlur(glow_r))
                  .point(lambda v: v * 88 // 100))
    img.alpha_composite(halo)

    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    shadow.paste((0, 0, 0, 200), (0, 0), mask.filter(ImageFilter.GaussianBlur(5)))
    img.alpha_composite(shadow.transform(
        img.size, Image.AFFINE, (1, 0, -6, 0, 1, -7), resample=Image.BILINEAR))

    grad = Image.new("RGBA", img.size)
    gd = ImageDraw.Draw(grad)
    span = max(1, y1 - y0)
    for gy in range(y0, y1 + 1):
        t = (gy - y0) / span
        gd.line([(0, gy), (img.width, gy)],
                fill=tuple(int(c_top[i] + (c_bot[i] - c_top[i]) * t)
                           for i in range(3)) + (255,))
    img.paste(grad, (0, 0), mask)


def title_block(img, cfg):
    lines = cfg["title"]
    f_t, tr_t = fit_size(BLACK_F, lines, 0.05, TITLE_BOX)
    f_s, tr_s = fit_size(BOLD_F, [cfg["sub"]], 0.34, int(TITLE_BOX * 0.70), hi=64)
    f_by = ImageFont.truetype(BOLD_F, 46)

    line_h = int(f_t.size * 1.06)
    block_h = len(lines) * line_h + int(f_s.size * 1.5) + 150
    img = scrim(img, TITLE_CX, BLOCK_CY, int(TITLE_BOX * 0.74),
                block_h // 2 + 46, 168)

    d = ImageDraw.Draw(img)
    y = BLOCK_CY - block_h // 2
    for s in lines:
        x = TITLE_CX - tracked_width(d, s, f_t, tr_t) // 2
        gradient_text(img, x, y - int(f_t.size * 0.24), s, f_t, tr_t,
                      cfg["top"], cfg["bot"], cfg["glow"])
        y += line_h
    d = ImageDraw.Draw(img)

    y += int(f_s.size * 0.30)
    sx = TITLE_CX - tracked_width(d, cfg["sub"], f_s, tr_s) // 2
    draw_tracked(d, (sx + 3, y + 3), cfg["sub"], f_s, (0, 0, 0, 195), tr_s)
    draw_tracked(d, (sx, y), cfg["sub"], f_s, cfg["sub_col"] + (255,), tr_s)
    y += int(f_s.size * 1.62)

    accent, half, dia = cfg["accent"], int(TITLE_BOX * 0.32), 11
    d.line([(TITLE_CX - half, y), (TITLE_CX - dia - 14, y)],
           fill=accent + (170,), width=3)
    d.line([(TITLE_CX + dia + 14, y), (TITLE_CX + half, y)],
           fill=accent + (170,), width=3)
    d.polygon([(TITLE_CX, y - dia), (TITLE_CX + dia, y),
               (TITLE_CX, y + dia), (TITLE_CX - dia, y)], fill=accent + (240,))
    y += 42

    wa = d.textlength("by ", font=f_by)
    wb = d.textlength("Bitochi", font=f_by)
    bx = TITLE_CX - int(wa + wb) // 2
    d.text((bx + 3, y + 3), "by ", font=f_by, fill=(0, 0, 0, 195))
    d.text((bx, y), "by ", font=f_by, fill=(238, 238, 242, 255))
    d.text((bx + wa + 3, y + 3), "Bitochi", font=f_by, fill=(0, 0, 0, 195))
    d.text((bx + wa, y), "Bitochi", font=f_by, fill=accent + (255,))
    return img


# ── Drive ────────────────────────────────────────────────────────────────────
def compose(slug: str) -> str:
    cfg = GAMES[slug]
    img = crop_2x1(os.path.join(ASSETS, cfg["art"]), cfg["bias"])
    img = scrim(img, WATCH_CX + 40, 380, 360, 330, 112)
    img = place_watch(img, cfg["face"](), cfg["accent"])
    img = title_block(img, cfg)

    out = os.path.join(HERE, f"{slug}_hero.png")
    img.convert("RGB").save(out, "PNG")
    subprocess.run([sys.executable,
                    os.path.join(REPO, ".cursor/skills/make-game/scripts/stamp_one.py"),
                    slug], check=True)
    site = os.path.join(REPO, "leaderboard", "heroes", f"{slug}_hero.png")
    if os.path.isdir(os.path.dirname(site)):
        Image.open(out).save(site, "PNG")
    return out


if __name__ == "__main__":
    for s in (sys.argv[1:] or list(GAMES)):
        print("wrote", compose(s))
