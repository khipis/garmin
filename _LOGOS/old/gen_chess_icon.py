#!/usr/bin/env python3
"""Generate chess launcher_icon.png (40x40) and chess_hero.png (1440x720)."""

from PIL import Image, ImageDraw
import os, math

BASE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(BASE)

def circle_crop(img):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).ellipse([0, 0, img.size[0]-1, img.size[1]-1], fill=255)
    img.putalpha(mask)
    return img

# ── Launcher icon ─────────────────────────────────────────────────────────────
def make_icon():
    img = Image.new("RGBA", (40, 40), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Checkerboard background (4x4 grid, 10px each)
    colors = [(212, 176, 119), (139, 94, 44)]
    for row in range(4):
        for col in range(4):
            c = colors[(row + col) % 2]
            d.rectangle([col*10, row*10, col*10+9, row*10+9], fill=c)

    # White king piece in centre
    d.text((10, 8),  "\u2654", fill=(245, 240, 225))   # ♔
    d.text((22, 18), "\u265A", fill=(30, 18, 8))         # ♚

    return circle_crop(img)

# ── Hero image ────────────────────────────────────────────────────────────────
def make_hero():
    W, H = 1440, 720
    img = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(img)

    # Background gradient (dark wood)
    for y in range(H):
        t = y / H
        r = int(12 + t * 8)
        g = int(8 + t * 5)
        b = int(4 + t * 3)
        d.line([(0, y), (W, y)], fill=(r, g, b))

    # Chess board
    SQ = 72
    BW = SQ * 8
    BH = SQ * 8
    bx = W // 2 - BW // 2
    by = H // 2 - BH // 2

    light = (212, 176, 119)
    dark  = (139, 94, 44)
    border = (80, 50, 20)

    d.rectangle([bx - 8, by - 8, bx + BW + 8, by + BH + 8], fill=border)
    for row in range(8):
        for col in range(8):
            c = light if (row + col) % 2 == 0 else dark
            d.rectangle([bx + col*SQ, by + row*SQ, bx + col*SQ + SQ - 1, by + row*SQ + SQ - 1], fill=c)

    # Arrange a midgame position
    pieces = [
        # (col, row, glyph, color)
        (4, 0, "\u2654", (245,240,225)),  # white king e8
        (3, 0, "\u2655", (245,240,225)),  # white queen d8
        (0, 0, "\u2656", (245,240,225)),  # white rook a8
        (7, 0, "\u2656", (245,240,225)),  # white rook h8
        (2, 1, "\u2659", (245,240,225)),  # white pawns
        (4, 1, "\u2659", (245,240,225)),
        (6, 1, "\u2659", (245,240,225)),

        (4, 7, "\u265A", (25,15,5)),   # black king
        (3, 7, "\u265B", (25,15,5)),   # black queen
        (0, 7, "\u265C", (25,15,5)),   # black rook
        (7, 7, "\u265C", (25,15,5)),
        (1, 6, "\u265F", (25,15,5)),
        (3, 6, "\u265F", (25,15,5)),
        (5, 6, "\u265F", (25,15,5)),
    ]
    from PIL import ImageFont
    fnt_size = 48
    try:
        fnt = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Unicode.ttf", fnt_size)
    except Exception:
        try:
            fnt = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", fnt_size)
        except Exception:
            fnt = ImageFont.load_default()

    for (col, row, glyph, color) in pieces:
        px = bx + col * SQ + SQ // 2 - fnt_size // 2
        py = by + row * SQ + SQ // 2 - fnt_size // 2
        # Shadow
        d.text((px + 2, py + 2), glyph, font=fnt, fill=(0, 0, 0, 128))
        d.text((px, py), glyph, font=fnt, fill=color)

    # Title
    try:
        title_fnt = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 72)
        sub_fnt   = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 36)
    except Exception:
        title_fnt = fnt
        sub_fnt   = fnt

    title = "BITOCHI CHESS"
    tx = W // 2 - 220
    for dx in range(-3, 4):
        for dy in range(-3, 4):
            d.text((tx + dx, H * 6 // 100 + dy), title, font=title_fnt, fill=(0, 0, 0))
    d.text((tx, H * 6 // 100), title, font=title_fnt, fill=(255, 215, 80))
    d.text((W // 2 - 160, H * 18 // 100), "Play chess vs AI  ·  Easy / Normal / Hard",
           font=sub_fnt, fill=(180, 160, 120))

    path = os.path.join(BASE, "chess_hero.png")
    img.save(path)
    print(f"  saved {path}  {img.size}")

print("Generating chess assets…")
icon = make_icon()
icon_path = os.path.join(ROOT, "chess", "resources", "launcher_icon.png")
icon.save(icon_path)
print(f"  saved {icon_path}  {icon.size}")
make_hero()
print("Done.")
