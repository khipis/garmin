#!/usr/bin/env python3
"""Generate poker launcher_icon.png (40x40) and poker_hero.png (1440x720)."""

from PIL import Image, ImageDraw, ImageFont
import os, math, random

BASE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(BASE)

# ── helpers ──────────────────────────────────────────────────────────────────
def new_icon():
    return Image.new("RGBA", (40, 40), (0, 0, 0, 0))

def save_icon(img, folder):
    path = os.path.join(ROOT, folder, "resources", "launcher_icon.png")
    img.save(path)
    print(f"  saved {path}  {img.size}")

def circle_crop(img):
    mask = Image.new("L", img.size, 0)
    d = ImageDraw.Draw(mask)
    d.ellipse([0, 0, img.size[0]-1, img.size[1]-1], fill=255)
    img.putalpha(mask)
    return img

# ── Poker icon ────────────────────────────────────────────────────────────────
def make_poker_icon():
    img = new_icon()
    d = ImageDraw.Draw(img)
    # Dark green felt background
    d.ellipse([0, 0, 39, 39], fill=(15, 60, 30, 255))
    d.ellipse([2, 2, 37, 37], fill=(18, 75, 38, 255))

    # Draw a card (white face)
    card_x, card_y, cw, ch = 6, 7, 12, 17
    d.rounded_rectangle([card_x, card_y, card_x+cw, card_y+ch], radius=2, fill=(230, 225, 200, 255))
    # Red heart on card
    d.text((card_x+3, card_y+2), "A", fill=(180, 20, 20, 255))
    d.text((card_x+2, card_y+7), "\u2665", fill=(180, 20, 20, 255))

    # Second card (overlapping)
    card_x2 = card_x + 10
    d.rounded_rectangle([card_x2, card_y, card_x2+cw, card_y+ch], radius=2, fill=(235, 230, 205, 255))
    d.text((card_x2+3, card_y+2), "K", fill=(30, 30, 60, 255))
    d.text((card_x2+2, card_y+7), "\u2660", fill=(30, 30, 60, 255))

    # Chips stack (right side)
    chip_colors = [(220, 60, 60), (60, 60, 200), (220, 220, 60)]
    for i, cc in enumerate(chip_colors):
        cy = 28 - i * 3
        d.ellipse([26, cy, 36, cy+6], fill=(*cc, 240))
        d.ellipse([27, cy+1, 35, cy+4], fill=(min(cc[0]+40, 255), min(cc[1]+40, 255), min(cc[2]+40, 255), 200))

    return circle_crop(img)

# ── Poker hero image ──────────────────────────────────────────────────────────
def make_poker_hero():
    W, H = 1440, 720
    img = Image.new("RGB", (W, H), (5, 15, 25))
    d = ImageDraw.Draw(img)

    # Dark background gradient effect (manual)
    for y in range(H):
        t = y / H
        c = int(5 + t * 15)
        d.line([(0, y), (W, y)], fill=(c, c + 8, c + 12))

    # Green felt table (centered ellipse)
    felt_cx, felt_cy = W // 2, H * 55 // 100
    felt_rx, felt_ry = W * 40 // 100, H * 28 // 100
    # Shadow
    d.ellipse([felt_cx - felt_rx - 10, felt_cy - felt_ry - 6,
               felt_cx + felt_rx + 10, felt_cy + felt_ry + 12],
              fill=(0, 0, 0, 200) if img.mode == "RGBA" else (10, 10, 10))
    # Felt surface
    d.ellipse([felt_cx - felt_rx, felt_cy - felt_ry,
               felt_cx + felt_rx, felt_cy + felt_ry],
              fill=(15, 100, 50))
    d.ellipse([felt_cx - felt_rx + 6, felt_cy - felt_ry + 4,
               felt_cx + felt_rx - 6, felt_cy + felt_ry - 4],
              fill=(18, 115, 58))
    # Table border
    d.ellipse([felt_cx - felt_rx - 12, felt_cy - felt_ry - 8,
               felt_cx + felt_rx + 12, felt_cy + felt_ry + 8],
              outline=(80, 40, 10), width=14)
    d.ellipse([felt_cx - felt_rx - 6, felt_cy - felt_ry - 4,
               felt_cx + felt_rx + 6, felt_cy + felt_ry + 4],
              outline=(100, 55, 15), width=6)

    # ── Community cards (5 in a row on the table) ────────────────────────────
    card_w, card_h = 90, 130
    gap = 18
    total_cw = 5 * card_w + 4 * gap
    cx_start = W // 2 - total_cw // 2
    cy_card = felt_cy - card_h // 2 + 10
    suits     = ["\u2660", "\u2665", "\u2666", "\u2665", "\u2663"]
    ranks     = ["A", "K", "Q", "J", "10"]
    is_red    = [False, True, True, True, False]
    for i in range(5):
        cx = cx_start + i * (card_w + gap)
        # Card shadow
        d.rounded_rectangle([cx+4, cy_card+4, cx+card_w+4, cy_card+card_h+4],
                             radius=8, fill=(0, 0, 0))
        # Card face
        d.rounded_rectangle([cx, cy_card, cx+card_w, cy_card+card_h],
                             radius=8, fill=(238, 232, 210))
        d.rounded_rectangle([cx+2, cy_card+2, cx+card_w-2, cy_card+card_h-2],
                             radius=6, outline=(180, 175, 155), width=2)
        clr = (190, 15, 15) if is_red[i] else (20, 20, 50)
        # Rank top-left
        d.text((cx + 8, cy_card + 6), ranks[i], fill=clr)
        # Suit top-left
        d.text((cx + 8, cy_card + 26), suits[i], fill=clr)
        # Large centre suit
        d.text((cx + card_w // 2 - 18, cy_card + card_h // 2 - 22), suits[i], fill=clr)

    # ── Title ─────────────────────────────────────────────────────────────────
    title_y = H * 10 // 100
    for dx in range(-2, 3):
        for dy in range(-2, 3):
            d.text((W // 2 - 180 + dx, title_y + dy), "BITOCHI POKER",
                   fill=(0, 0, 0))
    d.text((W // 2 - 180, title_y), "BITOCHI POKER", fill=(68, 200, 255))

    subtitle_y = H * 20 // 100
    d.text((W // 2 - 100, subtitle_y), "Texas Hold'em", fill=(180, 200, 120))

    # ── Chips (left side) ─────────────────────────────────────────────────────
    chip_colors = [(220, 50, 50), (50, 50, 210), (230, 180, 30), (210, 210, 210)]
    for j, cc in enumerate(chip_colors):
        cx2 = W * 15 // 100
        cy2 = felt_cy - 60 + j * 16
        # Stack of chips
        for k in range(4):
            cyk = cy2 - k * 6
            d.ellipse([cx2-38, cyk-6, cx2+38, cyk+6], fill=cc)
            d.ellipse([cx2-32, cyk-3, cx2+32, cyk+3],
                      fill=(min(cc[0]+30,255), min(cc[1]+30,255), min(cc[2]+30,255)))

    # ── Player cards (bottom) ─────────────────────────────────────────────────
    ph_w, ph_h = 110, 155
    ph_gap = 30
    ph_y = H * 68 // 100
    ph_cards = [("A", "\u2660", False), ("A", "\u2665", True)]
    for i, (rk, su, red) in enumerate(ph_cards):
        phx = W // 2 - ph_gap // 2 - ph_w + i * (ph_w + ph_gap)
        # Shadow
        d.rounded_rectangle([phx+5, ph_y+5, phx+ph_w+5, ph_y+ph_h+5],
                             radius=10, fill=(0, 0, 0))
        # Card
        d.rounded_rectangle([phx, ph_y, phx+ph_w, ph_y+ph_h],
                             radius=10, fill=(245, 238, 218))
        clr = (185, 15, 15) if red else (20, 20, 50)
        d.text((phx + 10, ph_y + 8), rk, fill=clr)
        d.text((phx + 10, ph_y + 35), su, fill=clr)
        d.text((phx + ph_w // 2 - 22, ph_y + ph_h // 2 - 28), su, fill=clr)

    # ── POT label ─────────────────────────────────────────────────────────────
    d.text((W // 2 - 60, felt_cy - felt_ry + 20), "POT: 1240", fill=(255, 220, 60))

    path = os.path.join(BASE, "poker_hero.png")
    img.save(path)
    print(f"  saved {path}  {img.size}")

# ── Run ───────────────────────────────────────────────────────────────────────
print("Generating poker assets…")
poker_icon = make_poker_icon()
save_icon(poker_icon, "poker")
make_poker_hero()
print("Done.")
