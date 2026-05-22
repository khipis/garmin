#!/usr/bin/env python3
"""Generate 1440x720 CINEMATIC hero image for Breath Training System (PRO).

Design brief: "BARDZIEJ DOJEBANE"
- Premium coaching-system identity (NOT a tool)
- Cinematic deep-ocean + gold-accent grading
- Telemetry / mission-control aesthetic
- Training state chips (RECOVERY / BUILDING / STABLE / PEAK)
- Next session card, coach badge, PRO crown
- Diver silhouette, god rays, bubble motes, vignette
"""

from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os, math, random

W, H = 1440, 720
OUT = os.path.dirname(os.path.abspath(__file__))
random.seed(11)


def font(size, italic=False):
    candidates = [
        "/System/Library/Fonts/Supplemental/Futura.ttc",
        "/System/Library/Fonts/HelveticaNeue.ttc",
        "/System/Library/Fonts/Helvetica.ttc",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    ]
    for p in candidates:
        if os.path.exists(p):
            try:
                return ImageFont.truetype(p, size)
            except Exception:
                pass
    return ImageFont.load_default()


def lerp(a, b, t):
    return int(a * (1 - t) + b * t)


def mix(c1, c2, t):
    return (lerp(c1[0], c2[0], t), lerp(c1[1], c2[1], t), lerp(c1[2], c2[2], t))


def background():
    # Three-tone cinematic gradient (deep navy -> teal -> black bottom)
    img = Image.new("RGB", (W, H), (0, 0, 0))
    px = img.load()
    top = (6, 30, 55)
    mid = (0, 10, 28)
    bot = (0, 3, 8)
    for y in range(H):
        t = y / H
        if t < 0.5:
            t2 = t / 0.5
            col = mix(top, mid, t2 * t2)
        else:
            t2 = (t - 0.5) / 0.5
            col = mix(mid, bot, t2)
        for x in range(W):
            # subtle horizontal teal tint on center
            dx = abs(x - W / 2) / (W / 2)
            warm = (0, 20, 30)
            tt = (1 - dx) * 0.15 * (1 - abs(y - H / 2) / (H / 2))
            c = (
                max(0, min(255, int(col[0] + warm[0] * tt))),
                max(0, min(255, int(col[1] + warm[1] * tt))),
                max(0, min(255, int(col[2] + warm[2] * tt))),
            )
            px[x, y] = c
    return img


def god_rays(img, count=8):
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    for _ in range(count):
        x = random.randint(-100, W)
        w = random.randint(60, 140)
        col = (160, 230, 255, random.randint(16, 32))
        d.polygon([(x, 0), (x + w, 0), (x + w + 120, H), (x - 60, H)], fill=col)
    overlay = overlay.filter(ImageFilter.GaussianBlur(40))
    return Image.alpha_composite(img.convert("RGBA"), overlay)


def caustics(img):
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    for _ in range(26):
        cx = random.randint(-100, W + 100)
        cy = random.randint(-80, 280)
        rw = random.randint(120, 320)
        rh = random.randint(300, 520)
        col = (120, 220, 255, random.randint(8, 22))
        d.ellipse([cx - rw // 2, cy - rh // 2, cx + rw // 2, cy + rh // 2], fill=col)
    overlay = overlay.filter(ImageFilter.GaussianBlur(80))
    return Image.alpha_composite(img.convert("RGBA"), overlay)


def vignette(img, strength=160):
    v = Image.new("L", img.size, 0)
    vd = ImageDraw.Draw(v)
    cx, cy = img.size[0] // 2, img.size[1] // 2
    maxR = math.sqrt(cx * cx + cy * cy)
    steps = 48
    for i in range(steps, 0, -1):
        r = int(maxR * i / steps)
        a = int(strength * (i / steps) ** 3)
        vd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=255 - a)
    v = v.filter(ImageFilter.GaussianBlur(90))
    black = Image.new("RGB", img.size, (0, 0, 0))
    return Image.composite(img.convert("RGB"), black, v)


def chromatic_text(d, pos, txt, f, base=(255, 255, 255), glow_col=(0, 220, 200), off=2):
    x, y = pos
    # shadow
    d.text((x + 2, y + 3), txt, font=f, fill=(0, 0, 0, 220), anchor="mm")
    # glow offsets
    d.text((x - off, y), txt, font=f, fill=glow_col + (120,), anchor="mm")
    d.text((x + off, y), txt, font=f, fill=(255, 180, 80, 120), anchor="mm")
    d.text((x, y), txt, font=f, fill=base + (255,), anchor="mm")


def diver_silhouette(img, cx, cy, scale=1.0):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    s = scale
    # body
    d.ellipse([cx - 10 * s, cy - 40 * s, cx + 10 * s, cy - 18 * s], fill=(0, 0, 0, 255))  # head
    # torso
    d.polygon([
        (cx - 14 * s, cy - 18 * s), (cx + 14 * s, cy - 18 * s),
        (cx + 10 * s, cy + 30 * s), (cx - 10 * s, cy + 30 * s),
    ], fill=(0, 0, 0, 255))
    # arms stretched forward
    d.polygon([
        (cx - 14 * s, cy - 14 * s), (cx - 70 * s, cy - 8 * s),
        (cx - 72 * s, cy - 2 * s), (cx - 14 * s, cy - 6 * s),
    ], fill=(0, 0, 0, 255))
    d.polygon([
        (cx + 14 * s, cy - 14 * s), (cx + 70 * s, cy - 8 * s),
        (cx + 72 * s, cy - 2 * s), (cx + 14 * s, cy - 6 * s),
    ], fill=(0, 0, 0, 255))
    # legs
    d.polygon([
        (cx - 10 * s, cy + 28 * s), (cx + 10 * s, cy + 28 * s),
        (cx + 14 * s, cy + 80 * s), (cx - 14 * s, cy + 80 * s),
    ], fill=(0, 0, 0, 255))
    # monofin
    d.polygon([
        (cx - 28 * s, cy + 80 * s), (cx + 28 * s, cy + 80 * s),
        (cx + 20 * s, cy + 110 * s), (cx - 20 * s, cy + 110 * s),
    ], fill=(0, 0, 0, 255))
    # faint outline glow
    glow = layer.filter(ImageFilter.GaussianBlur(3))
    tinted = Image.new("RGBA", img.size, (0, 0, 0, 0))
    td = ImageDraw.Draw(tinted)
    td.bitmap((0, 0), layer.split()[3].point(lambda v: v // 3), fill=(0, 220, 255, 40))
    img = Image.alpha_composite(img.convert("RGBA"), tinted)
    img = Image.alpha_composite(img, glow)
    img = Image.alpha_composite(img, layer)
    return img


def ring(d, cx, cy, r, col, w=2):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=col, width=w)


def arc(d, cx, cy, r, a1, a2, col, w=6):
    d.arc([cx - r, cy - r, cx + r, cy + r], a1, a2, fill=col, width=w)


def crown(d, cx, cy, s=26, col=(255, 215, 80)):
    # small crown icon
    d.polygon([
        (cx - s, cy), (cx - s * 0.6, cy - s * 0.7), (cx - s * 0.3, cy - s * 0.3),
        (cx, cy - s), (cx + s * 0.3, cy - s * 0.3), (cx + s * 0.6, cy - s * 0.7),
        (cx + s, cy),
    ], fill=col)
    d.rectangle([cx - s, cy, cx + s, cy + s * 0.35], fill=col)
    # gems
    for gx in [-s * 0.6, 0, s * 0.6]:
        d.ellipse([cx + gx - 3, cy + s * 0.14 - 3, cx + gx + 3, cy + s * 0.14 + 3],
                  fill=(255, 255, 255))


def telemetry_grid(img):
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    # faint grid
    for x in range(0, W, 80):
        d.line([(x, 0), (x, H)], fill=(40, 120, 160, 18), width=1)
    for y in range(0, H, 80):
        d.line([(0, y), (W, y)], fill=(40, 120, 160, 18), width=1)
    # corner data ticks
    for (x, y, tag, val) in [
        (60, 50, "DEPTH", "PRO"),
        (W - 60, 50, "SESSION", "#042"),
        (60, H - 60, "STATE", "STABLE"),
        (W - 60, H - 60, "SYS", "ONLINE"),
    ]:
        d.text((x, y), tag, font=font(12), fill=(0, 180, 200, 160),
               anchor=("lm" if x < W / 2 else "rm"))
        d.text((x, y + 14), val, font=font(14), fill=(255, 210, 100, 200),
               anchor=("lm" if x < W / 2 else "rm"))
    return Image.alpha_composite(img.convert("RGBA"), overlay)


def gen():
    bg = background()
    bg = god_rays(bg, 10)
    bg = caustics(bg)

    # diver silhouette (small, deep)
    bg = diver_silhouette(bg, 200, 540, scale=1.1)
    bg = diver_silhouette(bg, 1260, 250, scale=0.7)

    img = bg.convert("RGBA")
    img = telemetry_grid(img)
    d = ImageDraw.Draw(img, "RGBA")

    # === HERO RING (center) ===
    cx, cy = 720, 290
    # outer decorative halos
    halo = Image.new("RGBA", img.size, (0, 0, 0, 0))
    hd = ImageDraw.Draw(halo)
    for rr, a in [(320, 20), (300, 28), (280, 40)]:
        hd.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=(0, 150, 170, a))
    halo = halo.filter(ImageFilter.GaussianBlur(30))
    img = Image.alpha_composite(img, halo)
    d = ImageDraw.Draw(img, "RGBA")

    for rr, w, col in [(268, 2, (16, 60, 90, 255)), (244, 1, (12, 44, 70, 255)),
                       (218, 1, (10, 34, 54, 255))]:
        ring(d, cx, cy, rr, col, w=w)

    # tick marks
    for i in range(60):
        ang = math.radians(-90 + i * 6)
        r1 = 262 if i % 5 == 0 else 256
        r2 = 246
        x1 = cx + math.cos(ang) * r1
        y1 = cy + math.sin(ang) * r1
        x2 = cx + math.cos(ang) * r2
        y2 = cy + math.sin(ang) * r2
        col = (0, 200, 180, 230) if i % 5 == 0 else (30, 90, 110, 180)
        d.line([(x1, y1), (x2, y2)], fill=col, width=2)

    # primary progress arc with gradient-feel (double stroke)
    arc(d, cx, cy, 236, -120, 100, (0, 80, 90, 255), w=14)
    arc(d, cx, cy, 236, -120, 100, (0, 230, 200, 255), w=8)
    # accent gold tip
    arc(d, cx, cy, 236, 95, 108, (255, 215, 90, 255), w=14)

    # inner second arc
    arc(d, cx, cy, 198, -90, 220, (120, 70, 200, 220), w=5)

    # hero timer
    f_tmr = font(150)
    f_sub = font(22)
    # text with layered glow
    for (ox, oy, col, a) in [(-3, 0, (0, 230, 200), 80), (3, 0, (255, 180, 80), 80)]:
        d.text((cx + ox, cy + oy), "3:02", font=f_tmr, fill=col + (a,), anchor="mm")
    d.text((cx, cy + 3), "3:02", font=f_tmr, fill=(0, 0, 0, 220), anchor="mm")
    d.text((cx, cy), "3:02", font=f_tmr, fill=(255, 255, 255, 255), anchor="mm")

    d.text((cx, cy - 98), "STATIC APNEA", font=font(20), fill=(0, 230, 200, 255), anchor="mm")
    d.text((cx, cy + 80), "PB 3:15  /  +00:12", font=font(20),
           fill=(200, 240, 230, 220), anchor="mm")

    # === LEFT CARD: Breath coach ===
    def card(x, y, w, h, accent):
        c = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        cd = ImageDraw.Draw(c)
        cd.rounded_rectangle([0, 0, w, h], radius=20, fill=(6, 20, 32, 220),
                             outline=accent + (255,), width=2)
        return c

    # left: breath animation (slightly shorter to fit Guide card below)
    bx, by, bw, bh = 80, 168, 260, 228
    c1 = card(bx, by, bw, bh, (0, 200, 240))
    img.paste(c1, (bx, by), c1)
    d = ImageDraw.Draw(img, "RGBA")
    # breathing rings
    ox, oy = bx + bw // 2, by + bh // 2 - 4
    for rr, a in [(88, 28), (72, 50), (58, 80), (44, 115), (30, 155)]:
        ring(d, ox, oy, rr, (0, 200, 240, a), w=3)
    d.ellipse([ox - 24, oy - 24, ox + 24, oy + 24], fill=(0, 90, 130, 255))
    d.ellipse([ox - 24, oy - 24, ox + 24, oy + 24], outline=(0, 220, 255, 255), width=3)
    d.text((ox, oy - 5), "4s", font=font(24), fill=(255, 255, 255, 255), anchor="mm")
    d.text((ox, oy + 16), "INHALE", font=font(13), fill=(170, 220, 255, 230), anchor="mm")
    d.text((bx + bw // 2, by + 20), "BREATHE COACH", font=font(15),
           fill=(0, 200, 240, 255), anchor="mm")
    d.text((bx + bw // 2, by + bh - 34), "Box  /  Wim Hof  /  Pranayama",
           font=font(13), fill=(180, 220, 240, 235), anchor="mm")
    d.text((bx + bw // 2, by + bh - 18), "+ Recovery  /  Breathe-Up",
           font=font(12), fill=(140, 200, 220, 200), anchor="mm")

    # === LEFT BOTTOM CARD: GUIDE / LEGENDA ===
    gx, gy, gw, gh = 80, 384, 260, 104
    cg = card(gx, gy, gw, gh, (80, 200, 120))
    img.paste(cg, (gx, gy), cg)
    d = ImageDraw.Draw(img, "RGBA")
    d.text((gx + gw // 2, gy + 13), "GUIDE  —  More → Guide",
           font=font(12), fill=(80, 220, 130, 255), anchor="mm")
    d.text((gx + gw // 2, gy + 25), "10 sections  /  65 entries  /  scrollable",
           font=font(9), fill=(130, 180, 140, 200), anchor="mm")
    d.line([(gx + 14, gy + 33), (gx + gw - 14, gy + 33)], fill=(50, 140, 80, 180), width=1)
    guide_lines = [
        ("NAV", "SELECT start  UP/DN scroll  BACK exit"),
        ("MODES", "BR · CO2 · O2 · AP · Readiness Check"),
        ("STATS", "Training · Progression · Physiology · Weekly · Sensor Trends"),
        ("PRO++", "CO2 tolerance · O2 adaptation · PB prediction · patterns"),
        ("SENSORS", "live HR delta · Body Battery · SpO2 · Stress · RHR"),
        ("REF", "all symbols: ^ v ~ ! *  +  acronym glossary"),
    ]
    for gi, (lbl, desc) in enumerate(guide_lines):
        y_ = gy + 43 + gi * 11
        d.text((gx + 16, y_), lbl, font=font(9), fill=(80, 220, 130, 230), anchor="lm")
        d.text((gx + 52, y_), desc, font=font(9), fill=(195, 220, 205, 210), anchor="lm")

    # === RIGHT TOP CARD: SENSOR HUB (PRO++ v5) — compact ===
    rx, ry, rw, rh = 1090, 155, 268, 138
    c2 = card(rx, ry, rw, rh, (160, 100, 255))
    img.paste(c2, (rx, ry), c2)
    d = ImageDraw.Draw(img, "RGBA")
    d.text((rx + rw // 2, ry + 18), "SENSOR HUB", font=font(14),
           fill=(160, 100, 255, 255), anchor="mm")
    # HR row
    hry = ry + 44
    d.ellipse([rx + 18, hry - 6, rx + 30, hry + 6], fill=(255, 60, 80, 255))
    d.text((rx + 38, hry), "HR", font=font(12), fill=(200, 200, 220, 210), anchor="lm")
    d.text((rx + rw - 14, hry), "58 bpm", font=font(17), fill=(255, 255, 255, 255), anchor="rm")
    d.text((rx + rw - 12, hry + 17), "dive -11 bpm", font=font(11), fill=(0, 230, 200, 210), anchor="rm")
    # separator
    d.line([(rx + 14, ry + 80), (rx + rw - 14, ry + 80)], fill=(80, 60, 120, 180), width=1)
    # 4 mini chips: BB / SpO2 / Stress / RHR
    chips = [("BB", "82%", (0, 220, 120)), ("O2", "97%", (80, 180, 255)),
             ("STR", "24", (255, 200, 60)), ("RHR", "52", (200, 130, 255))]
    chipW = rw // 4
    for ci, (lbl, val, col) in enumerate(chips):
        cx_ = rx + ci * chipW + chipW // 2
        d.text((cx_, ry + 95), lbl, font=font(10), fill=(160, 170, 190, 200), anchor="mm")
        d.text((cx_, ry + 115), val, font=font(13), fill=col + (255,), anchor="mm")

    # === RIGHT BOTTOM CARD: PHYSIOLOGY (PRO++) ===
    px2, py2, pw2, ph2 = 1090, 308, 268, 192
    c3 = card(px2, py2, pw2, ph2, (255, 200, 60))
    img.paste(c3, (px2, py2), c3)
    d = ImageDraw.Draw(img, "RGBA")
    d.text((px2 + pw2 // 2, py2 + 20), "PHYSIOLOGY", font=font(14),
           fill=(255, 200, 60, 255), anchor="mm")
    rows = [
        ("CO2", [38, 52, 60, 68, 72], 72, (0, 230, 200), "^"),
        ("O2",  [44, 50, 58, 56, 62], 62, (255, 200, 60), "^"),
        ("REC", [70, 65, 58, 52, 45], 45, (255, 110, 70), "v"),
    ]
    rrowY0 = py2 + 46
    rrowH = 44
    for ri, (lbl, hist, val, col, arr) in enumerate(rows):
        ry_ = rrowY0 + ri * rrowH
        d.text((px2 + 20, ry_ + 10), lbl, font=font(13), fill=(220, 230, 240, 255), anchor="lm")
        hbx = px2 + 72
        hbW = 120
        hbH = 24
        bcount = 5
        sp = 3
        bw_ = (hbW - sp * (bcount - 1)) // bcount
        d.line([(hbx, ry_ + 22), (hbx + hbW, ry_ + 22)], fill=(40, 80, 100, 200), width=1)
        for bi, v in enumerate(hist):
            bH = max(2, int(v * hbH / 100))
            bx_ = hbx + bi * (bw_ + sp)
            barCol = col if bi == bcount - 1 else (90, 120, 140, 230)
            d.rectangle([bx_, ry_ + 22 - bH, bx_ + bw_, ry_ + 22], fill=barCol)
        d.text((px2 + pw2 - 14, ry_ + 10), arr + str(val), font=font(13),
               fill=col + (255,), anchor="rm")
    d.text((px2 + pw2 // 2, py2 + ph2 - 18), "CO2 DOMINANT  •  PLATEAU DETECTION",
           font=font(10), fill=(0, 230, 200, 220), anchor="mm")

    # === STATE CHIPS BAR ===
    states = [
        ("RECOVERY", (80, 180, 220)),
        ("BUILDING", (0, 230, 160)),
        ("STABLE",   (180, 200, 80)),
        ("PEAK",     (255, 180, 60)),
    ]
    by_ = 490
    cw, ch = 220, 48
    total = len(states) * cw + (len(states) - 1) * 20
    x0 = (W - total) // 2
    for i, (name, col) in enumerate(states):
        x = x0 + i * (cw + 20)
        # glow
        glow = Image.new("RGBA", (cw + 50, ch + 50), (0, 0, 0, 0))
        gd = ImageDraw.Draw(glow)
        gd.rounded_rectangle([10, 10, cw + 40, ch + 40], radius=14,
                             fill=col + (45,))
        glow = glow.filter(ImageFilter.GaussianBlur(14))
        img.alpha_composite(glow, (x - 25, by_ - 25))
        d = ImageDraw.Draw(img, "RGBA")
        active = (i == 2)  # highlight STABLE
        d.rounded_rectangle([x, by_, x + cw, by_ + ch], radius=12,
                            fill=(6, 14, 22, 240) if not active else (16, 30, 40, 255),
                            outline=col + (255,), width=2 if not active else 3)
        d.ellipse([x + 16, by_ + ch // 2 - 5, x + 26, by_ + ch // 2 + 5], fill=col + (255,))
        d.text((x + cw // 2 + 10, by_ + ch // 2), name, font=font(18),
               fill=col + (255,), anchor="mm")

    # chevron arrows between states
    for i in range(len(states) - 1):
        x = x0 + i * (cw + 20) + cw + 10
        d.polygon([(x - 3, by_ + ch // 2 - 6), (x + 7, by_ + ch // 2),
                   (x - 3, by_ + ch // 2 + 6)], fill=(100, 180, 200, 200))

    # === TOP BADGES ===
    # PRO++ crown badge (top-right)
    px, py = W - 200, 44
    d.rounded_rectangle([px, py, px + 180, py + 50], radius=12,
                        fill=(255, 200, 60, 245),
                        outline=(220, 160, 0, 255), width=2)
    crown(d, px + 28, py + 25, s=14)
    d.text((px + 110, py + 25), "PRO++", font=font(26),
           fill=(24, 18, 0, 255), anchor="mm")
    # AI Coach pill below the crown
    d.rounded_rectangle([px + 14, py + 56, px + 166, py + 84], radius=10,
                        fill=(0, 60, 80, 230),
                        outline=(0, 230, 200, 255), width=2)
    d.text((px + 90, py + 70), "AI COACH", font=font(15),
           fill=(0, 230, 200, 255), anchor="mm")
    # v5.3 / Guide badge
    d.rounded_rectangle([px + 14, py + 90, px + 166, py + 114], radius=10,
                        fill=(20, 10, 40, 230),
                        outline=(160, 100, 255, 255), width=2)
    d.text((px + 90, py + 102), "v5.3  GUIDE  SENSOR HUB", font=font(11),
           fill=(160, 100, 255, 255), anchor="mm")

    # Top-center feature ribbon
    feats = "8 PATHS  ·  SENSOR HUB  ·  PHYSIOLOGY  ·  PB PREDICTOR  ·  GUIDE"
    fy = 38
    fw = 880
    fx = (W - fw) // 2
    d.rounded_rectangle([fx, fy, fx + fw, fy + 38], radius=18,
                        fill=(6, 22, 36, 220),
                        outline=(0, 200, 180, 200), width=1)
    d.text((W // 2, fy + 19), feats, font=font(16),
           fill=(180, 230, 230, 255), anchor="mm")

    # FTS emblem (top-left)
    ex, ey = 80, 70
    d.ellipse([ex - 34, ey - 34, ex + 34, ey + 34],
              outline=(0, 230, 200, 255), width=3)
    d.ellipse([ex - 26, ey - 26, ex + 26, ey + 26],
              outline=(0, 230, 200, 140), width=2)
    d.text((ex, ey), "BTS", font=font(20), fill=(255, 255, 255, 255), anchor="mm")

    # === BUBBLES ===
    bubbles = [
        (130, 120, 4, 180), (190, 60, 3, 150), (260, 520, 3, 120),
        (1260, 130, 5, 180), (1340, 80, 3, 150), (1180, 480, 4, 140),
        (420, 40, 4, 150), (1000, 50, 3, 140), (360, 620, 3, 110),
        (1080, 600, 3, 140), (60, 260, 2, 100), (1400, 320, 2, 100),
        (700, 640, 3, 120),
    ]
    bubs = Image.new("RGBA", img.size, (0, 0, 0, 0))
    bd = ImageDraw.Draw(bubs)
    for bx_, by__, br, a in bubbles:
        bd.ellipse([bx_ - br, by__ - br, bx_ + br, by__ + br],
                   outline=(140, 220, 255, a), width=2)
        bd.ellipse([bx_ - br // 2, by__ - br // 2, bx_ - br // 4, by__ - br // 4],
                   fill=(220, 245, 255, min(a + 40, 255)))
    img = Image.alpha_composite(img, bubs)
    d = ImageDraw.Draw(img, "RGBA")

    # === BOTTOM GLASS BAR ===
    barH = 140
    barY = H - barH
    bar = Image.new("RGBA", (W, barH), (0, 0, 0, 230))
    bd = ImageDraw.Draw(bar)
    for y in range(barH):
        t = y / barH
        a = int(230 + 20 * t)
        bd.line([(0, y), (W, y)], fill=(0, 4, 10, a))
    img.alpha_composite(bar, (0, barY))
    d = ImageDraw.Draw(img, "RGBA")

    # triple accent lines
    for i, (off, alpha) in enumerate([(0, 255), (-4, 120), (-8, 60)]):
        for x in range(W):
            t = x / W
            col = mix((0, 150, 200), (0, 230, 200), t)
            gold = (255, 215, 90)
            col = mix(col, gold, max(0, t - 0.7) / 0.3) if t > 0.7 else col
            d.line([(x, barY + off), (x, barY + off + 2)], fill=col + (alpha,))

    # title
    f_title = font(68)
    f_sub = font(24)
    title = "BREATH TRAINING SYSTEM"
    chromatic_text(d, (W // 2, barY + 46), title, f_title,
                   base=(255, 255, 255), glow_col=(0, 230, 200))
    d.text((W // 2, barY + 96), "Predictive Coaching  ·  Sensor Hub (HR/SpO2/BB/Stress)  ·  Pattern AI  ·  8 Paths  ·  In-App Guide",
           font=f_sub, fill=(255, 215, 90, 230), anchor="mm")

    # corner tick marks
    tk = 26
    for (x, y) in [(30, 30), (W - 30, 30), (30, H - 30), (W - 30, H - 30)]:
        d.line([(x - tk, y), (x + tk, y)], fill=(255, 215, 90, 220), width=2)
        d.line([(x, y - tk), (x, y + tk)], fill=(255, 215, 90, 220), width=2)

    # === FINAL FX ===
    final = vignette(img.convert("RGB"), strength=140)
    # soft bloom on highlights
    bloom = final.filter(ImageFilter.GaussianBlur(6))
    final = Image.blend(final, bloom, 0.12)

    out = os.path.join(OUT, "breathtrainingsystem_hero.png")
    final.save(out, "PNG", optimize=True)
    print(f"  -> {out}")


if __name__ == "__main__":
    print("Generating breathtrainingsystem CINEMATIC hero image...")
    gen()
    print("Done!")
