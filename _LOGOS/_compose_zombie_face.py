#!/usr/bin/env python3
"""Render a Zombie Survival: Last Stand watch face for the store hero.

A port of the game's own renderer (ZsArt.mc + ZsHud.mc): same geometry
percentages, same 64-colour palette, same sprite skeletons. It exists because
the hero needs a clean 454x454 action frame and the Connect IQ simulator is
shared with other work; keep it in sync with the .mc files if those change.

    python3 _LOGOS/_compose_zombie_face.py out.png
"""
import sys

from PIL import Image, ImageDraw, ImageFont

SCREEN = 454

# ── Palette (ZsConst.mc) ─────────────────────────────────────────────────────
ACCENT, FIRE, FIRE2 = 0x55FF55, 0xFF5500, 0xFFAA00
BLOOD, BLOOD2 = 0xAA0000, 0xFF0000
WOOD, WOOD_D = 0xAA5500, 0x550000
STEEL, STEEL_D = 0xAAAAAA, 0x555555
DANGER, WARN = 0xFF0000, 0xFFAA00
CLOTH, SKIN = 0x005555, 0xFFAA55

Z_WALKER, Z_RUNNER, Z_BRUTE, Z_CRAWLER, Z_SPITTER, Z_SCREAMER, Z_BOSS = range(7)
Z_COLOR = [0x55AA55, 0xAAFF55, 0x55AA00, 0x55AA55, 0xAAFF00, 0xAAFFAA, 0x55AA00]
Z_DARK = [0x005500, 0x55AA00, 0x005500, 0x005500, 0x55AA00, 0x55AA55, 0x005500]
Z_RIM = [0xAAFFAA, 0xFFFFAA, 0xAAFF55, 0xAAFFAA, 0xFFFF55, 0xFFFFFF, 0xAAFF55]
Z_CLOTH = [0x555555, 0x550000, 0x555555, 0x550055, 0x005555, 0x550055, 0x550000]
Z_EYE = [0xFF0000, 0xFFAA00, 0xFF0000, 0xFF5500, 0xFFFF55, 0xFF00AA, 0xFF0000]
Z_HPCT = [100, 92, 140, 52, 104, 106, 168]

SKY_RAMP = [0x000000, 0x550000, 0xAA5500, 0xFFAA00]
LANES = 3


def rgb(c):
    return ((c >> 16) & 0xFF, (c >> 8) & 0xFF, c & 0xFF)


class DC:
    """The subset of Toybox.Graphics.Dc the renderer actually uses."""

    def __init__(self, w, h):
        self.im = Image.new("RGB", (w, h), (0, 0, 0))
        self.d = ImageDraw.Draw(self.im)
        self.w, self.h = w, h
        self.c = (255, 255, 255)
        self.pen = 1

    def col(self, c):
        self.c = rgb(c)

    def rect(self, x, y, w, h):
        w = max(1, int(w))
        h = max(1, int(h))
        x, y = int(x), int(y)
        self.d.rectangle([x, y, x + w - 1, y + h - 1], fill=self.c)

    def circle(self, x, y, r):
        r = max(1, int(r))
        x, y = int(x), int(y)
        self.d.ellipse([x - r, y - r, x + r, y + r], fill=self.c)

    def ellipse(self, x, y, rx, ry):
        rx, ry = max(1, int(rx)), max(1, int(ry))
        x, y = int(x), int(y)
        self.d.ellipse([x - rx, y - ry, x + rx, y + ry], fill=self.c)

    def line(self, x0, y0, x1, y1):
        self.d.line([int(x0), int(y0), int(x1), int(y1)],
                    fill=self.c, width=self.pen)

    def arc(self, cx, cy, r, a0, a1):
        # Monkey C angles: 0 = 3 o'clock, counter-clockwise. Pillow: 0 = 3
        # o'clock, clockwise. Mirror and go the short way round.
        self.d.arc([cx - r, cy - r, cx + r, cy + r], -a0, -a1,
                   fill=self.c, width=self.pen)


def _h(n):
    return ((n * 1103515245 + 12345) & 0x7FFFFFFF) >> 9 & 0xFFFF


def _mix(a, b, t):
    ra, ga, ba = (a >> 16) & 0xFF, (a >> 8) & 0xFF, a & 0xFF
    rb, gb, bb = (b >> 16) & 0xFF, (b >> 8) & 0xFF, b & 0xFF
    return ((ra * (100 - t) + rb * t) // 100 << 16
            | (ga * (100 - t) + gb * t) // 100 << 8
            | (ba * (100 - t) + bb * t) // 100)


# ── Geometry (ZsArt.mc) ──────────────────────────────────────────────────────
def lane_ys(h):
    return [h * 85 // 100, h * 71 // 100, h * 60 // 100]


def lane_scales():
    return [100, 76, 57]


def wall_xs(w):
    return [w * 30 // 100, w * 36 // 100, w * 42 // 100]


def horizon_y(h):
    return h * 48 // 100


def player_x(w):
    return w * 12 // 100


def z_height(h, scale, t):
    return h * 17 // 100 * scale // 100 * Z_HPCT[t] // 100


# ── Background ───────────────────────────────────────────────────────────────
def draw_sky(dc, w, h, t):
    """Night sky as dithered horizontal bands. A 64-colour panel cannot blend,
    so the ramp is faked by interleaving rows of the next colour up — solid
    ellipses of firelight read as hard-edged blobs at this size."""
    hz = horizon_y(h)
    dc.col(SKY_RAMP[0])
    dc.rect(0, 0, w, hz + 1)
    for i in range(16):
        sx = _h(i * 37 + 11) % w
        sy = _h(i * 53 + 7) % (hz * 58 // 100)
        tw = ((t // 7) + i) % 9
        dc.col(0xFFFFFF if tw == 0 else (0xAAAAAA if tw < 4 else 0x555555))
        dc.rect(sx, sy, 1, 1)

    # Two solid steps of ember instead of a dithered ramp: full-width dither
    # rows read as venetian blinds once the sky is more than a few pixels tall.
    dc.col(0x550000); dc.rect(0, hz - h * 12 // 100, w, h * 12 // 100)
    dc.col(0xAA5500); dc.rect(0, hz - h * 3 // 100, w, h * 3 // 100)

    # Pools of firelight, low enough that the skyline eats most of them and
    # only the flicker between the towers shows.
    pulse = (t // 9) % 3
    glow(dc, w * 26 // 100, hz, w * 30 // 100, h * (3 + pulse) // 100)
    glow(dc, w * 82 // 100, hz, w * 18 // 100, h * (3 - pulse // 2) // 100)
    draw_moon(dc, w, h, t)
    draw_skyline(dc, w, h)


def band(dc, w, y0, y1, col, d0, d1=100):
    """Fill rows y0..y1 with col, row coverage ramping from d0 to d1 percent.
    Error diffusion down the column spreads the dropped rows evenly, which is
    the only gradient a 64-colour panel can show."""
    y0, y1 = int(y0), int(y1)
    span = max(1, y1 - y0)
    dc.col(col)
    acc = 0
    for y in range(y0, y1):
        acc += d0 + (d1 - d0) * (y - y0) // span
        if acc >= 100:
            acc -= 100
            dc.rect(0, y, w, 1)


def glow(dc, cx, cy, rx, ry):
    dc.col(0xAA5500); dc.ellipse(cx, cy, rx, ry)
    dc.col(0xFFAA00); dc.ellipse(cx, cy, rx * 46 // 100, ry * 58 // 100)


def draw_moon(dc, w, h, t):
    mx, my, r = w * 76 // 100, h * 15 // 100, h * 55 // 1000
    dc.col(0x555555); dc.circle(mx, my, r * 118 // 100)
    dc.col(0xAAAAAA); dc.circle(mx, my, r)
    dc.col(0xFFFFFF); dc.circle(mx - r // 5, my - r // 5, r * 62 // 100)
    dc.col(0xAAAAAA)
    dc.circle(mx - r // 3, my - r // 4, r // 6)
    dc.circle(mx - r // 12, my + r // 5, r // 9 + 1)
    cx = ((t // 6) % (w + 260)) - 130
    dc.col(0x000000)
    dc.rect(cx, my - r // 3, r * 5 // 2, r * 2 // 5 + 1)
    dc.rect(cx + r, my + r // 3, r * 2, r // 3 + 1)


def draw_skyline(dc, w, h):
    hz = horizon_y(h)
    dc.col(0x000000)
    x, i = -6, 0
    while x < w:
        bw = 13 + (_h(i * 3 + 1) % 22)
        bh = h * 2 // 100 + (_h(i * 7 + 5) % (h * 5 // 100))
        dc.rect(x, hz - bh, bw, bh + 2)
        x += bw + 4
        i += 1
    x, i = -12, 0
    while x < w:
        bw2 = 17 + (_h(i * 11 + 3) % 28)
        bh2 = h * 5 // 100 + (_h(i * 13 + 9) % (h * 12 // 100))
        by = hz - bh2
        dc.col(0x000000); dc.rect(x, by, bw2, bh2 + 2)
        # Ember rim so the near towers separate from the black sky above the
        # glow instead of merging into one dark mass.
        dc.col(0x550000)
        dc.rect(x, by, bw2, 1)
        dc.rect(x, by, 1, bh2)
        if bw2 > 22 and bh2 > 16:
            for k in range(3):
                if (_h(i * 29 + k * 7) % 100) < 58:
                    continue
                wx = x + 4 + k * (bw2 - 8) // 3
                wy = by + 5 + (_h(i * 19 + k * 3) % (bh2 - 10))
                dc.col(0xFFAA00 if (_h(i * 23 + k) % 100) < 26 else 0xAA5500)
                dc.rect(wx, wy, 2, 2)
        x += bw2 + 6
        i += 1


def draw_ground(dc, w, h, ys, t):
    hz = horizon_y(h)
    span = h - hz
    # Wet asphalt: black, with the firelight only skimming the first few
    # metres past the horizon. Anything more and the street competes with the
    # zombies for the eye.
    dc.col(0x000000); dc.rect(0, hz, w, span)
    dc.col(0xAA5500); dc.rect(0, hz, w, 1)
    band(dc, w, hz + 1, hz + (ys[2] - hz) * 45 // 100, 0x550000, 100, 0)
    for p in range(5):
        px = _h(p * 71 + 3) % w
        py = hz + h * 8 // 100 + (_h(p * 97 + 13) % (h * 38 // 100))
        pw = 6 + (_h(p * 41) % 18)
        dc.col(0x000055); dc.rect(px, py, pw, 2)
        dc.col(0x555555); dc.rect(px + pw // 3, py, pw // 3, 1)
    for l in range(LANES - 1, -1, -1):
        ly = ys[l]
        dc.col(0xAAAA55 if l == 0 else 0x555500)
        dw, gap = 16 - l * 5, 26 - l * 6
        off = (t // 5) % (dw + gap)
        dx = w * 42 // 100 - off
        dh = 3 - l
        dy = ly - (h * 6 // 100 if l == 0 else h * 4 // 100)
        while dx < w:
            dc.rect(dx, dy, dw, dh)
            dx += dw + gap
        dc.col(0xAAAAAA if l == 0 else 0x555555)
        dc.rect(0, ly, w, 2 if l == 0 else 1)
        dc.col(0x000000)
        dc.rect(0, ly + (2 if l == 0 else 1), w, 1)
    draw_debris(dc, w, h, ys)


def draw_debris(dc, w, h, ys):
    for l in range(LANES):
        y, s = ys[l], 4 - l
        for i in range(3):
            x = w * 50 // 100 + (_h(i * 31 + l * 7) % (w // 2))
            dc.col(0x555555 if (i & 1) == 0 else 0x550000)
            dc.rect(x, y - 2 - (i % 2), 4 + s, 2)
    cy, cx = ys[2], w * 86 // 100
    cw, ch = w * 14 // 100, h * 5 // 100
    dc.col(0x000000)
    dc.rect(cx - cw // 2, cy - ch, cw, ch)
    dc.rect(cx - cw // 3, cy - ch - ch // 2, cw * 2 // 3, ch // 2)
    dc.col(0x555555)
    dc.rect(cx - cw // 2, cy - ch, cw, 1)
    dc.rect(cx - cw // 3, cy - ch - ch // 2, cw * 2 // 3, 1)
    dc.col(0x550000)
    dc.rect(cx - cw // 4, cy - ch - ch // 2, cw // 6, ch // 2)


def draw_weather(dc, w, h, t):
    dc.col(0x5555AA)
    for i in range(11):
        sx = _h(i * 41) % w
        sy = ((_h(i * 53) % h) + t * (5 + i % 4)) % h
        dc.line(sx, sy, sx - 3, sy + 9)
    dc.col(FIRE)
    for e in range(5):
        ex = _h(e * 61) % w
        ey = h - ((_h(e * 71) % h) + t * 2) % h
        dc.rect(ex, ey, 2, 2)


# ── Barricade ────────────────────────────────────────────────────────────────
def draw_barricade(dc, w, h, lane, x, y, scale, pct, t):
    hgt = max(9, h * 11 // 100 * scale // 100)
    wide = max(12, h * 15 // 100 * scale // 100)
    u = max(1, hgt // 9)
    x0, top = x - wide // 2, y - hgt
    dmg = 100 - pct

    pn = 7
    pw = wide // pn
    if pw < 2:
        pw, pn = 2, wide // 2
    for i in range(pn):
        mid = pn // 2
        d = (mid - i) if i < mid else (i - mid)
        if dmg > 100 - d * 26:
            continue
        px = x0 + i * pw
        py = top + _h(i * 13 + lane * 31) % (u * 2 + 1)
        ph = y - py
        dc.col(WOOD if (i & 1) == 0 else 0x550000)
        dc.rect(px, py, pw - 1, ph)
        dc.col(0xFFAA55); dc.rect(px, py, pw - 1, 1)
        if u >= 2:
            dc.col(0x000000); dc.rect(px + pw - 2, py + 1, 1, ph - 1)

    dc.col(0x550000)
    dc.rect(x0, top + hgt * 34 // 100, wide, u)
    dc.rect(x0, top + hgt * 68 // 100, wide, u)
    dc.col(WOOD)
    dc.rect(x0, top + hgt * 34 // 100, wide, 1)
    dc.rect(x0, top + hgt * 68 // 100, wide, 1)

    if dmg < 74:
        sx, sw = x0 + wide * 62 // 100, wide * 34 // 100
        dc.col(STEEL_D); dc.rect(sx, top + u, sw, hgt - u * 2)
        dc.col(STEEL)
        rx = sx
        while rx < sx + sw:
            dc.rect(rx, top + u, 1, hgt - u * 2)
            rx += (u + 1) if u > 1 else 2
        dc.col(0x000000); dc.rect(sx, top + u, sw, 1)

    bag = max(4, wide // 3)
    b = 0
    while b * bag < wide + bag:
        bx = x0 - u + b * bag
        dc.col(0x550000); dc.ellipse(bx + bag // 2, y - u, bag * 55 // 100, u)
        dc.col(WOOD)
        dc.ellipse(bx + bag // 2, y - u - u // 3, bag * 42 // 100, u * 50 // 100)
        b += 1

    if u >= 3:
        dc.col(0xAAAAAA)
        wy = top - u // 2
        for k in range(4):
            kx = x0 + k * wide // 4
            dc.line(kx, wy + u // 2, kx + wide // 8, wy - u // 2)
            dc.line(kx + wide // 8, wy - u // 2, kx + wide // 4, wy + u // 2)

    if dmg > 40:
        dc.col(BLOOD)
        dc.rect(x0 + wide // 5, top + hgt // 2, u * 2, u)
        dc.rect(x0 + wide * 3 // 5, top + hgt // 3, u, u * 2)
    if dmg > 70:
        dc.col(BLOOD2)
        dc.rect(x0 + wide // 3, top + hgt * 55 // 100, u, u * 3)


# ── Zombies ──────────────────────────────────────────────────────────────────
def draw_zombie(dc, tp, x, gy, hgt, anim, flash=0, burning=0):
    hgt = max(8, int(hgt))
    u = max(1, hgt // 9)
    body, dark = Z_COLOR[tp], Z_DARK[tp]
    cloth, rim = Z_CLOTH[tp], Z_RIM[tp]
    if flash:
        body = cloth = rim = 0xFFFFFF
        dark = 0xFFAAAA
    elif burning:
        # Only the edges catch: tinting the whole body turns the sprite into an
        # orange blob and it stops reading as a zombie.
        dark, rim = _mix(dark, 0xAA0000, 45), 0xFFAA00

    ph = (anim // 3) % 4
    stride = 0 if ph == 0 else (1 if ph == 1 else (0 if ph == 2 else -1))
    bob = -u // 3 if ph in (1, 3) else 0

    dc.col(0x000000)
    dc.ellipse(x, gy + 1, hgt * 26 // 100, u * 2 // 3 + 1)

    if tp == Z_CRAWLER:
        crawler(dc, x, gy, u, body, dark, cloth, ph, tp)
    elif tp == Z_BOSS:
        boss(dc, x, gy, max(1, hgt // 15), body, dark, cloth, ph, anim, rim)
    else:
        humanoid(dc, tp, x, gy + bob, u, body, dark, cloth, stride, rim)
    if burning:
        flames(dc, x, gy, hgt, anim)


def humanoid(dc, tp, x, gy, u, body, dark, cloth, stride, rim):
    lean, shoulder, headR, armLen = 0, u * 3, u, u * 3
    if tp == Z_RUNNER:
        lean, shoulder = u, u * 5 // 2
    if tp == Z_BRUTE:
        shoulder, headR, armLen = u * 7 // 2, u * 5 // 4, u * 4
    if tp == Z_SPITTER:
        shoulder = u * 7 // 2
    if tp == Z_SCREAMER:
        shoulder = u * 5 // 2

    hipY = gy - u * 3
    chestY = hipY - u * 3
    headY = chestY - u * 2

    dc.col(dark)
    dc.rect(x - u + stride * u // 2, hipY, u, u * 3)
    dc.rect(x + stride * u // 2 - u // 2, hipY, u,
            u * 3 - (u // 2 if stride > 0 else 0))
    dc.col(cloth)
    dc.rect(x - u - lean // 2, hipY - u // 2, u * 2 + u // 2, u * 3 // 2)

    # Flesh first, rags over the belly — a mostly-cloth torso reads as a grey
    # box once the sprite is under twenty pixels tall.
    dc.col(body); dc.rect(x - shoulder // 2 - lean, chestY, shoulder, u * 3)
    dc.col(cloth)
    dc.rect(x - shoulder // 2 - lean, chestY + u * 2, shoulder, u)
    if tp == Z_SPITTER:
        dc.col(0xAAFF00)
        dc.ellipse(x - lean, chestY + u * 2, shoulder // 2, u * 3 // 2)
    if tp == Z_BRUTE:
        dc.col(0xFFFFAA)
        dc.rect(x - shoulder // 4 - lean, chestY + u, shoulder // 2, u // 2)
        dc.rect(x - shoulder // 4 - lean, chestY + u * 2, shoulder // 2, u // 2)

    armY = chestY + u - stride * u // 3
    dc.col(body)
    dc.rect(x - shoulder // 2 - armLen - lean, armY, armLen, u)
    dc.rect(x - shoulder // 2 - armLen * 3 // 4 - lean, armY + u + u // 2,
            armLen * 3 // 4, u)
    dc.col(dark)
    dc.rect(x - shoulder // 2 - armLen - lean - u // 2, armY, u // 2 + 1, u)

    hx = x - lean - u // 2
    dc.col(body); dc.circle(hx, headY, headR + u // 4)
    dc.col(dark); dc.rect(hx - headR, headY + headR // 2, headR * 2, u // 2 + 1)
    if tp == Z_SCREAMER:
        dc.col(0x000000)
        dc.ellipse(hx - headR // 2, headY + headR, headR * 3 // 4, headR)
    dc.col(Z_EYE[tp])
    dc.rect(hx - headR + (1 if u > 3 else 0), headY - u // 4, u // 2 + 1, u // 2 + 1)
    if u >= 4:
        dc.rect(hx - headR // 4, headY - u // 4, u // 3 + 1, u // 3 + 1)
    if u >= 3:
        dc.col(dark)
        dc.rect(hx - headR, headY - headR - u // 3, headR * 2, u // 2)

    dc.col(rim)
    dc.rect(x + shoulder // 2 - lean - 1, chestY, 1, u * 3)
    dc.rect(hx + headR - 1, headY - headR // 2, 1, headR + u // 2)
    dc.rect(x + stride * u // 2 + u // 2 - 1, hipY, 1, u * 3)


def crawler(dc, x, gy, u, body, dark, cloth, ph, tp):
    y = gy - u * 2
    drag = u // 2 if ph in (1, 2) else 0
    dc.col(cloth); dc.rect(x - u, y, u * 3, u * 3 // 2)
    dc.col(body)
    dc.rect(x - u * 2, y - u // 2, u * 2, u * 3 // 2)
    dc.circle(x - u * 5 // 2 - drag, y, u)
    dc.col(dark)
    dc.rect(x + u * 2, y + u // 2, u * 2, u // 2 + 1)
    dc.rect(x + u * 2, y + u, u * 5 // 2, u // 2)
    dc.rect(x - u * 4 - drag, y + u // 2, u * 2, u // 2 + 1)
    dc.col(Z_EYE[tp]); dc.rect(x - u * 3 - drag, y - u // 3, u // 2 + 1, u // 2 + 1)


def boss(dc, x, gy, u, body, dark, cloth, ph, anim, rim):
    stride = 0 if ph in (0, 2) else (1 if ph == 1 else -1)
    hipY = gy - u * 5
    chestY = hipY - u * 6
    headY = chestY - u * 2
    hipW, shoulder = u * 5, u * 8

    dc.col(dark)
    dc.rect(x - hipW // 2 - u + stride * u // 2, hipY, u * 2, u * 5)
    dc.rect(x + hipW // 2 - u - stride * u // 2, hipY, u * 2, u * 5)
    dc.col(cloth)
    dc.rect(x - hipW // 2 - u, gy - u, u * 2, u)
    dc.rect(x + hipW // 2 - u, gy - u, u * 2, u)

    dc.col(body)
    dc.rect(x - hipW // 2, hipY - u, hipW, u * 2)
    dc.rect(x - shoulder // 2, chestY, shoulder, u * 5)
    dc.col(dark)
    dc.rect(x - shoulder // 2, chestY + u * 4, shoulder, u)
    dc.col(0xFFFFAA)
    for i in range(3):
        dc.rect(x - shoulder // 4, chestY + u + i * u * 3 // 2,
                shoulder // 2, u // 2 + 1)
    dc.col(STEEL_D)
    dc.rect(x - shoulder // 2 - u // 2, chestY - u // 2, u * 3, u * 2)
    dc.rect(x + shoulder // 2 - u * 5 // 2, chestY - u // 2, u * 3, u * 2)
    dc.col(STEEL)
    dc.rect(x - shoulder // 2 - u // 2, chestY - u // 2, u * 3, 1)
    dc.rect(x + shoulder // 2 - u * 5 // 2, chestY - u // 2, u * 3, 1)

    pulse = ((anim // 4) % 2) == 0
    dc.col(FIRE if pulse else 0x550000)
    dc.circle(x, chestY + u * 5 // 2, u * 3 // 2)
    dc.col(0xFFFF55 if pulse else FIRE)
    dc.circle(x, chestY + u * 5 // 2, u * 3 // 4)

    dc.col(body)
    dc.rect(x - shoulder // 2 - u * 3, chestY + u, u * 3, u * 2)
    dc.rect(x - shoulder // 2 - u * 4, chestY + u * 2, u * 2, u * 5)
    dc.col(dark)
    dc.rect(x - shoulder // 2 - u * 5, chestY + u * 6, u * 3, u * 2)
    dc.rect(x + shoulder // 2 - u, chestY + u, u * 2, u * 3)

    # Head sunk between the shoulders, but still clear of them — the
    # Abomination is hunched, not decapitated.
    dc.col(body); dc.rect(x - u * 2, headY + u, u * 4, u * 2)
    dc.col(dark); dc.circle(x - u // 2, headY, u * 2)
    dc.col(0x000000)
    dc.rect(x - u * 2, headY + u, u * 3, u)
    dc.col(Z_EYE[Z_BOSS])
    dc.rect(x - u * 2, headY - u // 2, u, u)
    dc.rect(x, headY - u // 2, u, u)

    dc.col(rim)
    dc.rect(x + shoulder // 2 - 1, chestY, 1, u * 5)
    dc.rect(x + hipW // 2 - 1, hipY, 1, u * 5)


def flames(dc, x, gy, hgt, anim):
    """Tongues licking off the shoulders and hips, tied to the sprite so they
    do not float above its head."""
    f = (anim // 2) % 3
    top = gy - hgt * 82 // 100
    dc.col(FIRE)
    dc.rect(x - hgt // 5, top, hgt // 9, hgt // 6 + f)
    dc.rect(x + hgt // 7, top + hgt // 8, hgt // 11, hgt // 7 + f)
    dc.rect(x - hgt // 12, gy - hgt // 3, hgt // 12, hgt // 8 + f)
    dc.col(FIRE2)
    dc.rect(x - hgt // 6, top - hgt // 12 - f, hgt // 14 + 1, hgt // 9)
    dc.rect(x + hgt // 6, top + hgt // 14, hgt // 16 + 1, hgt // 10)


# ── Survivor ─────────────────────────────────────────────────────────────────
def draw_survivor(dc, x, gy, hgt, lane, recoil, reloading, adren, breathe):
    u = max(1, hgt // 10)
    bx = x + (u // 2 if recoil else 0)
    gyy = gy + (0 if ((breathe // 8) % 2) == 0 else -1)
    dc.col(0x000000); dc.ellipse(x, gy + 1, u * 4, u)

    hipY = gyy - u * 4
    chestY = hipY - u * 3
    headY = chestY - u * 2

    dc.col(0x555555)
    dc.rect(bx - u * 2, hipY, u * 3 // 2, u * 4)
    dc.rect(bx + u // 2, hipY, u * 3 // 2, u * 4)
    dc.col(0x000000)
    dc.rect(bx - u * 5 // 2, gyy - u, u * 2, u)
    dc.rect(bx + u // 2, gyy - u, u * 2, u)

    dc.col(0xAA0000 if adren else CLOTH)
    dc.rect(bx - u * 2, chestY, u * 4, u * 4)
    dc.col(0xFF0055 if adren else 0x55AAAA)
    dc.rect(bx - u * 2, chestY, u * 4, u)
    dc.col(0xAA5500); dc.rect(bx - u * 7 // 2, chestY + u // 2, u * 3 // 2, u * 5 // 2)

    dc.col(SKIN); dc.circle(bx, headY + u, u * 5 // 4)
    dc.col(0x005500)
    dc.rect(bx - u * 3 // 2, headY, u * 3, u)
    dc.rect(bx + u // 2, headY + u // 2, u * 2, u // 2 + 1)

    aim = 0 if lane == 0 else (-u if lane == 1 else -u * 2)
    bl = u * 5
    by = chestY + u
    mx, my = bx + u + bl, by + aim
    dc.col(0x555555)
    dc.pen = 3 if u >= 3 else 2
    dc.line(bx + u, by, mx, my)
    dc.pen = 1
    dc.col(0x000000); dc.rect(bx - u // 2, by - u // 2, u * 2, u)
    dc.col(0xFF0055 if adren else 0x55AAAA)
    dc.rect(bx + u // 2, by - u // 4, u * 2, u * 3 // 4 + 1)
    if reloading:
        dc.col(WARN); dc.rect(bx + u // 2, by + u * 2, u, u * 3 // 2)
    return [mx, my]


def draw_muzzle_flash(dc, mx, my, s):
    dc.col(FIRE2); dc.circle(mx, my, s)
    dc.col(0xFFFFFF); dc.circle(mx, my, s // 2)
    dc.col(FIRE)
    dc.rect(mx, my - s // 3, s * 2, s * 2 // 3 + 1)
    dc.rect(mx + s // 2, my - s * 3 // 2, s // 2 + 1, s * 3)


def draw_tracer(dc, x0, y0, x1, y1, hot=True):
    dc.col(0xFFFFFF if hot else FIRE2)
    dc.pen = 2 if hot else 1
    dc.line(x0, y0, x1, y1)
    dc.pen = 1


# ── HUD (ZsHud.mc) ───────────────────────────────────────────────────────────
def font(size, bold=True):
    p = ("/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold
         else "/System/Library/Fonts/Supplemental/Arial.ttf")
    try:
        return ImageFont.truetype(p, size)
    except OSError:
        return ImageFont.load_default()


def text(dc, x, y, f, s, col, anchor="ma"):
    dc.d.text((x + 1, y + 1), s, font=f, fill=(0, 0, 0), anchor=anchor)
    dc.d.text((x, y), s, font=f, fill=rgb(col), anchor=anchor)


def draw_hud(dc, w, h, wave, kills, total, mod_name, wall_pct, done_pct):
    cx, cy, r = w // 2, h // 2, min(w, h) // 2

    dc.pen = 5
    dc.col(0x555555); dc.arc(cx, cy, r - 3, 140, 40)
    dc.col(ACCENT); dc.arc(cx, cy, r - 3, 140, max(40, 140 - done_pct))
    dc.col(0x555555); dc.arc(cx, cy, r - 3, 320, 220)
    wcol = STEEL if wall_pct >= 55 else (WARN if wall_pct >= 28 else DANGER)
    dc.col(wcol)
    dc.arc(cx, cy, r - 3, 320, 220 + (320 - 220) * (100 - wall_pct) // 100)
    dc.pen = 1

    text(dc, cx, h * 4 // 100, font(30), "NIGHT %d" % wave, ACCENT)
    text(dc, cx, h * 13 // 100, font(20), mod_name, FIRE)
    text(dc, w * 15 // 100, h * 21 // 100, font(23),
         "%d/%d" % (kills, total), 0xFFFFFF, "la")


# ── Emplacements ─────────────────────────────────────────────────────────────
# Ports of ZsArt._mgNest / _tesla / _mortar. Drawn per lane before that lane's
# barricade so the wall occludes them the same way it does on device.
def draw_turret(dc, w, h, lane, t, firing):
    ys, sc, xs = lane_ys(h), lane_scales(), wall_xs(w)
    u = max(3, h * 45 // 1000 * sc[lane] // 100)
    x, y = xs[lane] - u * 7 // 2, ys[lane]

    if lane == 0:
        dc.col(0x555500); dc.rect(x - u, y - u, u * 2, u)
        dc.col(0x005500); dc.rect(x - u, y - u, u * 2, u // 3 + 1)
        dc.col(STEEL_D); dc.rect(x - u // 3, y - u * 2, u * 2 // 3, u)
        dc.col(STEEL); dc.rect(x, y - u * 2 + 1, u * 2, u // 3 + 1)
        if firing:
            dc.col(FIRE2); dc.rect(x + u * 2, y - u * 2, u, u // 2 + 1)
    elif lane == 1:
        dc.col(STEEL_D); dc.rect(x - u // 2, y - u * 2, u, u * 2)
        dc.col(0x55AAFF); dc.circle(x, y - u * 2 - u // 2, u // 2 + 1)
        dc.col(0xAAFFFF)
        dc.rect(x - u, y - u * 2 - u // 2, u * 2, 1)
        dc.rect(x, y - u * 3, 1, u)
    else:
        dc.col(0x555555); dc.rect(x - u, y - u // 2, u * 2, u // 2 + 1)
        dc.col(STEEL_D)
        dc.d.polygon([(x - u // 2, y - u // 2), (x + u // 3, y - u * 2),
                      (x + u, y - u * 2 + u // 2), (x, y - u // 2)],
                     fill=rgb(STEEL_D))
        dc.col(FIRE); dc.rect(x + u // 3, y - u * 2, u // 2 + 1, u // 3 + 1)


# ── Frame ────────────────────────────────────────────────────────────────────
def render(t=41):
    w = h = SCREEN
    dc = DC(w, h)
    ys, scales, wx = lane_ys(h), lane_scales(), wall_xs(w)

    draw_sky(dc, w, h, t)
    draw_ground(dc, w, h, ys, t)

    # A staged wave, back to front. Kept sparse and spread out: on a 454px
    # disc, four sprites to a lane collapse into one green smear.
    horde = [
        (2, [(Z_WALKER, 0.72)]),
        (1, [(Z_BOSS, 0.58), (Z_SPITTER, 0.96)]),
        (0, [(Z_RUNNER, 0.86)]),
    ]
    hero_px = w * 14 // 100
    muzzle = None
    for lane, mobs in horde:
        gy, sc = ys[lane], scales[lane]
        if lane == 0:
            muzzle = draw_survivor(dc, hero_px, ys[0], h * 18 // 100,
                                   0, True, False, True, t)
        for tp, fx in sorted(mobs, key=lambda m: m[1]):
            x = int(wx[lane] + (w * 1.02 - wx[lane]) * fx)
            draw_zombie(dc, tp, x, gy, z_height(h, sc, tp), t + int(fx * 17),
                        burning=1 if tp == Z_BRUTE else 0)
        draw_turret(dc, w, h, lane, t, firing=(lane == 0))
        draw_barricade(dc, w, h, lane, wx[lane], gy, sc,
                       [42, 76, 93][lane], t)

    if muzzle:
        draw_tracer(dc, muzzle[0], muzzle[1], w * 56 // 100,
                    ys[0] - h * 11 // 100)
        draw_muzzle_flash(dc, muzzle[0], muzzle[1], h * 5 // 200)

    # Blood thrown by the round that just landed on the brute.
    for i in range(9):
        px = w * 56 // 100 + (_h(i * 17 + 5) % (w * 11 // 100))
        py = ys[0] - h * 15 // 100 + (_h(i * 23 + 9) % (h * 9 // 100))
        dc.col(BLOOD2 if (i & 1) else BLOOD)
        dc.rect(px, py, 3, 3)

    draw_weather(dc, w, h, t)
    draw_hud(dc, w, h, wave=13, kills=19, total=34, mod_name="HORDE NIGHT",
             wall_pct=46, done_pct=56)

    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, w - 1, h - 1], fill=255)
    out = Image.new("RGB", (w, h), (0, 0, 0))
    out.paste(dc.im, (0, 0), mask)
    return out


if __name__ == "__main__":
    path = sys.argv[1] if len(sys.argv) > 1 else "/tmp/zombie_face.png"
    tick = int(sys.argv[2]) if len(sys.argv) > 2 else 41
    render(tick).save(path)
    print("wrote", path)
