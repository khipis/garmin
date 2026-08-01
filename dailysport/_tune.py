#!/usr/bin/env python3
"""Mirror of the Monkey C shot integrator, used only to tune constants."""
import math

REF_H = 240.0
G = 860.0
K = 0.22
PWR_LO, PWR_HI = 0.46, 1.36
AIM_REF = 52.0


def geom(h, w, dist=0.73, height=0.34):
    floor = h * 0.86
    lx = w * 0.20
    ly = floor - h * 0.30
    rx = w * dist
    ry = floor - h * height
    return lx, ly, rx, ry, floor


def ref_speed(lx, ly, rx, ry, g, ang=AIM_REF):
    dx = rx - lx
    dy = ly - ry  # positive = rim above launch
    a = math.radians(ang)
    den = 2.0 * math.cos(a) ** 2 * (dx * math.tan(a) - dy)
    if den <= 0:
        return None
    v = math.sqrt(g * dx * dx / den)
    t = dx / (v * math.cos(a))
    comp = 1.0 / max(0.65, 1.0 - K * t / 2.0)
    return v * min(1.6, comp)


def fly(lx, ly, ang, v, g, rx, ry, floor, rimw, dt=0.0125):
    a = math.radians(ang)
    x, y = lx, ly
    vx, vy = v * math.cos(a), -v * math.sin(a)
    prev_y = y
    for _ in range(int(6.0 / dt)):
        vx -= vx * K * dt
        vy -= vy * K * dt
        vy += g * dt
        x += vx * dt
        y += vy * dt
        if prev_y < ry <= y and vy > 0:
            off = x - rx
            if abs(off) < rimw / 2.0:
                return ("in", off)
            return ("miss", off)
        prev_y = y
        if y > floor or x > rx + 200:
            return ("miss", x - rx)
    return ("miss", 999)


for h, w in ((240, 240), (416, 416), (208, 208), (280, 280)):
    scale = h / REF_H
    g = G * scale
    lx, ly, rx, ry, floor = geom(h, w)
    rimw = w * 0.155
    v_ref = ref_speed(lx, ly, rx, ry, g)
    print(f"\n== {w}x{h}  vref={v_ref:.0f}px/s  rim width {rimw:.0f}px")
    # meter fraction -> speed
    for m in (0.45, 0.55, 0.58, 0.60, 0.62, 0.66, 0.75):
        v = v_ref * (PWR_LO + m * (PWR_HI - PWR_LO))
        res, off = fly(lx, ly, AIM_REF, v, g, rx, ry, floor, rimw)
        print(f"   angle 52  meter {m:.2f} -> {res:5s} off={off:+.1f}px")
    # angle sensitivity at the sweet meter value
    for ang in (38, 44, 48, 52, 56, 62, 70):
        best = None
        for i in range(0, 101):
            m = i / 100.0
            v = v_ref * (PWR_LO + m * (PWR_HI - PWR_LO))
            res, off = fly(lx, ly, ang, v, g, rx, ry, floor, rimw)
            if res == "in":
                if best is None:
                    best = [m, m]
                else:
                    best[1] = m
        print(f"   angle {ang:3d} -> make window meter {best}")
