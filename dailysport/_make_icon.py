#!/usr/bin/env python3
"""Render dailysport/resources/launcher_icon.png at 1024x1024.

Authored large and left large, the way the other flagship titles ship theirs:
Connect IQ scales the icon down per device (40, 60, 70...), and a downscale
of a clean 1024 master beats an upscale of a 40 px sprite on every screen.

The mark is the game in one glyph — a basketball dropping through a gold
daily ring that has just closed.
"""
import os

from PIL import Image, ImageDraw, ImageFilter

S = 1024
SS = 2                       # supersample, then LANCZOS down
W = S * SS
img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
d = ImageDraw.Draw(img)

cx = cy = W // 2

# ── Backing plate: dark disc so the mark reads on any launcher wallpaper ────
plate_r = int(W * 0.495)
d.ellipse([cx - plate_r, cy - plate_r, cx + plate_r, cy + plate_r],
          fill=(10, 12, 20, 255))
d.ellipse([cx - plate_r, cy - plate_r, cx + plate_r, cy + plate_r],
          outline=(38, 44, 62, 255), width=int(W * 0.012))

# ── Daily ring: gold, with the last arc closed in green ────────────────────
ring_r = int(W * 0.435)
rw = int(W * 0.062)
d.ellipse([cx - ring_r, cy - ring_r, cx + ring_r, cy + ring_r],
          outline=(251, 176, 32, 255), width=rw)
d.arc([cx - ring_r, cy - ring_r, cx + ring_r, cy + ring_r], 196, 344,
      fill=(46, 226, 160, 255), width=rw)

# ── Ball ───────────────────────────────────────────────────────────────────
ball_r = int(W * 0.315)

glow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
ImageDraw.Draw(glow).ellipse(
    [cx - ball_r - 24, cy - ball_r - 24, cx + ball_r + 24, cy + ball_r + 24],
    fill=(255, 110, 20, 130))
img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(int(W * 0.03))))

d.ellipse([cx - ball_r, cy - ball_r, cx + ball_r, cy + ball_r],
          fill=(226, 104, 26, 255))
# Top-left lighting, the way a lit ball actually falls off toward the seam.
hi = Image.new("RGBA", (W, W), (0, 0, 0, 0))
ImageDraw.Draw(hi).ellipse(
    [cx - ball_r, cy - ball_r,
     cx + int(ball_r * 0.35), cy + int(ball_r * 0.15)],
    fill=(255, 158, 62, 230))
img.alpha_composite(hi.filter(ImageFilter.GaussianBlur(int(W * 0.035))))

d = ImageDraw.Draw(img)
lw = int(W * 0.030)
seam = (88, 32, 6, 255)
d.ellipse([cx - ball_r, cy - ball_r, cx + ball_r, cy + ball_r],
          outline=seam, width=int(W * 0.016))
d.line([cx - ball_r, cy, cx + ball_r, cy], fill=seam, width=lw)
d.line([cx, cy - ball_r, cx, cy + ball_r], fill=seam, width=lw)
bow = int(ball_r * 1.5)
off = int(ball_r * 0.62)
d.arc([cx - bow - off, cy - bow, cx + bow - off, cy + bow],
      300, 60, fill=seam, width=lw)
d.arc([cx - bow + off, cy - bow, cx + bow + off, cy + bow],
      120, 240, fill=seam, width=lw)

# Specular pop, so the ball reads as a sphere at 40 px too.
spec = Image.new("RGBA", (W, W), (0, 0, 0, 0))
ImageDraw.Draw(spec).ellipse(
    [cx - int(ball_r * 0.62), cy - int(ball_r * 0.66),
     cx - int(ball_r * 0.22), cy - int(ball_r * 0.30)],
    fill=(255, 224, 170, 190))
img.alpha_composite(spec.filter(ImageFilter.GaussianBlur(int(W * 0.02))))

out = img.resize((S, S), Image.LANCZOS)
path = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                    "resources", "launcher_icon.png")
out.save(path)
print("wrote", path, out.size)
