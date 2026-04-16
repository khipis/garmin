#!/usr/bin/env python3
"""Generate improved logos for chess, checkers, and fakenotificationescape.
Each gets: launcher_icon.png (40x40), store_icon.png (200x200), *_hero.png (1440x720)."""

import math, os, random
from PIL import Image, ImageDraw, ImageFilter, ImageFont

random.seed(42)

BASE  = os.path.dirname(os.path.abspath(__file__))
ROOT  = os.path.dirname(BASE)

def get_font(size):
    for path in [
        "/System/Library/Fonts/Supplemental/Impact.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/Arial.ttf",
        "/Library/Fonts/Arial.ttf",
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

def glow_circle(img, cx, cy, r, col, layers=6):
    w, h = img.size
    for i in range(layers, 0, -1):
        alpha = int(40 * i / layers)
        rad = r + (layers - i) * max(r // 4, 3)
        lay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        ld = ImageDraw.Draw(lay)
        ld.ellipse([cx - rad, cy - rad, cx + rad, cy + rad], fill=col + (alpha,))
        img.alpha_composite(lay)

# ═════════════════════════════════════════════════════════════════════════════
#  CHESS
# ═════════════════════════════════════════════════════════════════════════════

def draw_chess_board(d, bx, by, sq, light, dark, border):
    bw = sq * 8
    d.rectangle([bx - 4, by - 4, bx + bw + 4, by + bw + 4], fill=border)
    d.rectangle([bx - 2, by - 2, bx + bw + 2, by + bw + 2], fill=(border[0]+30, border[1]+20, border[2]+10))
    for row in range(8):
        for col in range(8):
            c = light if (row + col) % 2 == 0 else dark
            d.rectangle([bx + col*sq, by + row*sq, bx + col*sq + sq - 1, by + row*sq + sq - 1], fill=c)

def draw_chess_piece_shape(d, cx, bot, s, piece_type, white):
    body = (250, 242, 225) if white else (35, 25, 15)
    rim  = (165, 120, 55) if white else (190, 150, 90)
    hw = s * 28 // 100

    if piece_type == "pawn":
        d.ellipse([cx - hw, bot - s*70//100, cx + hw, bot - s*35//100], fill=rim)
        d.ellipse([cx - hw+1, bot - s*69//100, cx + hw-1, bot - s*36//100], fill=body)
        d.rectangle([cx - hw-2, bot - s*20//100, cx + hw+2, bot], fill=rim)
        d.rectangle([cx - hw-1, bot - s*19//100, cx + hw+1, bot-1], fill=body)
    elif piece_type == "rook":
        bw = s * 30 // 100
        d.rectangle([cx - bw, bot - s*70//100, cx + bw, bot], fill=rim)
        d.rectangle([cx - bw+1, bot - s*69//100, cx + bw-1, bot-1], fill=body)
        tw = bw // 3
        for off in [-bw, 0, bw - tw]:
            d.rectangle([cx + off, bot - s*82//100, cx + off + tw, bot - s*68//100], fill=rim)
            d.rectangle([cx + off+1, bot - s*81//100, cx + off + tw-1, bot - s*69//100], fill=body)
    elif piece_type == "knight":
        bw = s * 26 // 100
        d.rectangle([cx - bw-2, bot - s*65//100, cx + bw+2, bot], fill=rim)
        d.rectangle([cx - bw-1, bot - s*64//100, cx + bw+1, bot-1], fill=body)
        d.ellipse([cx - bw, bot - s*90//100, cx + bw + s*15//100, bot - s*50//100], fill=rim)
        d.ellipse([cx - bw+1, bot - s*89//100, cx + bw + s*14//100, bot - s*51//100], fill=body)
    elif piece_type == "bishop":
        bw = s * 24 // 100
        d.ellipse([cx - bw-2, bot - s*70//100, cx + bw+2, bot - s*10//100], fill=rim)
        d.ellipse([cx - bw-1, bot - s*69//100, cx + bw+1, bot - s*11//100], fill=body)
        d.ellipse([cx - s*8//100, bot - s*85//100, cx + s*8//100, bot - s*70//100], fill=rim)
        d.rectangle([cx - bw-3, bot - s*15//100, cx + bw+3, bot], fill=rim)
        d.rectangle([cx - bw-2, bot - s*14//100, cx + bw+2, bot-1], fill=body)
    elif piece_type == "queen":
        bw = s * 32 // 100
        d.rectangle([cx - bw, bot - s*68//100, cx + bw, bot], fill=rim)
        d.rectangle([cx - bw+1, bot - s*67//100, cx + bw-1, bot-1], fill=body)
        for off in [-bw+2, 0, bw-2]:
            d.ellipse([cx + off - s*7//100, bot - s*85//100, cx + off + s*7//100, bot - s*65//100], fill=rim)
            d.ellipse([cx + off - s*5//100, bot - s*83//100, cx + off + s*5//100, bot - s*67//100],
                     fill=(255, 215, 60) if white else (200, 170, 50))
    elif piece_type == "king":
        bw = s * 32 // 100
        d.rectangle([cx - bw, bot - s*68//100, cx + bw, bot], fill=rim)
        d.rectangle([cx - bw+1, bot - s*67//100, cx + bw-1, bot-1], fill=body)
        cross_c = (255, 215, 30)
        d.rectangle([cx - 2, bot - s*92//100, cx + 2, bot - s*65//100], fill=cross_c)
        d.rectangle([cx - s*10//100, bot - s*86//100, cx + s*10//100, bot - s*80//100], fill=cross_c)


print("=== CHESS ===")

# Launcher icon 40x40
img = Image.new("RGBA", (40, 40), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
light = (220, 185, 130); dark = (100, 65, 35); border = (60, 38, 18)
draw_chess_board(d, 1, 1, 5, light, dark, border)
draw_chess_piece_shape(d, 12, 22, 16, "queen", True)
draw_chess_piece_shape(d, 28, 22, 16, "king", False)
img = circle_crop(img)
save(img, os.path.join(ROOT, "chess", "resources", "launcher_icon.png"))

# Store icon 200x200
img = Image.new("RGBA", (200, 200), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
gradient_bg(d, 200, 200, (18, 12, 6), (8, 5, 2))
draw_chess_board(d, 12, 40, 22, light, dark, border)
draw_chess_piece_shape(d, 60, 105, 50, "queen", True)
draw_chess_piece_shape(d, 140, 105, 50, "king", False)
fnt = get_font(20)
d.text((100, 10), "CHESS", font=fnt, fill=(255, 215, 80), anchor="mt")
d.text((100, 186), "Bitochi", font=get_font(14), fill=(160, 140, 100), anchor="mt")
img = circle_crop(img)
save(img, os.path.join(BASE, "chess", "store_icon.png"))

# Hero 1440x720
img = Image.new("RGBA", (1440, 720))
d = ImageDraw.Draw(img)
gradient_bg(d, 1440, 720, (14, 10, 5), (6, 4, 2))

# Vignette glow
glow_circle(img, 720, 360, 180, (40, 30, 15), layers=12)

SQ = 72; bx = 720 - SQ*4; by = 60
draw_chess_board(d, bx, by, SQ, (220, 185, 130), (100, 65, 35), (60, 38, 18))

# Draw pieces on the board for a mid-game look
positions = [
    (0, 7, "rook", True), (7, 7, "rook", True), (4, 7, "king", True),
    (3, 6, "queen", True),
    (1, 6, "pawn", True), (2, 5, "pawn", True), (5, 6, "pawn", True), (6, 6, "pawn", True),
    (2, 3, "knight", True), (5, 4, "bishop", True),
    (0, 0, "rook", False), (7, 0, "rook", False), (4, 0, "king", False),
    (3, 1, "queen", False),
    (1, 1, "pawn", False), (4, 2, "pawn", False), (5, 1, "pawn", False), (6, 1, "pawn", False),
    (6, 2, "knight", False), (2, 0, "bishop", False),
]
for (col, row, ptype, white) in positions:
    px = bx + col * SQ + SQ // 2
    py = by + row * SQ + SQ - 2
    draw_chess_piece_shape(d, px, py, SQ, ptype, white)

# Title
tf = get_font(84)
sf = get_font(36)
sf2 = get_font(24)
d.text((722, 640), "BITOCHI CHESS", font=tf, fill=(0, 0, 0, 180), anchor="mt")
d.text((720, 638), "BITOCHI CHESS", font=tf, fill=(255, 220, 90), anchor="mt")
d.text((720, 688), "Play chess vs AI  ·  Easy / Normal / Hard", font=sf2, fill=(160, 140, 100), anchor="mt")

save(img.convert("RGB"), os.path.join(BASE, "chess_hero.png"))

# ═════════════════════════════════════════════════════════════════════════════
#  CHECKERS
# ═════════════════════════════════════════════════════════════════════════════

def draw_checker_piece(d, cx, cy, r, white, king=False):
    d.ellipse([cx-r+1, cy-r+2, cx+r+1, cy+r+2], fill=(0, 0, 0, 100))
    ring = (200, 150, 70) if white else (160, 30, 0)
    d.ellipse([cx-r, cy-r, cx+r, cy+r], fill=ring)
    body = (245, 225, 180) if white else (190, 48, 16)
    d.ellipse([cx-r+2, cy-r+2, cx+r-2, cy+r-2], fill=body)
    hi = (255, 248, 230, 130) if white else (240, 100, 70, 110)
    d.ellipse([cx-r//2, cy-r+2, cx+r//4, cy-r//4], fill=hi)
    if king:
        s = r * 50 // 100
        crown_c = (255, 215, 30)
        d.rectangle([cx - s, cy - s//4, cx + s, cy + s*3//4], fill=crown_c)
        for off in [-s, 0, s]:
            pk = s * 65 // 100
            d.polygon([(cx + off - s//3, cy - s//4), (cx + off, cy - s), (cx + off + s//3, cy - s//4)],
                     fill=crown_c)


print("\n=== CHECKERS ===")

# Launcher icon 40x40
img = Image.new("RGBA", (40, 40), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
light = (195, 160, 100); dark = (100, 55, 25); border = (55, 30, 12)
draw_chess_board(d, 1, 1, 5, light, dark, border)
draw_checker_piece(d, 13, 13, 6, False, king=True)
draw_checker_piece(d, 28, 28, 6, True)
img = circle_crop(img)
save(img, os.path.join(ROOT, "checkers", "resources", "launcher_icon.png"))

# Store icon 200x200
img = Image.new("RGBA", (200, 200), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
gradient_bg(d, 200, 200, (16, 10, 4), (8, 5, 2))
draw_chess_board(d, 12, 40, 22, light, dark, border)
draw_checker_piece(d, 65, 90, 22, False, king=True)
draw_checker_piece(d, 135, 130, 22, True)
fnt = get_font(18)
d.text((100, 10), "CHECKERS", font=fnt, fill=(255, 110, 50), anchor="mt")
d.text((100, 186), "Bitochi", font=get_font(14), fill=(160, 130, 90), anchor="mt")
img = circle_crop(img)
save(img, os.path.join(BASE, "checkers", "store_icon.png"))

# Hero 1440x720
img = Image.new("RGBA", (1440, 720))
d = ImageDraw.Draw(img)
gradient_bg(d, 1440, 720, (12, 8, 3), (5, 3, 1))
glow_circle(img, 720, 340, 160, (35, 20, 8), layers=12)

SQ = 72; bx = 720 - SQ*4; by = 40
draw_chess_board(d, bx, by, SQ, (195, 160, 100), (100, 55, 25), (55, 30, 12))

# Checkers starting position
for row in range(8):
    for col in range(8):
        if (row + col) % 2 != 1: continue
        px = bx + col * SQ + SQ // 2
        py = by + row * SQ + SQ // 2
        if row < 3:
            draw_checker_piece(d, px, py, SQ * 35 // 100, False)
        elif row > 4:
            draw_checker_piece(d, px, py, SQ * 35 // 100, True)

# Add a king piece prominently
draw_checker_piece(d, bx + 3 * SQ + SQ//2, by + 4 * SQ + SQ//2, SQ * 35 // 100, False, king=True)
draw_checker_piece(d, bx + 4 * SQ + SQ//2, by + 3 * SQ + SQ//2, SQ * 35 // 100, True, king=True)

tf = get_font(84)
sf2 = get_font(24)
d.text((722, 630), "BITOCHI CHECKERS", font=tf, fill=(0, 0, 0, 180), anchor="mt")
d.text((720, 628), "BITOCHI CHECKERS", font=tf, fill=(255, 110, 50), anchor="mt")
d.text((720, 678), "Play checkers vs AI  ·  Easy / Normal / Hard", font=sf2, fill=(160, 130, 90), anchor="mt")

save(img.convert("RGB"), os.path.join(BASE, "checkers_hero.png"))

# ═════════════════════════════════════════════════════════════════════════════
#  FAKE NOTIFICATION ESCAPE
# ═════════════════════════════════════════════════════════════════════════════

def draw_notif_card(d, x, y, w, h, accent, title, msg, time="9:41"):
    d.rounded_rectangle([x, y, x+w, y+h], radius=8, fill=(22, 22, 28))
    d.rounded_rectangle([x+1, y+1, x+w-1, y+h-1], radius=7, fill=(30, 32, 38))
    d.rectangle([x, y, x+w, y+4], fill=accent)
    fnt_s = get_font(max(h//6, 10))
    fnt_t = get_font(max(h//8, 8))
    d.text((x + 12, y + 10), title, font=fnt_s, fill=accent)
    d.text((x + w - 12, y + 10), time, font=fnt_t, fill=(80, 80, 90), anchor="rt")
    d.text((x + 12, y + h//2 - 4), msg, font=fnt_t, fill=(160, 165, 175))


print("\n=== FAKE NOTIFICATION ESCAPE ===")

GREEN  = (30, 185, 85)
BLUE   = (0, 132, 255)
WAPP   = (37, 211, 102)
RED    = (255, 59, 48)
PURPLE = (97, 31, 105)
TELE   = (44, 165, 224)

# Launcher icon 40x40
img = Image.new("RGBA", (40, 40), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
for y in range(40):
    t = y / 39
    r = int(8 + t * 6)
    g = int(10 + t * 8)
    b = int(18 + t * 14)
    d.line([(0, y), (39, y)], fill=(r, g, b, 255))

# Phone icon
d.rounded_rectangle([12, 4, 28, 36], radius=3, fill=(40, 44, 52))
d.rectangle([14, 8, 26, 30], fill=(20, 22, 26))
d.rectangle([14, 8, 26, 11], fill=GREEN[:3])
d.rounded_rectangle([8, 14, 32, 22], radius=2, fill=(30, 34, 42))
d.rectangle([10, 15, 30, 15], fill=BLUE[:3])
d.ellipse([17, 31, 23, 35], fill=(60, 65, 75))

# Notification dot
d.ellipse([27, 2, 35, 10], fill=(255, 60, 50))
d.ellipse([29, 4, 33, 8], fill=(255, 120, 110))

img = circle_crop(img)
save(img, os.path.join(ROOT, "fakenotificationescape", "resources", "launcher_icon.png"))

# Store icon 200x200
img = Image.new("RGBA", (200, 200), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
gradient_bg(d, 200, 200, (10, 12, 22), (5, 6, 14))

# Phone silhouette
d.rounded_rectangle([60, 20, 140, 170], radius=12, fill=(35, 38, 48))
d.rectangle([66, 32, 134, 155], fill=(18, 20, 26))

# Stacked notifications
cards = [(GREEN, "CALL"), (BLUE, "SMS"), (WAPP, "WhatsApp"), (RED, "PagerDuty")]
for i, (col, label) in enumerate(cards):
    cy = 38 + i * 30
    d.rounded_rectangle([70, cy, 130, cy + 26], radius=4, fill=(28, 30, 36))
    d.rectangle([70, cy, 130, cy + 3], fill=col)
    fnt = get_font(10)
    d.text((75, cy + 9), label, font=fnt, fill=col)

# Alert badge
d.ellipse([125, 12, 155, 42], fill=(255, 50, 40))
fnt = get_font(18)
d.text((140, 20), "!", font=fnt, fill=(255, 255, 255), anchor="mt")

fnt = get_font(16)
d.text((100, 178), "ESCAPE KIT", font=fnt, fill=(200, 210, 225), anchor="mt")

img = circle_crop(img)
save(img, os.path.join(BASE, "fakenotificationescape", "store_icon.png"))

# Hero 1440x720
img = Image.new("RGBA", (1440, 720))
d = ImageDraw.Draw(img)
gradient_bg(d, 1440, 720, (8, 10, 20), (3, 4, 10))

# Subtle grid pattern
for x in range(0, 1440, 40):
    d.line([(x, 0), (x, 720)], fill=(20, 22, 30))
for y in range(0, 720, 40):
    d.line([(0, y), (1440, y)], fill=(20, 22, 30))

glow_circle(img, 720, 300, 200, (15, 25, 50), layers=10)

# Phone mockup (centre)
px, py, pw, ph = 600, 60, 240, 460
d.rounded_rectangle([px-2, py-2, px+pw+2, py+ph+2], radius=22, fill=(55, 60, 70))
d.rounded_rectangle([px, py, px+pw, py+ph], radius=20, fill=(20, 22, 28))
d.rectangle([px+8, py+30, px+pw-8, py+ph-30], fill=(12, 14, 18))

# Notification cards on phone
notifs = [
    (GREEN,  "Incoming Call",    "Mom — ringing..."),
    (BLUE,   "Messages",         "Boss — Call me ASAP!"),
    (WAPP,   "WhatsApp",         "Work Group — Come NOW!"),
    (RED,    "PagerDuty",        "SEV-1 — Production DOWN"),
    (TELE,   "Telegram",         "DevOps — Server is DOWN"),
    (PURPLE, "Slack",            "#incidents — Check alert"),
    ((0,132,255), "Messenger",   "Mom — Are you there?"),
]
for i, (col, title, msg) in enumerate(notifs):
    ny = py + 40 + i * 56
    if ny + 48 > py + ph - 35: break
    draw_notif_card(d, px + 14, ny, pw - 28, 48, col, title, msg)

# Floating notification cards (sides)
side_notifs = [
    (140, 120, 280, 70, GREEN, "INCOMING CALL", "Unknown — Answer now"),
    (1020, 180, 280, 70, RED, "PAGERDUTY", "P0-CRITICAL — API failure"),
    (100, 420, 260, 65, WAPP, "WhatsApp", "Family — Need help!!"),
    (1060, 400, 260, 65, TELE, "Telegram", "Monitor Bot — DB unreachable"),
    (160, 560, 240, 60, BLUE, "SMS", "Bank Alert — Package arrived"),
    (1040, 540, 260, 60, PURPLE, "Slack", "#dev-ops — Deploy in 5min"),
]
for (sx, sy, sw, sh, col, title, msg) in side_notifs:
    lay = Image.new("RGBA", (1440, 720), (0, 0, 0, 0))
    ld = ImageDraw.Draw(lay)
    ld.rounded_rectangle([sx, sy, sx+sw, sy+sh], radius=8, fill=(22, 24, 32, 220))
    ld.rectangle([sx, sy, sx+sw, sy+4], fill=col + (220,))
    fnt_s = get_font(16)
    fnt_t = get_font(13)
    ld.text((sx + 12, sy + 10), title, font=fnt_s, fill=col + (240,))
    ld.text((sx + 12, sy + 32), msg, font=fnt_t, fill=(140, 145, 155, 200))
    img.alpha_composite(lay)

# Title
tf = get_font(72)
sf = get_font(30)
d2 = ImageDraw.Draw(img)
d2.text((722, 608), "FAKE NOTIFICATION", font=tf, fill=(0, 0, 0, 160), anchor="mt")
d2.text((720, 606), "FAKE NOTIFICATION", font=tf, fill=(220, 230, 245), anchor="mt")
d2.text((722, 662), "ESCAPE KIT", font=sf, fill=(0, 0, 0, 140), anchor="mt")
d2.text((720, 660), "ESCAPE KIT", font=sf, fill=(30, 185, 85), anchor="mt")
d2.text((720, 698), "Call  ·  SMS  ·  WhatsApp  ·  Email  ·  Telegram  ·  PagerDuty  ·  Slack  ·  Messenger",
        font=get_font(16), fill=(100, 110, 130), anchor="mt")

save(img.convert("RGB"), os.path.join(BASE, "fakenotificationescape", "fakenotificationescape_hero.png"))

# Also save launcher to the fakenotificationescape subfolder
save(circle_crop(Image.open(os.path.join(ROOT, "fakenotificationescape", "resources", "launcher_icon.png")).copy()),
     os.path.join(BASE, "fakenotificationescape", "launcher_icon.png"))

print("\nAll done!")
