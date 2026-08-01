#!/usr/bin/env python3
"""Render zombiesurvival/resources/launcher_icon.png at 1024x1024.

Authored large and left large: Connect IQ scales the icon down per device
(40, 60, 70...), and a downscale of a clean 1024 master beats an upscale of a
40 px sprite on every screen.

The mark is the game in one glyph — a toxic-green zombie head lit from behind
by a burning horizon, biting through a crossed plank barricade.
"""
import os

from PIL import Image, ImageDraw, ImageFilter

S = 1024
SS = 2                       # supersample, then LANCZOS down
W = S * SS
img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
cx = cy = W // 2


def blur_layer(draw_fn, radius):
    layer = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(layer))
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(int(W * radius))))


# ── Backing plate ───────────────────────────────────────────────────────────
plate_r = int(W * 0.495)
d.ellipse([cx - plate_r, cy - plate_r, cx + plate_r, cy + plate_r],
          fill=(8, 7, 9, 255))
d.ellipse([cx - plate_r, cy - plate_r, cx + plate_r, cy + plate_r],
          outline=(46, 30, 22, 255), width=int(W * 0.012))

# ── Burning horizon behind the head ─────────────────────────────────────────
plate = Image.new("L", (W, W), 0)
ImageDraw.Draw(plate).ellipse(
    [cx - plate_r, cy - plate_r, cx + plate_r, cy + plate_r], fill=255)

fire = Image.new("RGBA", (W, W), (0, 0, 0, 0))
fd = ImageDraw.Draw(fire)
fd.ellipse([cx - int(W * 0.62), cy + int(W * 0.02),
            cx + int(W * 0.62), cy + int(W * 0.46)], fill=(120, 26, 4, 255))
fd.ellipse([cx - int(W * 0.44), cy + int(W * 0.10),
            cx + int(W * 0.44), cy + int(W * 0.40)], fill=(214, 74, 8, 255))
fd.ellipse([cx - int(W * 0.24), cy + int(W * 0.16),
            cx + int(W * 0.24), cy + int(W * 0.36)], fill=(255, 158, 32, 255))
fire = fire.filter(ImageFilter.GaussianBlur(int(W * 0.035)))
fire.putalpha(Image.composite(fire.getchannel("A"),
                              Image.new("L", (W, W), 0), plate))
img.alpha_composite(fire)

# Skyline teeth standing in front of the glow.
d = ImageDraw.Draw(img)
sky_y = cy + int(W * 0.19)
bx = cx - int(W * 0.44)
for i, bh in enumerate([0.10, 0.16, 0.07, 0.20, 0.12, 0.17, 0.08, 0.14, 0.11]):
    bw = int(W * 0.098)
    d.rectangle([bx, sky_y - int(W * bh), bx + bw - int(W * 0.012), sky_y],
                fill=(6, 5, 7, 255))
    bx += bw

# ── Head ────────────────────────────────────────────────────────────────────
hr = int(W * 0.285)
hy = cy - int(W * 0.055)

blur_layer(lambda dd: dd.ellipse(
    [cx - hr - int(W * 0.05), hy - hr - int(W * 0.05),
     cx + hr + int(W * 0.05), hy + hr + int(W * 0.05)],
    fill=(60, 160, 40, 120)), 0.045)

d = ImageDraw.Draw(img)
d.ellipse([cx - hr, hy - int(hr * 1.06), cx + hr, hy + int(hr * 1.02)],
          fill=(74, 132, 56, 255))
# Moon-side rim, the same trick the in-game sprites use to lift off the street.
d.arc([cx - hr, hy - int(hr * 1.06), cx + hr, hy + int(hr * 1.02)],
      280, 80, fill=(168, 232, 120, 255), width=int(W * 0.020))
# Rotten patches.
d.ellipse([cx - int(hr * 0.78), hy - int(hr * 0.52),
           cx - int(hr * 0.30), hy - int(hr * 0.06)], fill=(52, 96, 38, 255))
d.ellipse([cx + int(hr * 0.24), hy + int(hr * 0.18),
           cx + int(hr * 0.72), hy + int(hr * 0.56)], fill=(52, 96, 38, 255))

# Heavy brow ridge, with the sockets sunk into shadow beneath it.
d.chord([cx - int(hr * 0.94), hy - int(hr * 0.62),
         cx + int(hr * 0.94), hy + int(hr * 0.16)],
        188, 352, fill=(40, 74, 30, 255))
d.rounded_rectangle([cx - int(hr * 0.86), hy - int(hr * 0.60),
                     cx + int(hr * 0.86), hy - int(hr * 0.34)],
                    radius=int(W * 0.014), fill=(96, 158, 70, 255))
for sx in (-1, 1):
    ex = cx + sx * int(hr * 0.40)
    ey = hy - int(hr * 0.20)
    er = int(hr * 0.19)
    blur_layer(lambda dd, ex=ex, ey=ey, er=er: dd.ellipse(
        [ex - er * 2, ey - er * 2, ex + er * 2, ey + er * 2],
        fill=(255, 40, 20, 170)), 0.022)
    d = ImageDraw.Draw(img)
    d.ellipse([ex - er, ey - er, ex + er, ey + er], fill=(255, 42, 24, 255))
    d.ellipse([ex - int(er * 0.42), ey - int(er * 0.46),
               ex + int(er * 0.20), ey + int(er * 0.10)],
              fill=(255, 214, 160, 255))

# Jaw hanging open, teeth showing.
jw, jh = int(hr * 0.62), int(hr * 0.40)
jy = hy + int(hr * 0.44)
d.rounded_rectangle([cx - jw, jy, cx + jw, jy + jh],
                    radius=int(W * 0.018), fill=(20, 14, 14, 255))
tw = (jw * 2) // 5
for i in range(5):
    tx = cx - jw + i * tw
    d.polygon([(tx + 3, jy), (tx + tw - 3, jy),
               (tx + tw // 2, jy + int(jh * (0.52 if i % 2 else 0.74)))],
              fill=(232, 226, 200, 255))
d.rectangle([cx - jw, jy, cx + jw, jy + int(W * 0.010)],
            fill=(120, 22, 14, 255))

# ── Barricade planks crossing the lower third ───────────────────────────────
def plank(p0, p1, thick, light, dark):
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]
    ln = max(1.0, (dx * dx + dy * dy) ** 0.5)
    nx, ny = -dy / ln * thick / 2, dx / ln * thick / 2
    quad = [(p0[0] + nx, p0[1] + ny), (p1[0] + nx, p1[1] + ny),
            (p1[0] - nx, p1[1] - ny), (p0[0] - nx, p0[1] - ny)]
    d.polygon(quad, fill=dark)
    inset = thick * 0.24
    ix, iy = nx * (1 - inset / (thick / 2)), ny * (1 - inset / (thick / 2))
    d.polygon([(p0[0] + ix, p0[1] + iy), (p1[0] + ix, p1[1] + iy),
               (p1[0], p1[1]), (p0[0], p0[1])], fill=light)


d = ImageDraw.Draw(img)
py = cy + int(W * 0.30)
plank((cx - int(W * 0.50), py + int(W * 0.10)),
      (cx + int(W * 0.50), py - int(W * 0.10)),
      int(W * 0.088), (176, 92, 26, 255), (92, 42, 10, 255))
plank((cx - int(W * 0.50), py - int(W * 0.10)),
      (cx + int(W * 0.50), py + int(W * 0.10)),
      int(W * 0.088), (150, 76, 20, 255), (78, 34, 8, 255))

# Clip everything back to the plate.
img.putalpha(Image.composite(img.getchannel("A"),
                             Image.new("L", (W, W), 0), plate))

out = img.resize((S, S), Image.LANCZOS)
path = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                    "resources", "launcher_icon.png")
out.save(path)
print("wrote", path, out.size)
