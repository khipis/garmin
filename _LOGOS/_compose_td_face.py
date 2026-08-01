#!/usr/bin/env python3
"""Render a Tower Defense: Siege Commander watch face off-device.

A port of the game's own renderer (TdArt.mc plus the layout and HUD in
BitochiTowerDefenseView.mc): same percentages, same palette, same draw order.
It exists so the art can be iterated on without the Connect IQ simulator in
the loop, and so the store hero can use a genuine frame. Keep it in sync with
the .mc files when those change.

    python3 _LOGOS/_compose_td_face.py out.png [tick] [map]
"""
import math
import sys

from PIL import Image, ImageDraw, ImageFont

SCREEN = 454

# ── Palette (TdConst.mc) ─────────────────────────────────────────────────────
C_GRASS, C_GRASS2, C_GRASS3 = 0x1E4028, 0x265030, 0x17321F
C_DIRT, C_DIRT_D = 0x6A5436, 0x3E301E
C_TEXT, C_MUTED = 0xE8EEF4, 0x7C93A8
C_GOLD, C_HP, C_DANGER = 0xFFD24A, 0x4CD07A, 0xFF4444

TW_GUN, TW_CANNON, TW_ARCHER, TW_FROST, TW_TESLA, TW_FLAME, TW_SNIPER = range(7)
TW_COLOR = [0x74A8E8, 0xE8843C, 0x8CD867, 0x66DCEE, 0xC98CFF, 0xFF6A3A, 0xE8D26A]

EN_GRUNT, EN_RUNNER, EN_TANK, EN_FLYER, EN_SHIELD, EN_HEALER, EN_BOSS = range(7)
EN_COLOR = [0xD9553F, 0xF2B33D, 0x9A6A46, 0xA9CCF5, 0xB0B8C4, 0x6FE3A6, 0xFF3D77]

MAX_DECO, MAX_PROP, MAX_STONE = 44, 12, 96
BARREL = 0x23282E


def rgb(c):
    return ((c >> 16) & 0xFF, (c >> 8) & 0xFF, c & 0xFF)


def shade(c, pct):
    p = max(0, pct)
    r = min(255, ((c >> 16) & 0xFF) * p // 100)
    g = min(255, ((c >> 8) & 0xFF) * p // 100)
    b = min(255, (c & 0xFF) * p // 100)
    return (r << 16) | (g << 8) | b


def mix(c0, c1, t):
    k = max(0, min(100, t))
    r = (((c0 >> 16) & 0xFF) * (100 - k) + ((c1 >> 16) & 0xFF) * k) // 100
    g = (((c0 >> 8) & 0xFF) * (100 - k) + ((c1 >> 8) & 0xFF) * k) // 100
    b = ((c0 & 0xFF) * (100 - k) + (c1 & 0xFF) * k) // 100
    return (r << 16) | (g << 8) | b


def hash3(a, b, c):
    return abs((a * 37409 + b * 12379 + c * 6151 + 911) % 1000003)


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

    def clear(self, c):
        self.d.rectangle([0, 0, self.w, self.h], fill=rgb(c))

    def rect(self, x, y, w, h):
        w, h = max(1, int(w)), max(1, int(h))
        x, y = int(x), int(y)
        self.d.rectangle([x, y, x + w - 1, y + h - 1], fill=self.c)

    def frect(self, x, y, w, h, r):
        self.d.rounded_rectangle([int(x), int(y), int(x + w), int(y + h)],
                                 radius=r, fill=self.c)

    def drect(self, x, y, w, h, r):
        self.d.rounded_rectangle([int(x), int(y), int(x + w), int(y + h)],
                                 radius=r, outline=self.c, width=self.pen)

    def fcircle(self, x, y, r):
        r = max(1, int(r))
        x, y = int(x), int(y)
        self.d.ellipse([x - r, y - r, x + r, y + r], fill=self.c)

    def dcircle(self, x, y, r):
        r = max(1, int(r))
        x, y = int(x), int(y)
        self.d.ellipse([x - r, y - r, x + r, y + r], outline=self.c,
                       width=self.pen)

    def line(self, x0, y0, x1, y1):
        self.d.line([int(x0), int(y0), int(x1), int(y1)], fill=self.c,
                    width=self.pen)
        if self.pen > 2:                       # Dc joins round, Pillow does not
            r = self.pen // 2
            for px, py in ((x0, y0), (x1, y1)):
                self.d.ellipse([int(px) - r, int(py) - r,
                                int(px) + r, int(py) + r], fill=self.c)

    def poly(self, pts):
        self.d.polygon([(int(a), int(b)) for a, b in pts], fill=self.c)

    def arc(self, cx, cy, r, a0, a1):
        # Monkey C: 0 = 3 o'clock, counter-clockwise. Pillow: clockwise.
        self.d.arc([cx - r, cy - r, cx + r, cy + r], -a1, -a0,
                   fill=self.c, width=self.pen)


# ── TdArt ────────────────────────────────────────────────────────────────────
class Art:
    def __init__(self):
        self.ph = 0
        self.uu = 4
        self.ax, self.ay = 1.0, 0.0

    def frame(self, phase, u):
        self.ph, self.uu = phase, u

    def aim(self, dx, dy):
        self.ax, self.ay = dx, dy

    def quad(self, dc, x, y, dx, dy, l0, l1, hw, col):
        ax, ay = x + dx * l0, y + dy * l0
        bx, by = x + dx * l1, y + dy * l1
        ppx, ppy = -dy * hw, dx * hw
        dc.col(col)
        dc.poly([(ax + ppx, ay + ppy), (bx + ppx, by + ppy),
                 (bx - ppx, by - ppy), (ax - ppx, ay - ppy)])

    def abar(self, dc, x, y, l0, l1, hw, col):
        self.quad(dc, x, y, self.ax, self.ay, l0, l1, hw, col)

    def tri(self, dc, x, y, dx, dy, back, ln, hw, col):
        bx, by = x + dx * back, y + dy * back
        ppx, ppy = -dy * hw, dx * hw
        dc.col(col)
        dc.poly([(x + dx * ln, y + dy * ln),
                 (bx + ppx, by + ppy), (bx - ppx, by - ppy)])

    def diamond(self, dc, x, y, rx, ry, col):
        dc.col(col)
        dc.poly([(x, y - ry), (x + rx, y), (x, y + ry), (x - rx, y)])

    def shadow(self, dc, x, y, r, col):
        r = max(1, r)
        dc.col(col)
        dc.fcircle(x - r // 2, y, r)
        dc.fcircle(x + r // 2, y, r)

    def ring_x(self, slot, d):
        a = slot % 8
        return [d, d * 7 // 10, 0, -d * 7 // 10, -d, -d * 7 // 10, 0,
                d * 7 // 10][a]

    def ring_y(self, slot, d):
        a = slot % 8
        return [0, -d * 7 // 10, -d, -d * 7 // 10, 0, d * 7 // 10, d,
                d * 7 // 10][a]

    # ── Terrain ──────────────────────────────────────────────────────────────
    def ground(self, dc, cx, cy, rad):
        dc.clear(C_GRASS)
        dc.col(C_GRASS2)
        dc.fcircle(cx - rad // 5, cy - rad // 4, rad * 66 // 100)
        dc.fcircle(cx + rad // 4, cy + rad // 7, rad * 58 // 100)
        dc.fcircle(cx - rad // 7, cy + rad // 3, rad * 44 // 100)
        dc.col(mix(C_GRASS2, 0x3A6A42, 55))
        dc.fcircle(cx + rad // 8, cy - rad // 8, rad * 36 // 100)
        dc.fcircle(cx - rad // 3, cy + rad // 10, rad * 24 // 100)
        pw = rad // 9 + 2
        dc.pen = pw
        for k in range(5):
            dc.col(shade(C_GRASS, 76 - k * 15))
            dc.dcircle(cx, cy, rad * 88 // 100 + k * pw * 9 // 10)
        dc.pen = 1

    def deco(self, dc, items):
        for x, y, s, c in items:
            dc.col(c)
            dc.rect(x, y, s, s)

    def tree(self, dc, x, y, s):
        s = max(3, s)
        self.shadow(dc, x + s // 3, y + s // 2, s * 4 // 5, shade(C_GRASS, 40))
        dc.col(0x3A2A18)
        dc.rect(x - s // 6, y - s // 3, s // 3 + 1, s * 2 // 3)
        dc.col(0x0A1A0E)
        dc.fcircle(x, y - s // 2, s + 1)
        dc.col(0x18461F)
        dc.fcircle(x, y - s // 2, s)
        dc.col(0x2C7233)
        dc.fcircle(x - s // 4, y - s * 3 // 4, s * 70 // 100)
        dc.col(0x5CAE52)
        dc.fcircle(x - s // 3, y - s, s * 36 // 100)

    def rock(self, dc, x, y, s):
        s = max(2, s)
        self.shadow(dc, x + s // 3, y + s // 3, s * 2 // 3, shade(C_GRASS, 46))
        dc.col(0x474C46)
        dc.fcircle(x, y, s)
        dc.col(0x6A7068)
        dc.fcircle(x - s // 4, y - s // 4, s * 66 // 100)
        dc.col(0x8B928A)
        dc.fcircle(x - s // 3, y - s // 3, s * 34 // 100)

    def props(self, dc, items):
        for x, y, s, k in items:
            if k == 0:
                self.tree(dc, x, y, s)
            else:
                self.rock(dc, x, y, s)

    def _stroke(self, dc, pts, w, col):
        if w < 1:
            return
        dc.pen = w
        dc.col(col)
        for i in range(1, len(pts)):
            dc.line(pts[i - 1][0], pts[i - 1][1], pts[i][0], pts[i][1])
        for i in range(1, len(pts) - 1):
            dc.fcircle(pts[i][0], pts[i][1], w // 2)

    def path_body(self, dc, pts, pw):
        if len(pts) < 2:
            return
        self._stroke(dc, pts, pw + 6, shade(C_DIRT_D, 62))
        self._stroke(dc, pts, pw + 3, 0x796A50)
        self._stroke(dc, pts, pw, C_DIRT)
        self._stroke(dc, pts, pw * 46 // 100, mix(C_DIRT, 0x9A8058, 55))
        dc.pen = 1

    def cobbles(self, dc, items):
        for x, y, s, c in items:
            dc.col(shade(c, 55))
            dc.rect(x, y + 1, s, s)
            dc.col(c)
            dc.rect(x, y, s, s)

    # ── Landmarks ────────────────────────────────────────────────────────────
    def portal(self, dc, x, y, u):
        r = max(5, u * 175 // 100)
        self.shadow(dc, x, y + r // 2, r * 2 // 3, shade(C_GRASS, 45))
        dc.col(0x2A2438)
        dc.fcircle(x, y, r)
        dc.col(0x6A5A88)
        dc.pen = 2
        dc.dcircle(x, y, r)
        dc.pen = 1
        dc.col(0x120A20)
        dc.fcircle(x, y, r * 70 // 100)
        sw = (self.ph // 2) % 8
        d = r * 45 // 100
        for k in range(3):
            slot = sw + k * 3
            dc.col(0xC898FF if k == 0 else 0x7A5AB0)
            dc.fcircle(x + self.ring_x(slot, d), y + self.ring_y(slot, d),
                       u * 30 // 100 + 1)

    def keep(self, dc, x, y, u, hp_pct):
        r = max(6, u * 200 // 100)
        cw = max(2, r // 2)
        self.shadow(dc, x, y + r // 2, r * 4 // 5, shade(C_GRASS, 42))
        dc.col(0x232932)
        dc.rect(x - r - 1, y - r - 1, r * 2 + 2, r * 2 + 2)
        dc.col(0x4A5260)
        dc.rect(x - r, y - r, r * 2, r * 2)
        dc.col(0x6B7683)
        dc.rect(x - r, y - r, r * 2, r * 45 // 100)
        dc.col(0x7C8794)
        mw = max(1, cw // 2)
        for k in range(4):
            dc.rect(x - r + k * (r // 2) + mw // 2, y - r - mw, mw + 1, mw + 1)
        dc.col(0x1B2028)
        dc.rect(x - cw // 2, y + r - cw, cw + 1, cw + 1)
        dc.col(0x59626F)
        for ox in (-r, r):
            for oy in (-r, r):
                dc.fcircle(x + ox, y + oy, cw // 2 + 1)
        speed = max(2, 8 - hp_pct * 5 // 100)
        beat = (self.ph // speed) % 3
        core = C_HP
        if hp_pct < 35:
            core = C_DANGER
        elif hp_pct < 70:
            core = C_GOLD
        dc.col(shade(core, 40))
        dc.fcircle(x, y, r // 2 + beat)
        dc.col(core)
        dc.fcircle(x, y, r // 3 + beat // 2)
        dc.col(0xFFFFFF)
        dc.fcircle(x - r // 8, y - r // 8, r // 8 + 1)
        dc.col(0x2A3038)
        dc.line(x, y - r - cw, x, y - r - cw * 3)
        fw = cw if (self.ph // 5) % 2 != 0 else cw * 3 // 4
        dc.col(core)
        dc.rect(x + 1, y - r - cw * 3, fw, cw)

    def pad(self, dc, x, y, u, sel):
        r = max(4, u * 105 // 100)
        dc.col(shade(C_GRASS, 50))
        dc.fcircle(x, y + 1, r)
        dc.col(0x50564A)
        dc.fcircle(x, y, r)
        dc.col(0x6E766A)
        dc.fcircle(x, y, r * 65 // 100)
        glow = ((self.ph // 4) % 6) < 3
        dc.col(0x8FA37E if glow else 0x6E7A62)
        dc.dcircle(x, y, r)
        if sel:
            dc.pen = 2
            dc.col(0xEFFFC8)
            dc.dcircle(x, y, r + 2)
            dc.pen = 1

    def range_ring(self, dc, x, y, r, col):
        if r < 3:
            return
        sp = (self.ph * 4) % 90
        dc.pen = 3
        dc.col(0x101A14)
        for k in range(4):
            a0 = sp + k * 90
            dc.arc(x, y, r, a0, a0 + 58)
        dc.pen = 2
        dc.col(col)
        for k in range(4):
            a0 = sp + k * 90
            dc.arc(x, y, r, a0, a0 + 58)
        dc.pen = 1

    # ── Towers ───────────────────────────────────────────────────────────────
    def tower(self, dc, t, tier, x, y, u, recoil, hot):
        col = TW_COLOR[t]
        self.shadow(dc, x, y + u // 2, u * 85 // 100, shade(C_GRASS, 42))
        pr = u * (95 + tier * 8) // 100
        dc.col(0x1E2A1C)
        dc.fcircle(x, y, pr + 1)
        dc.col(0x4A4E46)
        dc.fcircle(x, y, pr)
        dc.col(0x767D70)
        dc.fcircle(x, y, pr * 78 // 100)
        dc.col(0x8E958A)
        dc.fcircle(x - pr // 5, y - pr // 5, pr * 40 // 100)
        if tier >= 2:
            dc.col(shade(col, 60))
            dc.dcircle(x, y, pr)

        fn = [self._gun, self._cannon, self._archer, self._frost, self._tesla,
              self._flame, self._sniper][t]
        fn(dc, tier, x, y, u, recoil, col, hot)

        if tier > 1:
            dc.col(C_GOLD)
            pip = max(1, u // 4)
            for k in range(tier - 1):
                dc.rect(x - pr + k * (pip * 2 + 1), y + pr - pip,
                        pip + 1, pip + 1)

    def _gun(self, dc, tier, x, y, u, recoil, col, hot):
        blen = u * (150 + tier * 14) // 100
        dark = BARREL
        if tier >= 4:
            off = u * 3 / 10
            self.abar(dc, x - self.ay * off, y + self.ax * off, -recoil, blen,
                      u * 18 // 100 + 1, dark)
            self.abar(dc, x + self.ay * off, y - self.ax * off, -recoil, blen,
                      u * 18 // 100 + 1, dark)
        else:
            self.abar(dc, x, y, -recoil, blen, u * 22 // 100 + 1, dark)
        self.abar(dc, x, y, blen - u // 4, blen, u * 38 // 100 + 1,
                  shade(col, 85))
        dc.col(shade(col, 80))
        dc.fcircle(x, y, u * 58 // 100 + 1)
        dc.col(col)
        dc.fcircle(x, y, u * 40 // 100 + 1)
        if hot:
            dc.col(0xFFF3C0)
            dc.fcircle(x + self.ax * (blen + 2), y + self.ay * (blen + 2),
                       u // 4 + 1)

    def _cannon(self, dc, tier, x, y, u, recoil, col, hot):
        dark = BARREL
        if tier >= 2:
            wo = u * 85 / 100
            dc.col(0x3A2A1E)
            dc.fcircle(x - self.ay * wo, y + self.ax * wo, u // 3 + 1)
            dc.fcircle(x + self.ay * wo, y - self.ax * wo, u // 3 + 1)
        blen = u * (150 + tier * 10) // 100
        back = -recoil - u // 3
        if tier >= 4:
            off = u * 4 / 10
            self.abar(dc, x - self.ay * off, y + self.ax * off, back, blen,
                      u * 24 // 100 + 1, dark)
            self.abar(dc, x + self.ay * off, y - self.ax * off, back, blen,
                      u * 24 // 100 + 1, dark)
        else:
            self.abar(dc, x, y, back, blen, u * 36 // 100 + 1, dark)
        self.abar(dc, x, y, blen - u // 3, blen - u // 6, u * 46 // 100 + 1,
                  shade(col, 70))
        dc.col(shade(col, 62))
        dc.fcircle(x, y, u * 72 // 100 + 1)
        dc.col(col)
        dc.fcircle(x, y, u * 48 // 100 + 1)
        if hot:
            mx = x + self.ax * (blen + u / 3)
            my = y + self.ay * (blen + u / 3)
            dc.col(0xFFE08A)
            dc.fcircle(mx, my, u // 2 + 1)
            dc.col(0xFFFFFF)
            dc.fcircle(mx, my, u // 4 + 1)

    def _archer(self, dc, tier, x, y, u, recoil, col, hot):
        dc.col(0x6B4A2A)
        dc.fcircle(x, y, u * 78 // 100 + 1)
        dc.col(0x8A6136)
        dc.fcircle(x, y, u * 58 // 100 + 1)
        post = max(1, u // 3)
        dc.col(0x4A3220)
        pr2 = u * 70 // 100
        dc.rect(x - pr2, y - pr2, post, post)
        dc.rect(x + pr2 - post, y - pr2, post, post)
        dc.rect(x - pr2, y + pr2 - post, post, post)
        dc.rect(x + pr2 - post, y + pr2 - post, post, post)
        ang = math.degrees(math.atan2(-self.ay, self.ax))
        bx = x + self.ax * u * 45 / 100
        by = y + self.ay * u * 45 / 100
        br = max(3, u * 70 // 100)
        dc.pen = 2
        dc.col(0xC9A86A)
        dc.arc(bx, by, br, int(ang - 62), int(ang + 62))
        dc.pen = 1
        self.abar(dc, x, y, -u // 4, u * 110 // 100, 1, 0xE8DCC0)
        self.tri(dc, x, y, self.ax, self.ay, u * 95 / 100, u * 135 / 100,
                 u * 22 // 100 + 1, col)
        if tier >= 3:
            bob = (self.ph // 4) % 2
            dc.col(0x3E6B34)
            dc.fcircle(x - self.ax * u * 55 / 100,
                       y - self.ay * u * 55 / 100 + bob, u // 4 + 1)
        if tier >= 4:
            dc.col(col)
            dc.rect(x - 1, y - u * 150 // 100, 2, u)
            self.tri(dc, x, y - u * 145 // 100, 1.0, 0.0, 0.0,
                     u * 60 / 100, u * 30 // 100 + 1, col)

    def _frost(self, dc, tier, x, y, u, recoil, col, hot):
        pulse = (self.ph // 3) % 6
        amp = pulse if pulse <= 3 else 6 - pulse
        dc.col(0x2A4E5E)
        dc.fcircle(x, y, u * 80 // 100 + 1)
        dc.col(0x3E6E82)
        dc.dcircle(x, y, u * 90 // 100 + amp)
        shards = 3 + tier
        sr = u * 110 // 100
        dc.col(shade(col, 70))
        for k in range(shards):
            slot = (k * 8) // shards
            dc.rect(x + self.ring_x(slot, sr) // 2 - 1,
                    y + self.ring_y(slot, sr) // 2 - 1, 3, 3)
        cr = u * 62 // 100 + 1
        self.diamond(dc, x, y, cr * 3 // 4, cr, shade(col, 70))
        self.diamond(dc, x, y, cr // 2, cr * 3 // 4, col)
        dc.col(0xE8FCFF)
        dc.rect(x - 1, y - cr // 2, 2, cr // 2)

    def _tesla(self, dc, tier, x, y, u, recoil, col, hot):
        dc.col(0x7A5A38)
        dc.fcircle(x, y, u * 88 // 100 + 1)
        dc.col(0xA8794A)
        for k in range(2 + tier // 2):
            rr = u * (85 - k * 18) // 100
            if rr < 2:
                break
            dc.dcircle(x, y, rr)
        dc.col(shade(col, 55))
        dc.fcircle(x, y, u * 42 // 100 + 1)
        dc.col(0xF0E4FF)
        dc.fcircle(x, y, u * 26 // 100 + 1)
        forks = 4 if hot else 2
        d = u * 95 // 100
        dc.col(0xFFFFFF if hot else col)
        for f in range(forks):
            slot = self.ph * 3 + f * 5 + f * f
            ox, oy = self.ring_x(slot, d), self.ring_y(slot, d)
            dc.line(x, y, x + ox // 2, y + oy // 2)
            dc.line(x + ox // 2, y + oy // 2, x + ox, y + oy - 1)

    def _flame(self, dc, tier, x, y, u, recoil, col, hot):
        fo = u * 75 / 100
        fr = u * (26 + tier * 4) // 100 + 1
        dc.col(0x54391F)
        dc.fcircle(x - self.ay * fo, y + self.ax * fo, fr)
        dc.fcircle(x + self.ay * fo, y - self.ax * fo, fr)
        dc.col(0x6E4A28)
        dc.fcircle(x, y, u * 70 // 100 + 1)
        self.abar(dc, x, y, 0, u * (110 + tier * 8) // 100,
                  u * 22 // 100 + 1, 0x3A2A1E)
        tip = u * (115 + tier * 8) / 100
        hotf = (self.ph // 2) % 3 != 0
        dc.col(0xFFC24A if hotf else 0xFF6A3A)
        dc.fcircle(x + self.ax * tip, y + self.ay * tip, u // 4 + 1)
        dc.col(col)
        dc.fcircle(x, y, u * 34 // 100 + 1)

    def _sniper(self, dc, tier, x, y, u, recoil, col, hot):
        blen = u * (190 + tier * 22) // 100
        if tier >= 2:
            lo = u * 60 / 100
            self.abar(dc, x, y, u // 2, u * 110 // 100, 1, 0x3A3A32)
            self.abar(dc, x - self.ay * lo, y + self.ax * lo, u // 2, u, 1,
                      0x3A3A32)
            self.abar(dc, x + self.ay * lo, y - self.ax * lo, u // 2, u, 1,
                      0x3A3A32)
        self.abar(dc, x, y, -recoil, blen, u * 14 // 100 + 1, 0x3E3E36)
        if tier >= 3:
            self.abar(dc, x, y, blen - u // 3, blen, u * 28 // 100 + 1,
                      shade(col, 70))
        dc.col(0x55554A)
        dc.fcircle(x, y, u * 60 // 100 + 1)
        dc.col(col)
        dc.fcircle(x, y, u * 34 // 100 + 1)
        glint = (self.ph // 3) % 9 == 0
        dc.col(0xFFFFFF if glint else 0x9AA8B4)
        dc.rect(x - self.ax * u * 55 / 100 - 1,
                y - self.ay * u * 55 / 100 - 1, 3, 3)

    # ── Enemies ──────────────────────────────────────────────────────────────
    def enemy(self, dc, t, x, y, r, flash, slow, hp_pct, extra):
        col = EN_COLOR[t]
        if flash > 0:
            col = mix(col, 0xFFFFFF, 70)
        elif slow > 0:
            col = mix(col, 0x66DCEE, 35)
        by = y
        if t == EN_FLYER:
            self.shadow(dc, x, y, r * 2 // 3, shade(C_GRASS, 40))
            by = y - r * 2
        else:
            self.shadow(dc, x, y + r // 2, r * 3 // 4, shade(C_GRASS, 44))
        dc.col(shade(col, 26))
        dc.fcircle(x, by, r + 1)
        fn = [self._grunt, self._runner, self._tank, self._flyer,
              self._shield, self._healer, self._boss][t]
        fn(dc, x, by, r, col, hp_pct, extra)
        if slow > 0:
            dc.col(0x8AE8FA)
            dc.dcircle(x, by, r + 2)

    def _legs(self, dc, x, y, r, col):
        s = max(1, r * 3 // 5)
        f = 1 if (self.ph // 2) % 2 == 0 else -1
        side = r * 6 / 10
        stride = r * f / 2
        dc.col(shade(col, 55))
        dc.rect(x - self.ay * side + self.ax * stride - s / 2,
                y + self.ax * side + self.ay * stride, s, s)
        dc.rect(x + self.ay * side - self.ax * stride - s / 2,
                y - self.ax * side - self.ay * stride, s, s)

    def _grunt(self, dc, x, y, r, col, hp, extra):
        self._legs(dc, x, y, r, col)
        so = r * 95 / 100
        dc.col(shade(col, 46))
        dc.fcircle(x - self.ay * so, y + self.ax * so, r * 42 // 100 + 1)
        dc.fcircle(x + self.ay * so, y - self.ax * so, r * 42 // 100 + 1)
        dc.col(shade(col, 70))
        dc.fcircle(x, y, r)
        dc.col(col)
        dc.fcircle(x - self.ax * r / 6, y - self.ay * r / 6, r * 76 // 100)
        sw = max(1, r // 6)
        self.abar(dc, x, y, r * 6 // 10, r * 19 // 10, sw, 0x2C2116)
        self.abar(dc, x, y, r * 17 // 10, r * 19 // 10, sw + 1, 0xB9BEC4)
        dc.col(mix(col, 0xFFFFFF, 42))
        dc.fcircle(x + self.ax * r * 52 / 100, y + self.ay * r * 52 / 100,
                   r * 44 // 100 + 1)
        dc.col(0x1A0E0A)
        dc.rect(x + self.ax * r * 82 / 100 - 1,
                y + self.ay * r * 82 / 100 - 1, 2, 2)

    def _runner(self, dc, x, y, r, col, hp, extra):
        dc.pen = 2
        dc.col(mix(col, 0xFFFFFF, 45))
        so = r * 7 / 10
        for sg in (-1, 1):
            dc.line(x - self.ax * r * 25 / 10 - sg * self.ay * so,
                    y - self.ay * r * 25 / 10 + sg * self.ax * so,
                    x - self.ax * r * 11 / 10 - sg * self.ay * so,
                    y - self.ay * r * 11 / 10 + sg * self.ax * so)
        dc.pen = 1
        self._legs(dc, x, y, r, col)
        self.abar(dc, x, y, -r * 9 // 10, r * 9 // 10, r * 62 // 100,
                  shade(col, 62))
        self.abar(dc, x, y, -r * 6 // 10, r * 8 // 10, r * 42 // 100, col)
        dc.col(mix(col, 0xFFFFFF, 50))
        dc.fcircle(x + self.ax * r * 78 / 100, y + self.ay * r * 78 / 100,
                   r * 50 // 100 + 1)
        dc.col(0x2A1A08)
        dc.rect(x + self.ax * r * 110 / 100 - 1,
                y + self.ay * r * 110 / 100 - 1, 2, 2)

    def _tank(self, dc, x, y, r, col, hp, extra):
        to = r * 85 / 100
        self.abar(dc, x - self.ay * to, y + self.ax * to, -r, r,
                  r * 3 // 10, 0x241B14)
        self.abar(dc, x + self.ay * to, y - self.ax * to, -r, r,
                  r * 3 // 10, 0x241B14)
        step = 0 if (self.ph // 3) % 2 == 0 else r * 4 // 10
        for k in range(3):
            d = -r + step + k * r * 8 // 10
            if d > r - 2:
                continue
            for sg in (-1, 1):
                self.quad(dc, x - sg * self.ay * to, y + sg * self.ax * to,
                          self.ax, self.ay, d, d + 2, r * 3 // 10, 0x5E4B37)
        self.abar(dc, x, y, -r * 9 // 10, r * 9 // 10, r * 7 // 10,
                  shade(col, 70))
        self.abar(dc, x, y, -r * 6 // 10, r * 6 // 10, r * 5 // 10, col)
        self.abar(dc, x, y, r * 75 // 100, r * 115 // 100, r * 8 // 10,
                  0x9AA2AA)
        dc.col(0x50565C)
        dc.rect(x + self.ax * r - 1, y + self.ay * r - 1, 2, 2)

    def _flyer(self, dc, x, y, r, col, hp, extra):
        up = (self.ph // 2) % 2 == 0
        span = r * 17 / 10 if up else r * 11 / 10
        sweep = r * 7 / 10 if up else r * 2 / 10
        dc.col(shade(col, 62))
        for sgn in (-1, 1):
            dc.poly([(x, y), (x + sgn * self.ay * span - self.ax * sweep,
                              y - sgn * self.ax * span - self.ay * sweep),
                     (x - self.ax * r, y - self.ay * r)])
        dc.col(col)
        dc.fcircle(x, y, r * 65 // 100 + 1)
        dc.col(0xFFF0C0)
        dc.rect(x + self.ax * r * 5 / 10 - 1, y + self.ay * r * 5 / 10 - 1,
                2, 2)

    def _shield(self, dc, x, y, r, col, hp, extra):
        self._legs(dc, x, y, r, col)
        dc.col(shade(col, 60))
        dc.fcircle(x, y, r * 80 // 100)
        dc.col(col)
        dc.fcircle(x, y, r * 58 // 100)
        self.abar(dc, x, y, r * 6 // 10, r * 105 // 100, r * 105 // 100,
                  0xD6DCE4)
        self.abar(dc, x, y, r * 75 // 100, r * 9 // 10, r * 105 // 100,
                  0x8A929C)
        dc.col(0xFFFFFF if extra > 0 else 0x5A6470)
        dc.dcircle(x, y, r + 1)

    def _healer(self, dc, x, y, r, col, hp, extra):
        pulse = (self.ph // 2) % 8
        amp = pulse if pulse <= 4 else 8 - pulse
        dc.col(shade(col, 40))
        dc.dcircle(x, y, r + amp)
        dc.col(shade(col, 55))
        dc.poly([(x, y - r - r // 2), (x - r, y + r), (x + r, y + r)])
        dc.col(col)
        dc.fcircle(x, y, r * 55 // 100 + 1)
        dc.col(0xEAFFF4)
        dc.rect(x - 1, y - r // 2, 2, r)
        dc.rect(x - r // 2, y - 1, r, 2)

    def _boss(self, dc, x, y, r, col, hp_pct, ability):
        aura = [0x7A1030, 0x2A6AA8, 0x6A2A9A, 0x1F7A4A][ability % 4]
        beat = (self.ph // 3) % 4
        dc.col(aura)
        dc.fcircle(x, y, r + beat)
        dc.col(shade(col, 55))
        dc.fcircle(x, y, r)
        dc.col(col)
        dc.fcircle(x, y, r * 76 // 100)
        cw = max(2, r // 2)
        dc.col(C_GOLD)
        dc.rect(x - r, y - r - cw // 2, r * 2, cw // 2 + 1)
        for ox in (-r + cw // 2, 0, r - cw // 2):
            ln = cw * 3 // 2 if ox == 0 else cw
            self.tri(dc, x + ox, y - r, 0.0, -1.0, 0.0, ln, cw // 2 + 1, C_GOLD)
        dc.col(0xFFF0A0)
        ex = x + self.ax * r * 45 / 100
        ey = y + self.ay * r * 45 / 100
        eo = r * 35 / 100
        dc.rect(ex - self.ay * eo - 1, ey + self.ax * eo - 1, 3, 3)
        dc.rect(ex + self.ay * eo - 1, ey - self.ax * eo - 1, 3, 3)
        bw = r * 2
        dc.col(0x1A1014)
        dc.rect(x - bw // 2, y - r - cw * 2, bw, 3)
        dc.col(C_DANGER)
        dc.rect(x - bw // 2, y - r - cw * 2, max(1, bw * hp_pct // 100), 3)

    def enemy_icon(self, dc, t, x, y, s):
        col = EN_COLOR[t]
        dc.col(col)
        if t == EN_FLYER:
            dc.fcircle(x, y, s // 2)
            dc.line(x - s * 3 // 2, y - s // 2, x, y)
            dc.line(x + s * 3 // 2, y - s // 2, x, y)
        elif t == EN_TANK:
            dc.rect(x - s, y - s // 2, s * 2, s)
        elif t == EN_SHIELD:
            dc.fcircle(x, y, s // 2)
            dc.col(0xD6DCE4)
            dc.rect(x + s // 2, y - s, 2, s * 2)
        elif t == EN_HEALER:
            dc.fcircle(x, y, s // 2)
            dc.col(0xEAFFF4)
            dc.rect(x - 1, y - s // 2, 2, s)
            dc.rect(x - s // 2, y - 1, s, 2)
        elif t == EN_BOSS:
            dc.fcircle(x, y, s)
            dc.col(C_GOLD)
            dc.rect(x - s, y - s - 2, s * 2, 2)
        elif t == EN_RUNNER:
            dc.fcircle(x, y, s // 2)
            dc.line(x - s * 3 // 2, y, x - s // 2, y)
        else:
            dc.fcircle(x, y, s * 2 // 3)

    def tower_icon(self, dc, t, x, y, s):
        col = TW_COLOR[t]
        dc.col(0x1E2630)
        dc.fcircle(x, y, s)
        dc.col(col)
        if t == TW_GUN:
            dc.fcircle(x, y, s // 2)
            dc.rect(x, y - 1, s, 2)
        elif t == TW_CANNON:
            dc.fcircle(x - s // 4, y, s // 2)
            dc.rect(x, y - 2, s, 4)
        elif t == TW_ARCHER:
            dc.arc(x - s // 3, y, s * 3 // 4, -60, 60)
            dc.rect(x - s // 2, y - 1, s * 3 // 2, 2)
        elif t == TW_FROST:
            self.diamond(dc, x, y, s // 2, s, col)
        elif t == TW_TESLA:
            dc.dcircle(x, y, s * 2 // 3)
            dc.line(x, y, x + s, y - s)
            dc.fcircle(x, y, s // 3)
        elif t == TW_FLAME:
            self.tri(dc, x - s // 2, y, 1.0, 0.0, 0.0, s * 3 // 2,
                     s * 2 // 3, col)
        else:
            dc.rect(x - s, y - 1, s * 2, 2)
            dc.fcircle(x - s // 2, y, s // 3)

    # ── HUD widgets ──────────────────────────────────────────────────────────
    def panel(self, dc, x, y, w, h, fill, border):
        dc.col(fill)
        dc.frect(x, y, w, h, 5)
        dc.col(border)
        dc.pen = 1
        dc.drect(x, y, w, h, 5)

    def bar(self, dc, x, y, w, h, pct, bg, fg):
        dc.col(bg)
        dc.rect(x, y, w, h)
        dc.col(fg)
        f = max(0, min(w, w * pct // 100))
        if f > 0:
            dc.rect(x, y, f, h)

    def coin(self, dc, x, y, r):
        dc.col(0xB88A20)
        dc.fcircle(x, y, r)
        dc.col(C_GOLD)
        dc.fcircle(x, y, r - 1)
        dc.col(0x8A6410)
        dc.rect(x - 1, y - r // 2, 2, r)

    def heart(self, dc, x, y, r, col):
        dc.col(col)
        dc.fcircle(x - r // 2, y - r // 3, r * 2 // 3)
        dc.fcircle(x + r // 2, y - r // 3, r * 2 // 3)
        dc.poly([(x - r, y - r // 4), (x + r, y - r // 4), (x, y + r)])


# ── Map (TdMap.mc) ───────────────────────────────────────────────────────────
PATHS = [
    [14, 30, 80, 30, 80, 54, 22, 54, 22, 76, 76, 76],
    [16, 22, 84, 22, 84, 38, 16, 38, 16, 54, 84, 54, 84, 70, 26, 70, 26, 84,
     58, 84],
    [50, 10, 82, 26, 88, 58, 62, 84, 30, 84, 12, 58, 20, 32, 44, 26, 56, 42,
     50, 54],
    [14, 26, 44, 26, 50, 44, 56, 26, 86, 26, 86, 60, 56, 60, 50, 78, 44, 60,
     14, 60],
]
PADS = [
    [46, 18, 80, 16, 92, 42, 50, 42, 12, 44, 50, 66, 12, 66, 86, 62, 48, 90,
     66, 90],
    [50, 30, 24, 30, 76, 30, 50, 46, 24, 46, 76, 46, 50, 62, 76, 62, 14, 62,
     44, 76],
    [66, 14, 34, 14, 92, 42, 76, 68, 46, 92, 20, 74, 8, 44, 30, 50, 68, 52,
     50, 70],
    [50, 34, 50, 52, 30, 18, 70, 18, 28, 42, 72, 42, 36, 72, 64, 72, 50, 88,
     20, 44],
]
MAP_NAMES = ["BEND", "SNAKE", "RING", "GATE"]


class Layout:
    """onLayout + _loadMap + _bakeTerrain from the view."""

    def __init__(self, w, h, map_idx):
        self.w, self.h = w, h
        self.cx, self.cy = w // 2, h // 2
        m = min(w, h)
        self.rad = m // 2 - 2
        self.side = m * 64 // 100
        self.ox = self.cx - self.side // 2
        self.oy = self.cy - self.side // 2 - m // 60
        self.u = max(3, self.side // 28)
        self.tu = max(4, self.side // 24)
        self.pw = max(5, self.side * 7 // 100)
        self.map_idx = map_idx

        raw = PATHS[map_idx]
        self.path = [(self.ox + raw[i * 2] * self.side // 100,
                      self.oy + raw[i * 2 + 1] * self.side // 100)
                     for i in range(len(raw) // 2)]
        pads = PADS[map_idx]
        self.pads = [(self.ox + pads[i * 2] * self.side // 100,
                      self.oy + pads[i * 2 + 1] * self.side // 100)
                     for i in range(len(pads) // 2)]
        self._bake()

    def _seg_lens(self):
        acc, out, dirs = 0.0, [0.0], [(1.0, 0.0)]
        for i in range(1, len(self.path)):
            dx = self.path[i][0] - self.path[i - 1][0]
            dy = self.path[i][1] - self.path[i - 1][1]
            ln = max(0.5, math.hypot(dx, dy))
            acc += ln
            out.append(acc)
            dirs.append((dx / ln, dy / ln))
        return out, dirs

    def dist_to_path(self, x, y):
        best = 1e9
        for i in range(1, len(self.path)):
            ax, ay = self.path[i - 1]
            bx, by = self.path[i]
            vx, vy = bx - ax, by - ay
            ln2 = vx * vx + vy * vy
            t = 0.0 if ln2 == 0 else max(0.0, min(1.0, ((x - ax) * vx +
                                                        (y - ay) * vy) / ln2))
            best = min(best, math.hypot(x - (ax + vx * t), y - (ay + vy * t)))
        return best

    def _bake(self):
        px = max(2, self.side // 40)
        self.deco = []
        for i in range(MAX_DECO):
            hx = hash3(self.map_idx, i, 3) % 100
            hy = hash3(self.map_idx, i, 19) % 100
            x = self.ox + hx * self.side // 100
            y = self.oy + hy * self.side // 100
            if self.dist_to_path(x, y) < self.pw:
                continue
            if ((x - self.cx) ** 2 + (y - self.cy) ** 2
                    > (self.rad - px * 2) ** 2):
                continue
            kind = hash3(i, self.map_idx, 41) % 10
            col, s = C_GRASS3, px
            if kind < 3:
                col = mix(C_GRASS2, 0x4E8A52, 45)
            elif kind < 5:
                col, s = shade(C_GRASS, 62), px + px // 2
            elif kind < 7:
                col, s = 0x6E7466, px - 1
            elif kind < 9:
                col, s = shade(C_GRASS2, 130), px - 1
            s = max(2, s)
            self.deco.append((x - s // 2, y - s // 2, s, col))

        base = max(4, self.side // 14)
        self.props = []
        for i in range(48):
            if len(self.props) >= MAX_PROP:
                break
            hx = hash3(self.map_idx, i, 53) % 100
            hy = hash3(self.map_idx, i, 71) % 100
            x = self.ox + hx * self.side // 100
            y = self.oy + hy * self.side // 100
            room = int(self.dist_to_path(x, y)) - self.pw // 2 - 3
            for px, py in self.pads:
                room = min(room,
                           int(math.hypot(x - px, y - py)) - self.tu * 3 // 2)
            room = min(room, self.rad - int(math.hypot(x - self.cx,
                                                       y - self.cy)))
            s = min(base, room * 70 // 100)
            small = base * 50 // 100
            if s < small:
                if s >= 5:
                    self.props.append((x, y, s, 1))
                continue
            rock = hash3(i, self.map_idx, 89) % 5 == 0
            if rock:
                s = s * 60 // 100
            self.props.append((x, y, s, 1 if rock else 0))

        cs = max(2, self.pw // 3)
        step = cs + 2
        lens, dirs = self._seg_lens()
        total = max(1.0, lens[-1])
        self.cob = []
        d, seg, m = float(step), 1, 0
        while d < total and m < MAX_STONE - 1:
            while seg < len(self.path) and lens[seg] < d:
                seg += 1
            if seg >= len(self.path):
                break
            t = (d - lens[seg - 1]) / (lens[seg] - lens[seg - 1])
            bx = self.path[seg - 1][0] + (self.path[seg][0]
                                          - self.path[seg - 1][0]) * t
            by = self.path[seg - 1][1] + (self.path[seg][1]
                                          - self.path[seg - 1][1]) * t
            nx, ny = -dirs[seg][1], dirs[seg][0]
            off = ((m % 3) - 1) * self.pw / 3
            jitter = (hash3(m, self.map_idx, 7) % 3) - 1
            sz = cs + (hash3(m, self.map_idx, 13) % 2)
            sp = 78 + (hash3(m, self.map_idx, 29) % 45)
            self.cob.append((int(bx + nx * off) - sz // 2 + jitter,
                             int(by + ny * off) - sz // 2, sz,
                             shade(C_DIRT, sp)))
            m += 1
            d += step

    def at(self, frac):
        """Point and direction `frac` along the path."""
        lens, dirs = self._seg_lens()
        d = lens[-1] * frac
        seg = 1
        while seg < len(lens) - 1 and lens[seg] < d:
            seg += 1
        t = (d - lens[seg - 1]) / max(0.001, lens[seg] - lens[seg - 1])
        return (self.path[seg - 1][0] + (self.path[seg][0]
                                         - self.path[seg - 1][0]) * t,
                self.path[seg - 1][1] + (self.path[seg][1]
                                         - self.path[seg - 1][1]) * t,
                dirs[seg][0], dirs[seg][1])


# ── Text ─────────────────────────────────────────────────────────────────────
def font(px):
    for p in ("/System/Library/Fonts/Supplemental/Arial Bold.ttf",
              "/System/Library/Fonts/Helvetica.ttc"):
        try:
            return ImageFont.truetype(p, px)
        except OSError:
            continue
    return ImageFont.load_default()


def text(dc, x, y, f, s, col, anchor="la"):
    dc.d.text((x, y), s, font=f, fill=rgb(col), anchor=anchor)


# ── Scene ────────────────────────────────────────────────────────────────────
def render(tick=24, map_idx=0):
    w = h = SCREEN
    dc = DC(w, h)
    L = Layout(w, h, map_idx)
    A = Art()
    A.frame(tick, L.u)

    A.ground(dc, L.cx, L.cy, L.rad)
    A.deco(dc, L.deco)
    A.path_body(dc, L.path, L.pw)
    A.cobbles(dc, L.cob)
    A.props(dc, L.props)
    A.portal(dc, L.path[0][0], L.path[0][1], L.tu)
    A.keep(dc, L.path[-1][0], L.path[-1][1], L.tu, 74)

    # A representative mid-run board: a mix of tiers on the pads that matter,
    # a pack strung out along the road, one selected tower showing its range.
    built = [(0, TW_GUN, 2), (1, TW_ARCHER, 3), (3, TW_CANNON, 2),
             (5, TW_FROST, 1), (7, TW_TESLA, 4), (8, TW_SNIPER, 2)]
    taken = {p for p, _, _ in built}
    for i, (px, py) in enumerate(L.pads):
        if i in taken:
            continue
        A.pad(dc, px, py, L.tu, i == 4)

    sel = built[3]
    A.range_ring(dc, L.pads[sel[0]][0], L.pads[sel[0]][1],
                 24 * L.side // 100, shade(TW_COLOR[sel[1]], 75))

    pack = [(EN_GRUNT, 0.18), (EN_RUNNER, 0.27), (EN_TANK, 0.40),
            (EN_SHIELD, 0.52), (EN_GRUNT, 0.60), (EN_FLYER, 0.70),
            (EN_BOSS, 0.84)]
    for i, (pad_i, tt, tier) in enumerate(built):
        px, py = L.pads[pad_i]
        ex, ey, _, _ = L.at(pack[i % len(pack)][1])
        dx, dy = ex - px, ey - py
        n = max(0.001, math.hypot(dx, dy))
        A.aim(dx / n, dy / n)
        A.tower(dc, tt, tier, px, py, L.tu, 0, i % 3 == 0)

    for tt, frac in pack:
        ex, ey, dx, dy = L.at(frac)
        A.aim(dx, dy)
        r = L.u
        if tt == EN_RUNNER:
            r = L.u * 75 // 100
        elif tt == EN_TANK:
            r = L.u * 145 // 100
        elif tt == EN_SHIELD:
            r = L.u * 125 // 100
        elif tt == EN_BOSS:
            r = L.u * 195 // 100
        elif tt == EN_FLYER:
            r = L.u * 105 // 100
        A.enemy(dc, tt, int(ex), int(ey), r, 0, 0, 62, 0)

    hud(dc, L, A, tick)

    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, w - 1, h - 1], fill=255)
    out = Image.new("RGB", (w, h), (0, 0, 0))
    out.paste(dc.im, (0, 0), mask)
    return out


def band_w(L, y0, y1):
    d = max(abs(y0 - L.cy), abs(y1 - L.cy))
    lim = L.rad - 3
    if d >= lim:
        return 16
    return int(math.sqrt(lim * lim - d * d)) * 2


def fit_w(L, want, y0, y1):
    return min(want, band_w(L, y0, y1))


def hud(dc, L, A, tick):
    fx = font(21)
    fh = 24
    ph = fh + 10
    py = L.h * 9 // 100
    pw = fit_w(L, L.w * 58 // 100, py, py + ph)
    px = L.cx - pw // 2
    A.panel(dc, px, py, pw, ph, 0x0B1520, 0x243544)
    text(dc, L.cx, py + 4, fx, "W7/30", C_TEXT, "ma")
    A.bar(dc, px + 8, py + ph - 5, pw - 16, 3, 46, 0x22303C, 0xF2B33D)

    cy2 = py + ph + 2
    text(dc, L.cx, cy2 + 2, fx, "SWARM", 0xF2B33D, "ma")

    sfh = max(12, min(20, L.h * 8 // 100))
    bot = L.h - L.h * 12 // 100
    top = bot - sfh * 2 - 8
    sw = fit_w(L, L.w * 84 // 100, top, bot)
    sx = L.cx - sw // 2
    A.panel(dc, sx, top, sw, bot - top, 0x0B1520, 0x243544)
    cr = sfh // 3
    A.coin(dc, sx + 10 + cr, top + 2 + sfh // 2, cr)
    text(dc, sx + 14 + cr * 2, top + 4, fx, "245", C_GOLD)
    A.heart(dc, sx + sw - 12 - cr, top + 2 + sfh // 2, cr, C_HP)
    text(dc, sx + sw - 16 - cr * 2, top + 4, fx, "18", C_HP, "ra")
    text(dc, L.cx, top + sfh + 3, fx, "START WAVE 7", C_MUTED, "ma")

    r = max(8, L.w * 7 // 100)
    inset = r + L.w * 2 // 100
    for a, col in ((0, 0xFF8A3A), (1, 0x66DCEE)):
        x = inset if a == 0 else L.w - inset
        dc.col(0x0B1520)
        dc.fcircle(x, L.cy, r)
        dc.col(col)
        dc.dcircle(x, L.cy, r)
        if a == 0:
            dc.fcircle(x, L.cy + 1, r // 3)
            dc.rect(x - 1, L.cy - r // 2, 2, r // 3)
        else:
            A.diamond(dc, x, L.cy, r // 3, r // 2, col)
        text(dc, x, L.cy + r + 2, fx, "65" if a == 0 else "40", C_GOLD, "ma")


if __name__ == "__main__":
    path = sys.argv[1] if len(sys.argv) > 1 else "/tmp/td_face.png"
    tick = int(sys.argv[2]) if len(sys.argv) > 2 else 24
    mp = int(sys.argv[3]) if len(sys.argv) > 3 else 0
    render(tick, mp).save(path)
    print("wrote", path)
