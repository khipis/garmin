#!/usr/bin/env python3
"""40x40 launcher icon: rolling ball in a maze corner."""
from PIL import Image, ImageDraw

S = 40
img = Image.new('RGBA', (S, S), (5, 8, 15, 255))
d = ImageDraw.Draw(img)
d.ellipse((1, 1, S-2, S-2), fill=(10, 16, 28, 255))

# Mini L-shaped maze walls (dark teal)
WC = (30, 80, 100, 255)
FC = (220, 240, 235, 255)
# Floor
d.rectangle((6, 6, S-7, S-7), fill=FC)
# Walls
d.rectangle((6, 6, 14, 26), fill=WC)     # left wall with gap
d.rectangle((6, 20, 26, 26), fill=WC)    # horizontal wall
d.rectangle((20, 20, 26, S-7), fill=WC)  # right segment
d.rectangle((6, S-14, 20, S-7), fill=WC) # bottom horizontal
# Ball (red)
d.ellipse((28, 8, S-5, S-19), fill=(220, 60, 60, 255), outline=(180, 30, 30, 255))
# Ball highlight
d.ellipse((30, 10, 34, 14), fill=(255, 160, 150, 255))
# Exit marker
d.rectangle((S-14, S-14, S-7, S-7), fill=(0, 200, 100, 255))

img.save("/Users/kkorolczuk/work/garmin/gyromaze/resources/launcher_icon.png", "PNG")
print("ok")
