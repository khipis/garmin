#!/usr/bin/env python3
"""Render a Backrooms Run watch face for the store hero.

This is a straight port of the game's own renderer (MapGenerator.mc,
Raycaster.mc, Renderer.mc): same seeded map, same DDA cast, same 4-level
palette ramps, same projection constants. It exists because the hero needs a
clean 454x454 frame and the Connect IQ simulator is not always available; keep
it in sync with the .mc constants if those change.

    python3 _LOGOS/_compose_backrooms_face.py out.png
"""
import sys

from PIL import Image, ImageDraw, ImageFont

MAP_W = MAP_H = 24
SCREEN = 454
COLS = 48                 # DETAIL = HIGH
FOV_PLANE = 0.72
WALL_SCALE = 102
WALL_CAP = 128
FOG_START = 1
FOG_CELLS = 12
RAMP_N = 10
MAX_DDA = 32
TEX = 2                   # DETAIL = HIGH
GRID_ROWS = 7
GRID_K = 4

WALL = [0xFFFF55, 0xAAAA55, 0xAAAA55, 0xAAAA00, 0xAAAA00,
        0x555500, 0x555500, 0x555500, 0x000000, 0x000000]
CEIL = [0xAAAAAA, 0xAAAAAA, 0xAAAA55, 0x555555, 0x555500, 0x000000]
FLOOR = [0x000000, 0x555500, 0x555500, 0xAA5500, 0xAA5500]
FLOOR2 = [0x000000, 0x000000, 0x550000, 0x555500, 0x555500]
CEIL_GRID = 0x555555
FLOOR_GRID = 0x550000
PANEL = 0xFFFFFF


def rgb(c):
    return ((c >> 16) & 0xFF, (c >> 8) & 0xFF, c & 0xFF)


def ramp(r, i):
    return rgb(r[max(0, min(i, len(r) - 1))])


# ── Map (port of MapGenerator.mc) ────────────────────────────────────────────
def nrand(s):
    return (s * 1103515245 + 12345) & 0x7FFFFFFF


class Map:
    def __init__(self):
        self.walls = [(1 << MAP_W) - 1] * MAP_H
        self.rooms = []
        self.sp = []

    def is_wall(self, x, y):
        if x < 0 or y < 0 or x >= MAP_W or y >= MAP_H:
            return True
        return (self.walls[y] >> x) & 1

    def clr(self, x, y):
        if 0 <= x < MAP_W and 0 <= y < MAP_H:
            self.walls[y] &= ~(1 << x)


def carve_h(m, xa, xb, y):
    for x in range(min(xa, xb), max(xa, xb) + 1):
        m.clr(x, y)


def carve_v(m, ya, yb, x):
    for y in range(min(ya, yb), max(ya, yb) + 1):
        m.clr(x, y)


def corridor(m, x0, y0, x1, y1, s):
    if (s & 1) == 0:
        carve_h(m, x0, x1, y0)
        carve_v(m, y0, y1, x1)
    else:
        carve_v(m, y0, y1, x0)
        carve_h(m, x0, x1, y1)


def gen(seed, level=0):
    m = Map()
    s = (seed ^ (level * 68917 + 13)) & 0x7FFFFFFF
    room_n = min(7 + level // 3, 9)
    sec = MAP_W // 3
    px = py = 0
    for i in range(room_n):
        sx0, sy0 = (i % 3) * sec, min((i // 3) * sec, MAP_H - sec)
        s = nrand(s); rw = 3 + s % 4
        s = nrand(s); rh = 3 + s % 3
        s = nrand(s); rx = sx0 + 1 + s % (sec - rw)
        s = nrand(s); ry = sy0 + 1 + s % (sec - rh)
        rx = max(1, min(rx, MAP_W - 1 - rw))
        ry = max(1, min(ry, MAP_H - 1 - rh))
        for yy in range(ry, ry + rh):
            for xx in range(rx, rx + rw):
                m.clr(xx, yy)
        m.rooms.append((rx, ry, rw, rh))
        cx, cy = rx + rw // 2, ry + rh // 2
        if i > 0:
            corridor(m, px, py, cx, cy, s)
        px, py = cx, cy
        s = nrand(s)
        if rw >= 4 and rh >= 4 and s % 100 < 55:
            m.walls[ry + 1] |= (1 << (rx + 1))
    if len(m.rooms) >= 4:
        s = nrand(s)
        ra, rb = m.rooms[s % 2], m.rooms[len(m.rooms) - 1 - (s % 2)]
        corridor(m, ra[0] + ra[2] // 2, ra[1] + ra[3] // 2,
                 rb[0] + rb[2] // 2, rb[1] + rb[3] // 2, s)
    rl = m.rooms[-1]
    ex, ey = rl[0] + rl[2] // 2, rl[1] + rl[3] // 2
    m.clr(ex, ey)
    m.sp.append((ex, ey, "exit"))
    return m


# ── Cast (port of Raycaster.mc) ──────────────────────────────────────────────
def cast(m, px, py, dx, dy, plx, ply, cols=COLS):
    out = []
    last = cols - 1
    for c in range(cols):
        camx = 2.0 * c / last - 1.0
        rdx, rdy = dx + plx * camx, dy + ply * camx
        mx, my = int(px), int(py)
        ddx = 1e6 if rdx == 0 else abs(1.0 / rdx)
        ddy = 1e6 if rdy == 0 else abs(1.0 / rdy)
        if rdx < 0:
            stepx, sdx = -1, (px - mx) * ddx
        else:
            stepx, sdx = 1, (mx + 1.0 - px) * ddx
        if rdy < 0:
            stepy, sdy = -1, (py - my) * ddy
        else:
            stepy, sdy = 1, (my + 1.0 - py) * ddy
        hit, side, guard = False, 0, 0
        while not hit and guard < MAX_DDA:
            guard += 1
            if sdx < sdy:
                sdx += ddx; mx += stepx; side = 0
            else:
                sdy += ddy; my += stepy; side = 1
            if m.is_wall(mx, my):
                hit = True
        perp = (sdx - ddx) if side == 0 else (sdy - ddy)
        perp = max(perp, 0.06)
        if not hit:
            perp = 60.0
        wx = (py + perp * rdy) if side == 0 else (px + perp * rdx)
        wx -= int(wx)
        out.append((perp, side, wx, mx, my))
    return out


def fog_step(perp):
    t = perp - FOG_START
    if t <= 0:
        return 0
    return min(int(t * RAMP_N / FOG_CELLS), RAMP_N - 1)


# ── Draw (port of Renderer.mc) ───────────────────────────────────────────────
def _row(k, n, span):
    """Depth of the k-th perspective row, squared so rows bunch at the horizon."""
    return span * k * k // (n * n)


def dither(d, x, y, w, h, col, step):
    for yy in range(y, y + h, step):
        d.rectangle([x, yy, x + w, yy], fill=col)


def render(m, px, py, ang, level_name="LOBBY", sanity=74, clock="1:12",
           torch=62, stam=100):
    import math
    w = h = SCREEN
    dx, dy = math.cos(ang), math.sin(ang)
    plx, ply = -dy * FOV_PLANE, dx * FOV_PLANE
    horizon = h // 2
    cx_s = w // 2

    im = Image.new("RGB", (w, h), (0, 0, 0))
    d = ImageDraw.Draw(im)

    # ── Ceiling: grey acoustic tiles, banded by depth not by screen space
    nc = len(CEIL)
    for i in range(nc):
        y_far = horizon - _row(i, nc, horizon)
        y_near = max(0, horizon - _row(i + 1, nc, horizon))
        d.rectangle([0, y_near, w, y_far], fill=ramp(CEIL, nc - 1 - i))
    for k in range(1, GRID_ROWS + 1):
        dd = _row(k, GRID_ROWS, horizon)
        y = horizon - dd
        if y < 0:
            break
        seg = max(1, dd - _row(k - 1, GRID_ROWS, horizon))
        d.rectangle([0, y, w, y], fill=rgb(CEIL_GRID))
        for j in (1, 2, 3):
            off = j * w * dd // (horizon * GRID_K)
            if off > w // 2:
                break
            d.rectangle([cx_s - off, y, cx_s - off, y + seg], fill=rgb(CEIL_GRID))
            d.rectangle([cx_s + off, y, cx_s + off, y + seg], fill=rgb(CEIL_GRID))

    # ── Floor: damp carpet on the same grid
    fh = h - horizon
    nf = len(FLOOR)
    for j in range(nf):
        g0 = horizon + _row(j, nf, fh)
        g1 = min(h, horizon + _row(j + 1, nf, fh))
        d.rectangle([0, g0, w, g1], fill=ramp(FLOOR, j))
    for k in range(1, GRID_ROWS + 1):
        dd = _row(k, GRID_ROWS, fh)
        y = horizon + dd
        if y >= h:
            break
        seg = max(1, dd - _row(k - 1, GRID_ROWS, fh))
        d.rectangle([0, y, w, y], fill=rgb(FLOOR_GRID))
        if seg > 5:
            dither(d, 0, y + 1, w, seg - 1, ramp(FLOOR2, nf * k // GRID_ROWS), 3)
        for j in (1, 2, 3):
            off = j * w * dd // (fh * GRID_K)
            if off > w // 2:
                break
            d.rectangle([cx_s - off, y, cx_s - off, y + seg], fill=rgb(FLOOR_GRID))
            d.rectangle([cx_s + off, y, cx_s + off, y + seg], fill=rgb(FLOOR_GRID))

    # ── Pools of light under each fitting, at the fittings' own depths
    last = horizon + fh * 74 // 100
    for p in range(1, 5):
        dp = _row(p, 5, fh)
        pyy = horizon + dp
        if pyy >= last:
            break
        pw = w * dp // (fh * 2) * 8 // 5
        ph = dp // 6 + 2
        if pw < 6:
            continue
        ph = min(ph, last - pyy)
        dither(d, cx_s - pw // 2, pyy, pw, ph, rgb(0xFFAA55), 4)
        dither(d, cx_s - pw // 4, pyy, pw // 2, ph, rgb(0xFFAA55), 2)

    # ── Fluorescent fittings receding down the hall
    for p in range(1, 5):
        dp = _row(p, 5, horizon)
        pyy = horizon - dp
        pw = w * dp // (horizon * 2)
        if pw < 5:
            continue
        ph = dp // 9 + 2
        d.rectangle([cx_s - pw // 2 - 1, pyy - 1, cx_s + pw // 2 + 1, pyy + ph + 1],
                    fill=(0, 0, 0))
        d.rectangle([cx_s - pw // 2, pyy, cx_s + pw // 2, pyy + ph], fill=rgb(PANEL))

    # ── Walls
    rays = cast(m, px, py, dx, dy, plx, ply)
    base_h = h * WALL_SCALE // 100
    cap = h * WALL_CAP // 100
    lamp_d = []
    for p in range(1, 5):
        dyy = _row(p, 5, horizon)
        lamp_d.append(99.0 if dyy < 1 else base_h / (2.0 * dyy))

    prev_face = None
    prev_drop = None

    def band(x, cwid, ya, yb, col):
        ya, yb = max(0, ya), min(h, yb)
        if yb > ya:
            d.rectangle([x, ya, x + cwid, yb], fill=col)

    def fixture(x, cwid, y0, y1, lh, rail, skirt, wx, key, step):
        kind = key % 17
        if kind == 3:
            if not (0.30 <= wx <= 0.60):
                return
            vh = lh // 9
            if vh < 4:
                return
            vy = rail - vh - lh // 22
            band(x, cwid, vy, vy + vh, ramp(WALL, step + 4))
            band(x, cwid, vy, vy + 1, ramp(WALL, step + 2))
            for s in (1, 2, 3):
                sy = vy + vh * s // 4
                band(x, cwid, sy, sy + 1, ramp(WALL, step + 1))
        elif kind == 7:
            if not (0.46 <= wx <= 0.54):
                return
            oh = lh // 16
            if oh < 3:
                return
            oy = skirt - oh - lh // 40
            band(x, cwid, oy, oy + oh, ramp(WALL, step + 4))
        elif kind == 11:
            if not (0.55 <= wx <= 0.85):
                return
            t = int((wx - 0.55) * 100)
            ph = lh * (30 - t) // 220
            if ph < 3:
                return
            py2 = y0 + lh // 5
            band(x, cwid, py2, py2 + ph, ramp(WALL, step + 5))
            band(x, cwid, py2 + ph, py2 + ph + 1, ramp(WALL, step + 2))
        elif kind == 14:
            if not (0.20 <= wx <= 0.80):
                return
            sh = lh // 20
            if sh < 2:
                return
            band(x, cwid, skirt - sh, skirt, ramp(WALL, step + 2))

    for c, (perp, side, tu, gx, gy) in enumerate(rays):
        if perp >= 55.0:
            prev_face = None
            continue
        x0 = c * w // COLS
        x1 = (c + 1) * w // COLS
        cwid = x1 - x0
        lh = min(int(base_h / perp), cap)
        y0, y1 = horizon - lh // 2, horizon + lh // 2
        step = fog_step(perp) + (1 if side == 1 else 0)
        lamp = False
        if perp < 12.0:
            for D in lamp_d:
                if abs(perp - D) < D / 4 + 0.35:
                    lamp = True
                    break

        face = gx * 961 + gy * 31 + side
        drop = min(int(tu * 3), 2)
        seam = perp < 8.0 and (face != prev_face or drop != prev_drop)
        if perp < 7.0 and ((drop + gx + gy) & 1) == 0:
            step += 1
        if perp < 5.0 and ((gx * 73 + gy * 151 + drop * 29) & 7) == 0:
            step += 1

        body = ramp(WALL, step)
        rail = y0 + lh * 34 // 100
        skirt = y1 - lh // 9
        if lh < 22:
            d.rectangle([x0, max(0, y0), x1, min(h, y1)], fill=body)
        else:
            line_h = max(1, lh // 26)
            for (ya, yb, col) in ((y0, rail, body),
                                  (rail, rail + line_h, ramp(WALL, step + 3)),
                                  (rail + line_h, skirt, ramp(WALL, step + 1)),
                                  (skirt, y1, ramp(WALL, step + 3))):
                ya, yb = max(0, ya), min(h, yb)
                if yb > ya:
                    d.rectangle([x0, ya, x1, yb], fill=col)
            if lamp:
                band(x0, cwid, y0, y0 + lh // 6, ramp(WALL, step - 2))
                band(x0, cwid, y0 + lh // 6, y0 + lh // 3, ramp(WALL, step - 1))
            if perp < 7.0 and skirt - rail > 24:
                bt = min(line_h, 3)
                for b in (1, 2, 3):
                    by = rail + (skirt - rail) * b // 4
                    band(x0, cwid, by, by + bt, ramp(WALL, step + 2))

        if (gx * 7 + gy * 13) % 5 == 0 and 26 < lh < cap:
            st_y, st_h = y0 + lh // 8, lh // 7
            if st_y >= 0 and st_y + st_h <= h:
                d.rectangle([x0, st_y, x1, st_y + st_h], fill=ramp(WALL, step + 1))

        if lh > 30 and perp < 6.0:
            fixture(x0, cwid, y0, y1, lh, rail, skirt, tu,
                    gx * 131 + gy * 47 + side * 7, step)

        if seam:
            d.rectangle([x0, max(0, y0), x0, min(h, y1)], fill=ramp(WALL, step + 2))
        if prev_face is not None and face != prev_face:
            d.rectangle([x0, max(0, y0), x0, min(h, y1)], fill=ramp(WALL, step + 4))
        prev_face = face
        prev_drop = drop

    # ── Billboards: the exit sign, if this camera can see it.
    det = plx * dy - dx * ply
    for (ex, ey, kind) in m.sp:
        sx, sy = ex + 0.5 - px, ey + 0.5 - py
        inv = 1.0 / det
        tx = inv * (dy * sx - dx * sy)
        ty = inv * (-ply * sx + plx * sy)
        if ty < 0.30:
            continue
        scr_x = int((w / 2) * (1.0 + tx / ty))
        col = max(0, min(scr_x * COLS // w, COLS - 1))
        if ty > rays[col][0] + 0.15:
            continue
        size = int(h * 78 / 100 / ty)
        y0 = horizon - size // 2
        dw, dh = max(5, size * 44 // 100), max(7, size * 78 // 100)
        dxx, dyy = scr_x - dw // 2, y0 + size - dh
        jamb = max(1, dw // 7)
        d.rectangle([dxx - jamb, dyy - jamb, dxx + dw + jamb, dyy + dh],
                    fill=rgb(0xAAAA55))
        d.rectangle([dxx, dyy, dxx + dw, dyy + dh], fill=(0, 0, 0))
        d.rectangle([dxx, dyy, dxx + dw, dyy + dh // 14 + 1], fill=rgb(0x555500))
        sw, sh = dw * 76 // 100, max(2, dh // 7)
        sy2 = dyy - jamb - sh - 2
        d.rectangle([scr_x - sw // 2 - 1, sy2 - 1, scr_x + sw // 2 + 1, sy2 + sh + 1],
                    fill=(0, 0, 0))
        d.rectangle([scr_x - sw // 2, sy2, scr_x + sw // 2, sy2 + sh], fill=rgb(0x55FF55))
        if size > 40:
            dither(d, dxx - jamb, y0 + size, dw + jamb * 2, size // 12,
                   rgb(0x55AA55), 2)

    # ── HUD
    try:
        f = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 26)
        fs = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 22)
    except OSError:
        f = fs = ImageFont.load_default()

    tb = d.textbbox((0, 0), level_name, font=f)
    tw2, th2 = tb[2] - tb[0], tb[3] - tb[1]
    ty = int(h * 0.08)
    d.rounded_rectangle([cx_s - tw2 // 2 - 9, ty, cx_s + tw2 // 2 + 9, ty + th2 + 12],
                        radius=6, fill=(0, 0, 0))
    d.text((cx_s, ty + 4), level_name, font=f, fill=rgb(0xFFFF55), anchor="ma")

    bw, bh = int(w * 0.44), 7
    bx, by = cx_s - bw // 2, int(h * 0.79)
    d.rounded_rectangle([bx - 15, by - 5, bx + bw + 15, by + bh + 21],
                        radius=6, fill=(0, 0, 0))
    col = rgb(0xAAFFAA) if sanity >= 45 else (rgb(0xFFFF55) if sanity >= 22 else rgb(0xFF5555))
    d.rectangle([bx - 1, by - 1, bx + bw + 1, by + bh + 1], fill=(0, 0, 0))
    d.rectangle([bx, by, bx + bw * sanity // 100, by + bh], fill=col)
    for n in range(1, 10):
        d.rectangle([bx + bw * n // 10, by, bx + bw * n // 10, by + bh], fill=(0, 0, 0))
    d.rectangle([bx, by + bh + 2, bx + bw, by + bh + 5], fill=(0, 0, 0))
    d.rectangle([bx, by + bh + 2, bx + bw * stam // 100, by + bh + 5], fill=rgb(0x55AAFF))

    # Torch cell, filling from the bottom.
    tx2, th = bx - 12, bh + 5
    d.rectangle([tx2, by, tx2 + 7, by + th], fill=(0, 0, 0))
    d.rectangle([tx2 + 2, by - 2, tx2 + 5, by], fill=rgb(0x555555))
    fill_h = th * torch // 100
    d.rectangle([tx2 + 1, by + th - fill_h, tx2 + 6, by + th],
                fill=rgb(0x00AA00) if torch >= 25 else rgb(0xFFAA00))
    d.rectangle([tx2 - 4, by + th // 2 - 1, tx2 - 1, by + th // 2 + 2], fill=rgb(0xFFFFAA))

    d.text((cx_s, int(h * 0.86)), clock + "   E", font=fs, fill=rgb(0xAAAA55), anchor="ma")

    # Vignette
    for r, pen in ((w // 2 - 2, 10), (w // 2 - 11, 6), (w // 2 - 16, 3)):
        d.ellipse([w // 2 - r, h // 2 - r, w // 2 + r, h // 2 + r], outline=(0, 0, 0), width=pen)

    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, w - 1, h - 1], fill=255)
    out = Image.new("RGB", (w, h), (0, 0, 0))
    out.paste(im, (0, 0), mask)
    return out


def best_view(m):
    """Pick the most photogenic camera in the floor.

    What we want is the iconic shot: a long hall running away from the lens
    with both side walls close enough to converge, and ideally the exit sign at
    the far end. Simply maximising depth finds the middle of a wide room, which
    renders as two flat slabs and no perspective at all.
    """
    import math
    best = None
    for (rx, ry, rw, rh) in m.rooms:
        for cx in range(rx - 3, rx + rw + 3):
            for cy in range(ry - 3, ry + rh + 3):
                if m.is_wall(cx, cy):
                    continue
                for q in range(4):
                    ang = q * 1.5708
                    rays = cast(m, cx + 0.5, cy + 0.5,
                                math.cos(ang), math.sin(ang),
                                -math.sin(ang) * FOV_PLANE,
                                math.cos(ang) * FOV_PLANE, 15)
                    depth = rays[7][0]
                    if not 5.0 < depth < 26.0:
                        continue
                    # Side walls must be near: that is what makes the hall
                    # converge instead of reading as an open box.
                    flanks = (rays[0][0] + rays[1][0] + rays[13][0] + rays[14][0]) / 4.0
                    if flanks > 4.0:
                        continue
                    score = depth * 3.0 - flanks * 2.0
                    # The exit sign at the end of the hall is worth a lot.
                    for (ex, ey, _k) in m.sp:
                        ddx, ddy = ex - cx, ey - cy
                        fwd = ddx * math.cos(ang) + ddy * math.sin(ang)
                        lat = abs(-ddx * math.sin(ang) + ddy * math.cos(ang))
                        if fwd > 2 and lat < 1.5:
                            score += 25.0
                    if best is None or score > best[0]:
                        best = (score, cx + 0.5, cy + 0.5, ang)
    return best


def render_face(seed=12345, level=0):
    """A 454x454 gameplay frame, framed on the most photogenic camera."""
    mp = gen(seed, level)
    b = best_view(mp)
    return render(mp, b[1], b[2], b[3])


if __name__ == "__main__":
    out_path = sys.argv[1] if len(sys.argv) > 1 else "/tmp/backrooms_face.png"
    seed = int(sys.argv[2]) if len(sys.argv) > 2 else 12345
    mp = gen(seed, 0)
    b = best_view(mp)
    face = render(mp, b[1], b[2], b[3])
    face.save(out_path)
    print("wrote", out_path, "cam", b[1], b[2], round(b[3], 2), "score", round(b[0], 1))
