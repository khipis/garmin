#!/usr/bin/env python3
"""Generates a 40x40 launcher icon for DiceRoyale.

Style: gold/amber dice cube on dark background, showing the '5' face,
clean and bold so it reads at watch-launcher sizes.
"""

from PIL import Image, ImageDraw

SIZE = 40
img = Image.new('RGBA', (SIZE, SIZE), (8, 12, 28, 255))
d = ImageDraw.Draw(img)

# Subtle vignette ring (inner background).
d.ellipse((1, 1, SIZE - 2, SIZE - 2), fill=(14, 22, 40, 255))

# Dice body — amber square with rounded corners.
pad = 5
d.rounded_rectangle((pad, pad, SIZE - pad - 1, SIZE - pad - 1),
                    radius=5, fill=(255, 204, 68, 255),
                    outline=(255, 160, 32, 255), width=1)

# Pips for "5" face.
pip_color = (24, 16, 0, 255)
r = 2
cx, cy = SIZE / 2, SIZE / 2
# 3x3 grid coords inside the die.
left   = pad + 5
right  = SIZE - pad - 6
mid_x  = SIZE / 2
top    = pad + 5
bottom = SIZE - pad - 6
mid_y  = SIZE / 2

pips = [(left, top), (right, top), (mid_x, mid_y), (left, bottom), (right, bottom)]
for (px, py) in pips:
    d.ellipse((px - r, py - r, px + r, py + r), fill=pip_color)

img.save("/Users/kkorolczuk/work/garmin/diceroyale/resources/launcher_icon.png", "PNG")
print("ok")
