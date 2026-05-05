#!/usr/bin/env python3
"""Generate 1440x720 PREMIUM hero image for Breath Training Tool (LITE).

Design brief: "DOJEBANE"
- Deep ocean atmosphere with light caustics
- Bold watchface composition: timer + breath rings + depth scale
- Strong typography: brand mark + tagline
- Rich color grading (teal / cyan / amber highlights)
- Layered glows, particles, vignette for cinematic feel.
"""

from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os, math, random

W, H = 1440, 720
OUT = os.path.dirname(os.path.abspath(__file__))

random.seed(7)


def font(size, bold=True):
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


def radial_gradient(size, inner, outer, cx=None, cy=None, stretch=1.0):
    w, h = size
    if cx is None:
        cx = w / 2
    if cy is None:
        cy = h / 2
    img = Image.new("RGB", size, outer)
    px = img.load()
    maxR = math.sqrt((w * 0.7) ** 2 + (h * 0.7 * stretch) ** 2)
    for y in range(h):
        for x in range(w):
            dx = x - cx
            dy = (y - cy) * stretch
            r = math.sqrt(dx * dx + dy * dy) / maxR
            if r > 1:
                r = 1
            t = r * r
            px[x, y] = mix(inner, outer, t)
    return img


def add_caustics(img, count=18):
    """Soft light rays + shimmer."""
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    for _ in range(count):
        cx = random.randint(-200, W + 200)
        cy = random.randint(-100, 250)
        w = random.randint(120, 380)
        h = random.randint(400, 700)
        col = (120, 220, 255, random.randint(8, 22))
        d.ellipse([cx - w // 2, cy - h // 2, cx + w // 2, cy + h // 2], fill=col)
    overlay = overlay.filter(ImageFilter.GaussianBlur(60))
    return Image.alpha_composite(img.convert("RGBA"), overlay)


def god_rays(img):
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    for i in range(6):
        x = 250 + i * 180 + random.randint(-20, 20)
        w = random.randint(40, 90)
        col = (150, 230, 255, 18)
        d.polygon([(x, 0), (x + w, 0), (x + w + 80, H), (x - 40, H)], fill=col)
    overlay = overlay.filter(ImageFilter.GaussianBlur(28))
    return Image.alpha_composite(img.convert("RGBA"), overlay)


def vignette(img, strength=180):
    v = Image.new("L", img.size, 0)
    vd = ImageDraw.Draw(v)
    cx, cy = img.size[0] // 2, img.size[1] // 2
    maxR = math.sqrt(cx * cx + cy * cy)
    steps = 40
    for i in range(steps, 0, -1):
        r = int(maxR * i / steps)
        a = int(strength * (i / steps) ** 3)
        vd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=255 - a)
    v = v.filter(ImageFilter.GaussianBlur(80))
    black = Image.new("RGB", img.size, (0, 0, 0))
    return Image.composite(img.convert("RGB"), black, v)


def draw_ring(d, cx, cy, r, color, width=2):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=color, width=width)


def draw_arc(d, cx, cy, r, start, end, color, width=6):
    d.arc([cx - r, cy - r, cx + r, cy + r], start, end, fill=color, width=width)


def draw_breath_rings(base, cx, cy):
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for k, (r, a) in enumerate([(210, 30), (175, 55), (140, 85), (108, 120), (78, 180)]):
        col = (0, 200 + k * 10, 240, a)
        draw_ring(d, cx, cy, r, col, width=3)
    d.ellipse([cx - 56, cy - 56, cx + 56, cy + 56], fill=(0, 90, 130, 255))
    d.ellipse([cx - 56, cy - 56, cx + 56, cy + 56], outline=(0, 220, 255, 255), width=3)
    glow = layer.filter(ImageFilter.GaussianBlur(4))
    base = Image.alpha_composite(base.convert("RGBA"), glow)
    base = Image.alpha_composite(base.convert("RGBA"), layer)
    return base


def draw_bubbles(d, bubbles):
    for bx, by, br, a in bubbles:
        d.ellipse([bx - br, by - br, bx + br, by + br], outline=(140, 220, 255, a), width=2)
        # highlight
        d.ellipse([bx - br // 2 - 1, by - br // 2 - 1, bx - br // 4, by - br // 4], fill=(220, 245, 255, min(a + 40, 255)))


def gen():
    bg = radial_gradient((W, H), (8, 40, 70), (0, 4, 14), cy=220, stretch=1.2)
    bg = god_rays(bg)
    bg = add_caustics(bg, 22)
    bg = bg.convert("RGB")

    img = bg.copy().convert("RGBA")
    d = ImageDraw.Draw(img, "RGBA")

    # --- LEFT: breathing orb ---
    bcx, bcy = 300, 320
    img = draw_breath_rings(img, bcx, bcy)
    d = ImageDraw.Draw(img, "RGBA")
    f_mode = font(22)
    f_val = font(42)
    d.text((bcx, bcy - 12), "4s", font=f_val, fill=(255, 255, 255, 255), anchor="mm")
    d.text((bcx, bcy + 22), "INHALE", font=f_mode, fill=(170, 220, 255, 230), anchor="mm")

    # --- CENTER: hero timer ---
    tcx, tcy = 720, 300
    # outer decorative rings
    for rr, w, col in [(248, 2, (20, 70, 100, 255)), (226, 1, (14, 50, 80, 255)), (200, 1, (10, 36, 60, 255))]:
        draw_ring(d, tcx, tcy, rr, col, width=w)

    # big progress arc
    draw_arc(d, tcx, tcy, 220, -120, 130, (0, 230, 200, 255), width=10)
    # accent tip
    d.arc([tcx - 220, tcy - 220, tcx + 220, tcy + 220], 125, 132, fill=(255, 220, 80, 255), width=12)

    # tick marks
    for i in range(60):
        ang = math.radians(-90 + i * 6)
        r1 = 244 if i % 5 == 0 else 238
        r2 = 228
        x1 = tcx + math.cos(ang) * r1
        y1 = tcy + math.sin(ang) * r1
        x2 = tcx + math.cos(ang) * r2
        y2 = tcy + math.sin(ang) * r2
        col = (0, 200, 180, 230) if i % 5 == 0 else (20, 100, 120, 180)
        d.line([(x1, y1), (x2, y2)], fill=col, width=2)

    # hero timer text
    f_tmr = font(140)
    f_lbl = font(26)
    d.text((tcx, tcy - 8), "2:47", font=f_tmr, fill=(255, 255, 255, 255), anchor="mm")
    d.text((tcx, tcy - 90), "HOLD", font=f_lbl, fill=(0, 230, 200, 255), anchor="mm")
    d.text((tcx, tcy + 70), "PB 3:15", font=font(22), fill=(120, 180, 200, 255), anchor="mm")

    # --- RIGHT: CO2 table card ---
    rcx, rcy = 1140, 320
    # card background
    card = Image.new("RGBA", (300, 300), (0, 0, 0, 0))
    cd = ImageDraw.Draw(card)
    cd.rounded_rectangle([0, 0, 300, 300], radius=22, fill=(8, 24, 36, 210), outline=(0, 200, 180, 255), width=2)
    card = card.filter(ImageFilter.GaussianBlur(0))
    img.paste(card, (rcx - 150, rcy - 150), card)
    d = ImageDraw.Draw(img, "RGBA")

    d.text((rcx, rcy - 120), "CO2 TABLE", font=font(20), fill=(0, 230, 200, 255), anchor="mm")
    # mini arc
    draw_ring(d, rcx, rcy + 6, 88, (20, 70, 90, 255), width=2)
    draw_arc(d, rcx, rcy + 6, 88, -90, 140, (255, 200, 60, 255), width=6)
    d.text((rcx, rcy + 6 - 22), "HOLD", font=font(16), fill=(180, 220, 230, 230), anchor="mm")
    d.text((rcx, rcy + 6 + 8), "0:48", font=font(44), fill=(255, 255, 255, 255), anchor="mm")
    d.text((rcx, rcy + 6 + 46), "Round 4 / 8", font=font(16), fill=(120, 170, 180, 255), anchor="mm")

    # --- MODE BADGES bottom band ---
    modes = [
        ("BREATHE", (0, 200, 240)),
        ("STATIC APNEA", (40, 220, 120)),
        ("CO2 TABLE", (0, 230, 200)),
        ("O2 TABLE", (180, 120, 255)),
    ]
    by = 508
    bw, bh = 270, 64
    total = len(modes) * bw + (len(modes) - 1) * 22
    x0 = (W - total) // 2
    for i, (m, c) in enumerate(modes):
        x = x0 + i * (bw + 22)
        # glow
        glow = Image.new("RGBA", (bw + 60, bh + 60), (0, 0, 0, 0))
        gd = ImageDraw.Draw(glow)
        gd.rounded_rectangle([12, 12, bw + 48, bh + 48], radius=16, fill=(c[0], c[1], c[2], 55))
        glow = glow.filter(ImageFilter.GaussianBlur(14))
        img.alpha_composite(glow, (x - 30, by - 30))
        d = ImageDraw.Draw(img, "RGBA")
        d.rounded_rectangle([x, by, x + bw, by + bh], radius=14, fill=(6, 14, 22, 230), outline=c + (255,), width=2)
        d.text((x + bw // 2, by + bh // 2), m, font=font(24), fill=c + (255,), anchor="mm")

    # --- BUBBLES ---
    bubbles = [
        (80, 180, 5, 180), (120, 80, 4, 150), (200, 440, 3, 130),
        (1320, 150, 5, 180), (1360, 90, 3, 150), (1280, 500, 4, 140),
        (520, 50, 4, 150), (900, 60, 3, 140), (380, 500, 3, 120),
        (1000, 500, 4, 140), (260, 240, 2, 100), (1160, 200, 2, 100),
    ]
    bubs = Image.new("RGBA", img.size, (0, 0, 0, 0))
    bd = ImageDraw.Draw(bubs)
    draw_bubbles(bd, bubbles)
    img = Image.alpha_composite(img, bubs)
    d = ImageDraw.Draw(img, "RGBA")

    # --- TITLE BAR ---
    barH = 120
    barY = H - barH
    # glass bar
    bar = Image.new("RGBA", (W, barH), (0, 0, 0, 220))
    bd = ImageDraw.Draw(bar)
    for y in range(barH):
        t = y / barH
        a = int(230 + 20 * t)
        bd.line([(0, y), (W, y)], fill=(0, 4, 10, a))
    img.alpha_composite(bar, (0, barY))
    d = ImageDraw.Draw(img, "RGBA")

    # accent line with gradient
    for x in range(W):
        t = x / W
        col = mix((0, 150, 200), (0, 230, 200), t)
        d.line([(x, barY - 2), (x, barY + 1)], fill=col + (255,))

    # brand
    title_f = font(58)
    sub_f = font(22)
    title = "BREATH TRAINING TOOL"
    # shadow
    d.text((W // 2 + 2, barY + 28 + 2), title, font=title_f, fill=(0, 0, 0, 220), anchor="mm")
    d.text((W // 2, barY + 28), title, font=title_f, fill=(255, 255, 255, 255), anchor="mm")
    d.text((W // 2, barY + 74), "Instant breath training  /  Breathe  /  Apnea  /  CO2  /  O2",
           font=sub_f, fill=(0, 230, 200, 230), anchor="mm")

    # small LITE badge top-right
    lx, ly = W - 110, 40
    d.rounded_rectangle([lx, ly, lx + 90, ly + 34], radius=8, fill=(255, 200, 60, 240))
    d.text((lx + 45, ly + 17), "LITE", font=font(20), fill=(20, 12, 0, 255), anchor="mm")

    # corner tick marks for cinematic framing
    tk = 24
    for (x, y) in [(30, 30), (W - 30, 30), (30, H - 30), (W - 30, H - 30)]:
        d.line([(x - tk, y), (x + tk, y)], fill=(0, 230, 200, 200), width=2)
        d.line([(x, y - tk), (x, y + tk)], fill=(0, 230, 200, 200), width=2)

    # final vignette
    final = vignette(img.convert("RGB"), strength=120)
    out = os.path.join(OUT, "breathtrainingtool_hero.png")
    final.save(out, "PNG", optimize=True)
    print(f"  -> {out}")


if __name__ == "__main__":
    print("Generating breathtrainingtool PREMIUM hero image...")
    gen()
    print("Done!")
