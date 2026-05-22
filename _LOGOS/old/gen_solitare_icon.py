#!/usr/bin/env python3
"""Generate solitaire launcher_icon.png (40x40) and solitare_hero.png (1440x720)."""

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
    # Green felt
    d.ellipse([0,0,39,39], fill=(15, 60, 30, 255))
    d.ellipse([2,2,37,37], fill=(18, 80, 42, 255))

    # Draw fanned card pile (blue backs)
    offsets = [0, 3, 6]
    for ox in offsets:
        d.rounded_rectangle([5+ox, 6, 16+ox, 22], radius=2, fill=(30, 50, 160, 240))
        d.rounded_rectangle([6+ox, 7, 15+ox, 21], radius=1, outline=(55, 75, 190, 180), width=1)

    # A♥ face card on top right
    d.rounded_rectangle([20, 10, 33, 30], radius=2, fill=(232, 226, 205, 255))
    d.rounded_rectangle([20, 10, 33, 30], radius=2, outline=(160, 150, 130, 200), width=1)
    d.text((22, 11), "A",  fill=(190, 20, 20, 255))
    d.text((21, 19), "\u2665", fill=(190, 20, 20, 255))

    return circle_crop(img)

# ── Hero image ────────────────────────────────────────────────────────────────
def make_hero():
    W, H = 1440, 720
    img = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(img)

    # Background gradient
    for y in range(H):
        t = y / H
        g = int(8 + t * 10)
        d.line([(0,y),(W,y)], fill=(g, g+14, g+8))

    # Felt table
    tx, ty, tw, th = W//2 - 500, H//2 - 170, 1000, 360
    d.rounded_rectangle([tx-8, ty-8, tx+tw+8, ty+th+8], radius=30, fill=(8, 25, 12))
    d.rounded_rectangle([tx, ty, tx+tw, ty+th], radius=24, fill=(16, 90, 45))
    d.rounded_rectangle([tx+8, ty+8, tx+tw-8, ty+th-8], radius=18, fill=(20, 105, 52))

    def card(x, y, cw, ch, rank, suit, face_up=True, rotated=False):
        if not face_up:
            d.rounded_rectangle([x,y,x+cw,y+ch], radius=6, fill=(28,48,168))
            d.rounded_rectangle([x+2,y+2,x+cw-2,y+ch-2], radius=4, outline=(48,68,195), width=1)
            return
        d.rounded_rectangle([x,y,x+cw,y+ch], radius=6, fill=(238,232,210))
        d.rounded_rectangle([x+2,y+2,x+cw-2,y+ch-2], radius=4, outline=(170,160,140), width=1)
        red = suit in ["\u2665","\u2666"]
        clr = (185,15,15) if red else (20,20,55)
        d.text((x+6, y+5), rank, fill=clr)
        d.text((x+6, y+24), suit, fill=clr)
        d.text((x+cw//2-8, y+ch//2-14), suit, fill=clr)

    cw, ch = 80, 112

    # 4 foundation piles (top right area)
    suits = ["\u2660","\u2665","\u2666","\u2663"]
    found_ranks = ["A","3","7","K"]
    for i, (s, r) in enumerate(zip(suits, found_ranks)):
        fx = tx + tw - 340 + i * 90
        fy = ty + 20
        card(fx, fy, cw, ch, r, s)

    # Tableau — 7 columns of fanned cards
    col_x_start = tx + 20
    col_gap = (tw - 40 - cw) // 6
    face_up_cards = [
        [("K","\u2660")],
        [("Q","\u2665"),("J","\u2660")],
        [("T","\u2665"),("9","\u2660"),("8","\u2665")],
        [("7","\u2665"),("6","\u2660"),("5","\u2665"),("4","\u2660")],
        [("3","\u2665"),("2","\u2660"),("A","\u2665"),("K","\u2660"),("Q","\u2665")],
    ]
    face_down_counts = [0, 1, 2, 3, 4, 5, 6]
    for col in range(7):
        cx = col_x_start + col * col_gap
        cy = ty + 145
        # Face-down cards
        for fd in range(face_down_counts[col]):
            card(cx, cy + fd * 22, cw, 28, "", "", face_up=False)
        # Face-up cards
        fu = face_up_cards[col % len(face_up_cards)]
        for fi, (r, s) in enumerate(fu):
            fd_count = face_down_counts[col]
            fy2 = cy + fd_count * 22 + fi * 22
            is_last = (fi == len(fu) - 1)
            if is_last:
                card(cx, fy2, cw, ch, r, s)
            else:
                card(cx, fy2, cw, 28, r, s)

    # Stock pile (top left)
    for k in range(4):
        card(tx + 20 + k, ty + 20 - k, cw, ch, "", "", face_up=False)

    # Title
    for dx in range(-2, 3):
        for dy in range(-2, 3):
            d.text((W//2 - 130 + dx, H*8//100 + dy), "BITOCHI SOLITAIRE", fill=(0,0,0))
    d.text((W//2 - 130, H*8//100), "BITOCHI SOLITAIRE", fill=(68,200,255))
    d.text((W//2 - 80, H*18//100), "Klondike · Draw 1 / Draw 3", fill=(160,200,140))

    path = os.path.join(BASE, "solitare_hero.png")
    img.save(path)
    print(f"  saved {path}  {img.size}")

print("Generating solitaire assets…")
icon = make_icon()
icon_path = os.path.join(ROOT, "solitare", "resources", "launcher_icon.png")
icon.save(icon_path)
print(f"  saved {icon_path}  {icon.size}")
make_hero()
print("Done.")
