#!/usr/bin/env python3
"""Angry Pomodoro launcher icon: angry red tomato face on dark background."""
from PIL import Image, ImageDraw
import os, math

DEST_APP = os.path.join(os.path.dirname(__file__),
                        "../../angrypomodoro/resources/launcher_icon.png")
DEST_ICON = os.path.join(os.path.dirname(__file__), "store_icon.png")
DEST_HERO = os.path.join(os.path.dirname(__file__), "angrypomodoro_hero.png")


def draw_icon(draw, cx, cy, r, angry=True):
    """Draw a tomato face. angry=True → red/angry, False → yellow/neutral."""
    head_color = (220, 50, 20) if angry else (255, 200, 40)
    outline    = (140, 20,  0) if angry else (180, 130, 0)
    draw.ellipse([cx-r, cy-r, cx+r, cy+r], fill=head_color, outline=outline, width=max(1, r//12))

    # Green leaf on top
    lw = max(2, r//5)
    draw.polygon([(cx-lw, cy-r+2), (cx-lw*2, cy-r-lw*2), (cx+2, cy-r-2)], fill=(50, 160, 30))
    draw.polygon([(cx+lw, cy-r+2), (cx+lw*2, cy-r-lw*2), (cx-2, cy-r-2)], fill=(50, 160, 30))

    eo  = r * 28 // 100
    eyy = cy - r * 10 // 100
    eyr = max(2, r * 13 // 100)

    if angry:
        # V eyebrows
        bw = max(2, eyr // 2)
        draw.polygon([(cx-eo-eyr-3, eyy-eyr-7), (cx-eo+eyr+1, eyy-eyr-2),
                      (cx-eo+eyr+1, eyy-eyr+2), (cx-eo-eyr-3, eyy-eyr-3)],
                     fill=(10, 0, 0))
        draw.polygon([(cx+eo-eyr-1, eyy-eyr-2), (cx+eo+eyr+3, eyy-eyr-7),
                      (cx+eo+eyr+3, eyy-eyr-3), (cx+eo-eyr-1, eyy-eyr+2)],
                     fill=(10, 0, 0))
        # Red pupils
        draw.ellipse([cx-eo-eyr, eyy-eyr, cx-eo+eyr, eyy+eyr], fill=(10, 0, 0))
        draw.ellipse([cx+eo-eyr, eyy-eyr, cx+eo+eyr, eyy+eyr], fill=(10, 0, 0))
        draw.ellipse([cx-eo-eyr*6//10, eyy-eyr*6//10, cx-eo+eyr*6//10, eyy+eyr*6//10], fill=(220, 10, 0))
        draw.ellipse([cx+eo-eyr*6//10, eyy-eyr*6//10, cx+eo+eyr*6//10, eyy+eyr*6//10], fill=(220, 10, 0))
        # Gritted mouth
        mw = r * 55 // 100; mh = max(4, r * 22 // 100); my = cy + r * 28 // 100
        draw.rectangle([cx-mw, my, cx+mw, my+mh], fill=(10, 0, 0))
        tw = mw * 2 // 3
        for i in range(3):
            draw.rectangle([cx-mw+i*tw+2, my+1, cx-mw+i*tw+tw-2, my+mh*55//100], fill=(255, 255, 255))
        # Steam puffs
        draw.ellipse([cx-r//5-3, cy-r-r//5-3, cx-r//5+3, cy-r-r//5+3], fill=(255, 130, 80))
        draw.ellipse([cx+r//5-2, cy-r-r//6-2, cx+r//5+2, cy-r-r//6+2], fill=(255, 150, 100))
    else:
        draw.ellipse([cx-eo-eyr, eyy-eyr, cx-eo+eyr, eyy+eyr], fill=(30, 20, 20))
        draw.ellipse([cx+eo-eyr, eyy-eyr, cx+eo+eyr, eyy+eyr], fill=(30, 20, 20))
        draw.ellipse([cx-eo+1, eyy-3, cx-eo+eyr//2+1, eyy+eyr//2-3], fill=(255, 255, 255))
        draw.ellipse([cx+eo+1, eyy-3, cx+eo+eyr//2+1, eyy+eyr//2-3], fill=(255, 255, 255))
        mw = r * 20 // 100; my = cy + r * 28 // 100
        draw.rectangle([cx-mw, my, cx+mw, my+3], fill=(120, 60, 0))


# ── 40×40 launcher icon ─────────────────────────────────────────────────────
img = Image.new("RGBA", (40, 40), (0, 0, 0, 0))
d   = ImageDraw.Draw(img)
draw_icon(d, 20, 21, 17, angry=True)
img.save(DEST_APP)
print(f"Saved launcher icon → {DEST_APP}")

# ── 200×200 store icon ───────────────────────────────────────────────────────
si = Image.new("RGBA", (200, 200), (12, 8, 20, 255))
sd = ImageDraw.Draw(si)
# Subtle background glow
sd.ellipse([20, 20, 180, 180], fill=(40, 5, 5, 200))
draw_icon(sd, 100, 105, 82, angry=True)
si.save(DEST_ICON)
print(f"Saved store icon   → {DEST_ICON}")

# ── 1440×720 hero image ──────────────────────────────────────────────────────
hero = Image.new("RGB", (1440, 720), (8, 5, 14))
hd   = ImageDraw.Draw(hero)
# Red gradient band
for y in range(720):
    alpha = max(0, 1.0 - abs(y - 360) / 360.0)
    c = int(30 * alpha)
    hd.rectangle([0, y, 1439, y], fill=(c + 5, 0, 0))
# Left angry face (large)
draw_icon(hd, 340, 370, 220, angry=True)
# Right neutral/calmer face
draw_icon(hd, 1100, 370, 180, angry=False)
# Title text area placeholder
hd.rectangle([530, 240, 910, 490], fill=(10, 6, 18))
hd.rectangle([534, 244, 906, 486], outline=(180, 40, 0), width=3, fill=(10, 6, 18))
hero.save(DEST_HERO)
print(f"Saved hero image   → {DEST_HERO}")
