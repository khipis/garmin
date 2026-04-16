#!/usr/bin/env python3
"""Generate a premium chess_hero.png (1440x720)."""

import math, os, random
from PIL import Image, ImageDraw, ImageFont, ImageFilter

random.seed(42)
BASE = os.path.dirname(os.path.abspath(__file__))

def get_font(size):
    for path in [
        "/System/Library/Fonts/Supplemental/Impact.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/Arial.ttf",
    ]:
        try: return ImageFont.truetype(path, size)
        except: pass
    return ImageFont.load_default()

def get_piece_font(size):
    for path in [
        "/System/Library/Fonts/Supplemental/Arial Unicode.ttf",
        "/System/Library/Fonts/Apple Color Emoji.ttc",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
    ]:
        try: return ImageFont.truetype(path, size)
        except: pass
    return ImageFont.load_default()

def save(img, path):
    os.makedirs(os.path.dirname(path) if os.path.dirname(path) else ".", exist_ok=True)
    img.save(path, "PNG", optimize=True)
    kb = os.path.getsize(path) // 1024
    print(f"  saved {path}  {img.size}  ({kb} KB)")

W, H = 1440, 720
img = Image.new("RGBA", (W, H))
d = ImageDraw.Draw(img)

# ── Rich dark wood background with gradient ──
for y in range(H):
    t = y / H
    r = int(18 + t * 10 + math.sin(y * 0.03) * 3)
    g = int(12 + t * 6 + math.sin(y * 0.03) * 2)
    b = int(6 + t * 3)
    d.line([(0, y), (W, y)], fill=(r, g, b))

# Wood grain texture
for _ in range(3000):
    sx = random.randint(0, W - 1)
    sy = random.randint(0, H - 1)
    grain = random.randint(0, 8)
    d.point((sx, sy), fill=(grain, grain // 2, 0, grain * 3))

# ── Spotlight glow ──
glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
gd = ImageDraw.Draw(glow)
for r in range(400, 0, -4):
    a = int(25 * r / 400)
    gd.ellipse([W//2 - r, 200 - r, W//2 + r, 200 + r], fill=(60, 45, 20, a))
img.alpha_composite(glow)

# ── Chess board ──
SQ = 62
BW = SQ * 8
bx = W // 2 - BW // 2
by = 60

light = (232, 200, 148)
dark  = (140, 88, 46)
border_c = (65, 38, 15)
border_hi = (95, 60, 28)

# Outer frame with beveled edges
d.rectangle([bx - 12, by - 12, bx + BW + 12, by + BW + 12], fill=(30, 18, 6))
d.rectangle([bx - 10, by - 10, bx + BW + 10, by + BW + 10], fill=border_c)
d.rectangle([bx - 8, by - 8, bx + BW + 8, by + BW + 8], fill=border_hi)
d.rectangle([bx - 6, by - 6, bx + BW + 6, by + BW + 6], fill=border_c)

# Board squares with subtle inner shadows
for row in range(8):
    for col in range(8):
        is_light = (row + col) % 2 == 0
        base = light if is_light else dark
        x0 = bx + col * SQ
        y0 = by + row * SQ
        d.rectangle([x0, y0, x0 + SQ - 1, y0 + SQ - 1], fill=base)
        # Subtle top-left highlight
        hi = tuple(min(c + 12, 255) for c in base)
        d.line([(x0, y0), (x0 + SQ - 2, y0)], fill=hi)
        d.line([(x0, y0), (x0, y0 + SQ - 2)], fill=hi)
        # Bottom-right shadow
        sh = tuple(max(c - 15, 0) for c in base)
        d.line([(x0 + 1, y0 + SQ - 1), (x0 + SQ - 1, y0 + SQ - 1)], fill=sh)
        d.line([(x0 + SQ - 1, y0 + 1), (x0 + SQ - 1, y0 + SQ - 1)], fill=sh)

# ── Piece rendering using Unicode glyphs ──
piece_font = get_piece_font(SQ - 10)
shadow_font = get_piece_font(SQ - 10)

white_pieces = {
    "K": "\u2654", "Q": "\u2655", "R": "\u2656",
    "B": "\u2657", "N": "\u2658", "P": "\u2659",
}
black_pieces = {
    "K": "\u265A", "Q": "\u265B", "R": "\u265C",
    "B": "\u265D", "N": "\u265E", "P": "\u265F",
}

# Mid-game position (interesting, not starting)
# Row 0 = top of image = rank 8 (black's back rank)
# Col 0 = a-file
board_setup = {
    # Black pieces
    (0, 0): ("R", False), (4, 0): ("K", False), (7, 0): ("R", False),
    (3, 1): ("Q", False),
    (0, 1): ("P", False), (2, 2): ("P", False), (4, 1): ("P", False),
    (5, 1): ("P", False), (7, 1): ("P", False),
    (5, 2): ("N", False), (2, 0): ("B", False),
    # White pieces
    (0, 7): ("R", True), (4, 7): ("K", True), (7, 7): ("R", True),
    (3, 6): ("Q", True),
    (1, 6): ("P", True), (2, 5): ("P", True), (5, 6): ("P", True),
    (6, 6): ("P", True), (7, 6): ("P", True),
    (2, 4): ("N", True), (5, 5): ("B", True),
}

white_col = (248, 242, 228)
white_outline = (160, 130, 80)
black_col = (32, 22, 12)
black_outline = (120, 100, 70)

for (col, row), (piece, is_white) in board_setup.items():
    cx = bx + col * SQ + SQ // 2
    cy = by + row * SQ + SQ // 2
    glyph_map = white_pieces if is_white else black_pieces
    glyph = glyph_map[piece]
    color = white_col if is_white else black_col

    # Shadow
    d.text((cx + 2, cy + 3), glyph, font=piece_font, fill=(0, 0, 0, 120), anchor="mm")
    # Outline (draw at offsets)
    outline_c = white_outline if is_white else black_outline
    for dx in [-1, 0, 1]:
        for dy in [-1, 0, 1]:
            if dx == 0 and dy == 0: continue
            d.text((cx + dx, cy + dy), glyph, font=piece_font, fill=outline_c, anchor="mm")
    # Main piece
    d.text((cx, cy), glyph, font=piece_font, fill=color, anchor="mm")

# ── Coordinate labels ──
coord_font = get_font(14)
files = "abcdefgh"
for i in range(8):
    fx = bx + i * SQ + SQ // 2
    d.text((fx, by + BW + 8), files[i], font=coord_font, fill=(90, 65, 35), anchor="mt")
    d.text((bx - 10, by + i * SQ + SQ // 2), str(8 - i), font=coord_font, fill=(90, 65, 35), anchor="mm")

# ── Captured pieces on the sides ──
small_font = get_piece_font(28)
captured_white = ["\u2659", "\u2659", "\u2657"]  # lost white pieces
captured_black = ["\u265F", "\u265F", "\u265E", "\u265D"]  # lost black pieces

for i, g in enumerate(captured_black):
    d.text((bx - 45, by + 30 + i * 32), g, font=small_font, fill=(35, 25, 12, 160), anchor="mm")
for i, g in enumerate(captured_white):
    d.text((bx + BW + 45, by + 30 + i * 32), g, font=small_font, fill=(200, 190, 170, 160), anchor="mm")

# ── Title area at bottom ──
title_y = by + BW + 30
tf = get_font(72)
sf = get_font(24)

title = "BITOCHI CHESS"
# Shadow
d.text((W // 2 + 3, title_y + 3), title, font=tf, fill=(0, 0, 0, 200), anchor="mt")
# Gold text
d.text((W // 2, title_y), title, font=tf, fill=(255, 215, 75), anchor="mt")

# Subtitle
sub = "Play chess vs AI  \u00b7  Easy / Normal / Hard"
d.text((W // 2, title_y + 72), sub, font=sf, fill=(170, 145, 105), anchor="mt")

# ── Decorative elements: chess clock / rating feel ──
# Small decorative line separators
line_y = title_y - 8
lw = 200
d.line([(W // 2 - lw, line_y), (W // 2 + lw, line_y)], fill=(80, 55, 25), width=1)
# Diamond at center
dc_s = 4
d.polygon([(W//2, line_y - dc_s), (W//2 + dc_s, line_y), (W//2, line_y + dc_s), (W//2 - dc_s, line_y)],
          fill=(120, 85, 40))

# ── Subtle vignette ──
vig = Image.new("RGBA", (W, H), (0, 0, 0, 0))
vd = ImageDraw.Draw(vig)
for i in range(80):
    a = int(2.5 * i)
    vd.rectangle([i, i, W - i, H - i], outline=(0, 0, 0, a))
img.alpha_composite(vig)

save(img.convert("RGB"), os.path.join(BASE, "chess_hero.png"))
save(img.convert("RGB"), os.path.join(BASE, "chess", "chess_hero.png"))

print("Done!")
