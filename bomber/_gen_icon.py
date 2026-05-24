#!/usr/bin/env python3
"""40x40 launcher icon: classic bomb with lit fuse."""
from PIL import Image, ImageDraw

S = 40
img = Image.new('RGBA', (S, S), (10, 4, 4, 255))
d = ImageDraw.Draw(img)
d.ellipse((1, 1, S - 2, S - 2), fill=(22, 10, 10, 255))

# Subtle floor glow.
for r in range(18, 12, -2):
    a = 30 + (18 - r) * 8
    d.ellipse((S/2 - r, S/2 + 4 - r/2, S/2 + r, S/2 + 4 + r/2),
              fill=(255, 100, 30, a))

# Bomb body (black sphere with highlight).
d.ellipse((S/2 - 11, S/2 - 8, S/2 + 11, S/2 + 14),
          fill=(15, 15, 20, 255), outline=(60, 60, 70, 255))
d.ellipse((S/2 - 7, S/2 - 5, S/2 - 2, S/2 - 0),
          fill=(80, 80, 95, 255))

# Fuse on top.
d.line((S/2, S/2 - 8, S/2 + 1, S/2 - 12), fill=(180, 130, 60, 255), width=2)
d.line((S/2 + 1, S/2 - 12, S/2 + 5, S/2 - 14), fill=(180, 130, 60, 255), width=2)

# Spark.
d.ellipse((S/2 + 3, S/2 - 17, S/2 + 9, S/2 - 11),
          fill=(255, 220, 60, 255))
d.ellipse((S/2 + 5, S/2 - 16, S/2 + 7, S/2 - 14),
          fill=(255, 255, 220, 255))

img.save("/Users/kkorolczuk/work/garmin/bomber/resources/launcher_icon.png", "PNG")
print("ok")
