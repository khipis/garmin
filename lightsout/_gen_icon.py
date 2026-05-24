#!/usr/bin/env python3
"""40x40 launcher icon: glowing light bulb on dark."""
from PIL import Image, ImageDraw

S = 40
img = Image.new('RGBA', (S, S), (8, 12, 28, 255))
d = ImageDraw.Draw(img)
d.ellipse((1, 1, S - 2, S - 2), fill=(14, 22, 40, 255))

# Glow halo.
for r in range(16, 8, -2):
    a = 40 + (16 - r) * 8
    d.ellipse((S/2 - r, S/2 - r - 2, S/2 + r, S/2 + r - 2),
              fill=(255, 200, 40, a))

# Bulb body.
d.ellipse((S/2 - 9, S/2 - 12, S/2 + 9, S/2 + 7),
          fill=(255, 220, 60, 255), outline=(180, 130, 0, 255))

# Highlight.
d.ellipse((S/2 - 5, S/2 - 9, S/2, S/2 - 4),
          fill=(255, 255, 220, 255))

# Bulb base / screw.
d.rectangle((S/2 - 5, S/2 + 7, S/2 + 5, S/2 + 11),
            fill=(80, 60, 30, 255), outline=(30, 20, 5, 255))
for yo in [9, 11]:
    d.line((S/2 - 4, S/2 + yo, S/2 + 4, S/2 + yo),
           fill=(30, 20, 5, 255))
d.line((S/2 - 3, S/2 + 13, S/2 + 3, S/2 + 13),
       fill=(20, 10, 0, 255))

img.save("/Users/kkorolczuk/work/garmin/lightsout/resources/launcher_icon.png", "PNG")
print("ok")
