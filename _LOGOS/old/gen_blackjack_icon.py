#!/usr/bin/env python3
"""Generate blackjack launcher_icon.png (40x40), store_icon.png (200x200), blackjack_hero.png (1440x720)."""

import math, os, random
from PIL import Image, ImageDraw, ImageFont

random.seed(21)

BASE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(BASE)

def get_font(size):
    for path in [
        "/System/Library/Fonts/Supplemental/Impact.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/Arial.ttf",
    ]:
        try:
            return ImageFont.truetype(path, size)
        except Exception:
            pass
    return ImageFont.load_default()

def circle_crop(img):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).ellipse([0, 0, img.size[0]-1, img.size[1]-1], fill=255)
    img.putalpha(mask)
    return img

def save(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, "PNG", optimize=True)
    kb = os.path.getsize(path) // 1024
    print(f"  saved {path}  {img.size}  ({kb} KB)")

def gradient_bg(d, w, h, top, bot):
    for y in range(h):
        t = y / max(h - 1, 1)
        r = int(top[0] + t * (bot[0] - top[0]))
        g = int(top[1] + t * (bot[1] - top[1]))
        b = int(top[2] + t * (bot[2] - top[2]))
        d.line([(0, y), (w, y)], fill=(r, g, b))

def draw_suit(d, cx, cy, suit, s, color):
    r = s * 5 // 10
    if r < 2: r = 2
    if suit == 0:  # spade
        d.polygon([(cx, cy - s), (cx - s, cy + s // 4), (cx + s, cy + s // 4)], fill=color)
        d.ellipse([cx - r, cy + s // 6 - r, cx + 1, cy + s // 6 + r], fill=color)
        d.ellipse([cx - 1, cy + s // 6 - r, cx + r, cy + s // 6 + r], fill=color)
        d.rectangle([cx - 1, cy + s // 3, cx + 2, cy + s // 3 + s * 4 // 10], fill=color)
    elif suit == 1:  # heart
        d.ellipse([cx - r, cy - s // 4 - r, cx + 1, cy - s // 4 + r], fill=color)
        d.ellipse([cx - 1, cy - s // 4 - r, cx + r, cy - s // 4 + r], fill=color)
        d.polygon([(cx - s, cy - s // 6), (cx, cy + s), (cx + s, cy - s // 6)], fill=color)
    elif suit == 2:  # diamond
        d.polygon([(cx, cy - s), (cx + s * 6 // 10, cy), (cx, cy + s), (cx - s * 6 // 10, cy)], fill=color)
    else:  # club
        d.ellipse([cx - r, cy - s * 4 // 10 - r, cx + r, cy - s * 4 // 10 + r], fill=color)
        d.ellipse([cx - s * 4 // 10 - r, cy + s // 5 - r, cx - s * 4 // 10 + r, cy + s // 5 + r], fill=color)
        d.ellipse([cx + s * 4 // 10 - r, cy + s // 5 - r, cx + s * 4 // 10 + r, cy + s // 5 + r], fill=color)
        d.rectangle([cx - 1, cy + s // 3, cx + 2, cy + s // 3 + s * 4 // 10], fill=color)

def draw_card(d, x, y, w, h, rank, suit, face_down=False):
    cr = max(w // 12, 2)
    if face_down:
        d.rounded_rectangle([x, y, x+w, y+h], radius=cr, fill=(26, 46, 90))
        d.rounded_rectangle([x+1, y+1, x+w-1, y+h-1], radius=cr, outline=(74, 106, 170))
        m = max(w // 8, 3)
        d.rounded_rectangle([x+m, y+m, x+w-m, y+h-m], radius=max(cr-1, 1), outline=(36, 58, 114))
        cx2, cy2 = x + w // 2, y + h // 2
        ds = w // 5
        d.polygon([(cx2, cy2 - ds), (cx2 + ds, cy2), (cx2, cy2 + ds), (cx2 - ds, cy2)], fill=(74, 106, 170))
        return

    d.rounded_rectangle([x, y, x+w, y+h], radius=cr, fill=(252, 250, 246))
    d.rounded_rectangle([x, y, x+w, y+h], radius=cr, outline=(200, 200, 200))

    ranks = ["2","3","4","5","6","7","8","9","10","J","Q","K","A"]
    is_red = suit in (1, 2)
    tc = (200, 17, 17) if is_red else (30, 30, 30)

    fnt_size = max(w * 30 // 100, 8)
    fnt = get_font(fnt_size)

    d.text((x + max(w * 8 // 100, 3), y + max(h * 5 // 100, 2)), ranks[rank], font=fnt, fill=tc)

    ss = max(w * 22 // 100, 3)
    draw_suit(d, x + w // 2, y + h // 2, suit, ss, tc)

    if h > fnt_size * 3:
        bb = d.textbbox((0, 0), ranks[rank], font=fnt)
        th = bb[3] - bb[1]
        d.text((x + w - max(w * 8 // 100, 3), y + h - th - max(h * 5 // 100, 2)),
               ranks[rank], font=fnt, fill=tc, anchor="rt" if hasattr(fnt, 'getbbox') else None)


# ═════════════════════════════════════════════════════════════════════════════
#  LAUNCHER ICON (40x40)
# ═════════════════════════════════════════════════════════════════════════════
print("=== BLACKJACK ===")

img = Image.new("RGBA", (40, 40), (0, 0, 0, 0))
d = ImageDraw.Draw(img)

for y in range(40):
    t = y / 39
    r = int(5 + t * 15)
    g = int(28 + t * 30)
    b = int(8 + t * 12)
    d.line([(0, y), (39, y)], fill=(r, g, b, 255))

d.rounded_rectangle([3, 6, 19, 32], radius=2, fill=(250, 248, 242))
d.rounded_rectangle([3, 6, 19, 32], radius=2, outline=(190, 190, 180))
fnt = get_font(10)
d.text((5, 7), "A", font=fnt, fill=(30, 30, 30))
draw_suit(d, 11, 20, 0, 4, (30, 30, 30))

d.rounded_rectangle([18, 4, 34, 30], radius=2, fill=(250, 248, 242))
d.rounded_rectangle([18, 4, 34, 30], radius=2, outline=(190, 190, 180))
d.text((20, 5), "K", font=fnt, fill=(200, 17, 17))
draw_suit(d, 26, 18, 1, 4, (200, 17, 17))

fnt_s = get_font(8)
d.text((20, 33), "21", font=fnt_s, fill=(255, 220, 50))

img = circle_crop(img)
save(img, os.path.join(ROOT, "blackjack", "resources", "launcher_icon.png"))


# ═════════════════════════════════════════════════════════════════════════════
#  STORE ICON (200x200)
# ═════════════════════════════════════════════════════════════════════════════

img = Image.new("RGBA", (200, 200), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
gradient_bg(d, 200, 200, (8, 45, 12), (2, 18, 5))

# Felt texture
for _ in range(600):
    sx = random.randint(0, 199)
    sy = random.randint(0, 199)
    a = random.randint(5, 15)
    d.point((sx, sy), fill=(0, 60, 0, a))

draw_card(d, 30, 40, 65, 95, 12, 0)  # A♠
draw_card(d, 105, 40, 65, 95, 11, 1)  # K♥

# "21" chip
cx, cy, cr = 100, 155, 22
d.ellipse([cx-cr-2, cy-cr-2, cx+cr+2, cy+cr+2], fill=(0, 0, 0, 80))
d.ellipse([cx-cr, cy-cr, cx+cr, cy+cr], fill=(200, 170, 30))
d.ellipse([cx-cr+3, cy-cr+3, cx+cr-3, cy+cr-3], fill=(230, 195, 50))
d.ellipse([cx-cr+5, cy-cr+5, cx+cr-5, cy+cr-5], outline=(180, 140, 20), width=2)
fnt = get_font(22)
bb = d.textbbox((0, 0), "21", font=fnt)
tw = bb[2] - bb[0]
d.text((cx - tw // 2, cy - 12), "21", font=fnt, fill=(40, 20, 0))

fnt = get_font(16)
d.text((100, 12), "BLACKJACK", font=fnt, fill=(255, 220, 70), anchor="mt")
d.text((100, 188), "Bitochi", font=get_font(12), fill=(120, 160, 120), anchor="mt")

img = circle_crop(img)
save(img, os.path.join(BASE, "blackjack", "store_icon.png"))


# ═════════════════════════════════════════════════════════════════════════════
#  HERO IMAGE (1440x720)
# ═════════════════════════════════════════════════════════════════════════════

W, H = 1440, 720
img = Image.new("RGBA", (W, H))
d = ImageDraw.Draw(img)

# Rich casino green felt background
gradient_bg(d, W, H, (6, 55, 14), (2, 22, 6))

# Felt texture
random.seed(42)
for _ in range(8000):
    sx = random.randint(0, W - 1)
    sy = random.randint(0, H - 1)
    a = random.randint(3, 12)
    d.point((sx, sy), fill=(0, 80, 0, a))

# Table edge (arc at bottom)
d.arc([-200, H - 180, W + 200, H + 400], 0, 180, fill=(40, 25, 8), width=8)
d.arc([-200, H - 176, W + 200, H + 404], 0, 180, fill=(55, 35, 12), width=3)

# Subtle radial glow from center
from PIL import ImageFilter
glow_lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
gd = ImageDraw.Draw(glow_lay)
for r in range(300, 0, -5):
    a = int(20 * r / 300)
    gd.ellipse([W//2 - r, H//2 - 80 - r, W//2 + r, H//2 - 80 + r], fill=(30, 80, 20, a))
img.alpha_composite(glow_lay)

# ── Main hand: Ace of Spades + King of Hearts = Blackjack! ──
cw, ch = 180, 260
spacing = 30

# Card 1: Ace of Spades (slightly rotated left)
c1x = W // 2 - cw - spacing // 2
c1y = H // 2 - ch // 2 - 40

# Card 2: King of Hearts (slightly rotated right)
c2x = W // 2 + spacing // 2
c2y = c1y

# Shadow
for card_x in [c1x, c2x]:
    d.rounded_rectangle([card_x + 5, c1y + 8, card_x + cw + 5, c1y + ch + 8], radius=12, fill=(0, 0, 0, 60))

# Draw cards
draw_card(d, c1x, c1y, cw, ch, 12, 0)  # A♠
draw_card(d, c2x, c2y, cw, ch, 11, 1)  # K♥

# Face-down card peeking behind
draw_card(d, c1x - 60, c1y + 30, cw, ch, 0, 0, face_down=True)

# ── Chips scattered around ──
chip_colors = [
    ((220, 30, 30), (180, 20, 20)),    # red
    ((30, 100, 220), (20, 70, 180)),    # blue
    ((40, 180, 50), (30, 140, 38)),     # green
    ((230, 195, 50), (190, 155, 30)),   # gold
    ((80, 80, 80), (55, 55, 55)),       # black
]

chip_positions = [
    (180, 280, 28, 0), (220, 350, 24, 1), (160, 420, 26, 3),
    (1200, 260, 30, 3), (1260, 340, 22, 2), (1220, 420, 26, 0),
    (340, 500, 20, 4), (400, 540, 18, 1),
    (1060, 480, 22, 2), (1100, 530, 18, 4),
    (620, 520, 16, 0), (820, 520, 16, 1),
]

for (cx, cy, cr, ci) in chip_positions:
    col, dcol = chip_colors[ci % len(chip_colors)]
    d.ellipse([cx-cr+2, cy-cr+3, cx+cr+2, cy+cr+3], fill=(0, 0, 0, 60))
    d.ellipse([cx-cr, cy-cr, cx+cr, cy+cr], fill=dcol)
    d.ellipse([cx-cr+2, cy-cr+2, cx+cr-2, cy+cr-2], fill=col)
    d.ellipse([cx-cr+4, cy-cr+4, cx+cr-4, cy+cr-4], outline=dcol, width=2)
    # Center dot
    d.ellipse([cx-cr//3, cy-cr//3, cx+cr//3, cy+cr//3], fill=(255, 255, 255, 60))

# ── "21" badge ──
badge_x, badge_y = W // 2, c1y - 10
br = 50
d.ellipse([badge_x-br-3, badge_y-br-3, badge_x+br+3, badge_y+br+3], fill=(0, 0, 0, 80))
d.ellipse([badge_x-br, badge_y-br, badge_x+br, badge_y+br], fill=(210, 175, 35))
d.ellipse([badge_x-br+4, badge_y-br+4, badge_x+br-4, badge_y+br-4], fill=(240, 205, 55))
d.ellipse([badge_x-br+8, badge_y-br+8, badge_x+br-8, badge_y+br-8], outline=(190, 150, 25), width=3)
fnt_21 = get_font(48)
bb = d.textbbox((0, 0), "21", font=fnt_21)
tw = bb[2] - bb[0]
th = bb[3] - bb[1]
d.text((badge_x - tw // 2, badge_y - th // 2 - 4), "21", font=fnt_21, fill=(50, 25, 0))

# ── Title ──
tf = get_font(84)
sf = get_font(28)

title = "BITOCHI BLACKJACK"
bb = d.textbbox((0, 0), title, font=tf)
tw = bb[2] - bb[0]
tx = (W - tw) // 2

d.text((tx + 3, H - 145 + 3), title, font=tf, fill=(0, 0, 0, 160))
d.text((tx, H - 145), title, font=tf, fill=(255, 225, 80))

sub = "Beat the dealer  ·  Classic 21"
bb2 = d.textbbox((0, 0), sub, font=sf)
sw = bb2[2] - bb2[0]
d.text(((W - sw) // 2, H - 60), sub, font=sf, fill=(140, 180, 140))

save(img.convert("RGB"), os.path.join(BASE, "blackjack", "blackjack_hero.png"))

# Also copy launcher icon to blackjack subfolder
launcher = Image.open(os.path.join(ROOT, "blackjack", "resources", "launcher_icon.png"))
save(launcher, os.path.join(BASE, "blackjack", "launcher_icon.png"))

print("\nDone!")
