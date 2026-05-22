#!/usr/bin/env python3
"""Generate Makao Lite launcher icon (70x70) and copy to resources."""
from PIL import Image, ImageDraw, ImageFont
import math, os, shutil

SIZE = 70
img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
d   = ImageDraw.Draw(img)

# Dark green card-table background (rounded square)
BG  = (11, 30, 15, 255)
def rr(draw, xy, r, fill):
    x0,y0,x1,y1 = xy
    draw.rectangle([x0+r,y0,x1-r,y1], fill=fill)
    draw.rectangle([x0,y0+r,x1,y1-r], fill=fill)
    draw.ellipse([x0,y0,x0+2*r,y0+2*r], fill=fill)
    draw.ellipse([x1-2*r,y0,x1,y0+2*r], fill=fill)
    draw.ellipse([x0,y1-2*r,x0+2*r,y1], fill=fill)
    draw.ellipse([x1-2*r,y1-2*r,x1,y1], fill=fill)

rr(d, (0,0,69,69), 10, BG)

# Draw two overlapping cards

def draw_card(draw, x, y, w, h, rank, suit, red):
    # card background
    rr(draw, (x,y,x+w,y+h), 4, (245,240,224,240))
    rr(draw, (x,y,x+w,y+h), 4, None)  # outline will be done separately
    draw.rounded_rectangle([x,y,x+w,y+h], radius=4, outline=(80,80,80,200), width=1)
    col = (200,20,0,255) if red else (20,20,20,255)
    try:
        font_sm = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 10)
    except:
        font_sm = ImageFont.load_default()
    draw.text((x+3, y+2), rank, fill=col, font=font_sm)
    draw.text((x+3, y+12), suit, fill=col, font=font_sm)

# Left card: A of Hearts (red)
draw_card(d, 6, 14, 26, 38, "A", "H", True)
# Right card: 2 of Spades (black)
draw_card(d, 22, 20, 26, 38, "2", "S", False)
# Front card: K of Diamonds (red)
draw_card(d, 38, 10, 26, 38, "K", "D", True)

# App label at bottom
try:
    font_lbl = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 9)
except:
    font_lbl = ImageFont.load_default()
d.text((35, 54), "MAKAO", fill=(180,220,180,220), font=font_lbl, anchor="mm")

out_dir = os.path.dirname(__file__)
icon_src = os.path.join(out_dir, "makao_icon.png")
img.save(icon_src)
print(f"Saved {icon_src}")

res_dir = os.path.join(out_dir, "..", "makao_lite", "resources")
os.makedirs(res_dir, exist_ok=True)
dst = os.path.join(res_dir, "launcher_icon.png")
shutil.copy(icon_src, dst)
print(f"Copied to {dst}")
