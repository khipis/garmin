#!/usr/bin/env python3
"""Generate the Cell Wars launcher icon (70x70 px).

Visual concept: dark background, a 10x10 mini cellular grid with
colourful glowing pixels arranged to suggest algorithmic territory battle.
"""

from PIL import Image, ImageDraw, ImageFont
import math, random, os

SZ = 70
OUT_ICON = os.path.join(os.path.dirname(__file__), "../cellwars/resources/launcher_icon.png")

random.seed(42)

img = Image.new("RGBA", (SZ, SZ), (0, 0, 0, 255))
draw = ImageDraw.Draw(img)

# Background radial glow
for r in range(SZ // 2, 0, -1):
    alpha = int(30 * (1 - r / (SZ / 2)))
    draw.ellipse([SZ//2 - r, SZ//2 - r, SZ//2 + r, SZ//2 + r],
                 fill=(20, 10, 40, alpha))

# ── Mini grid 10x10 at centre ────────────────────────────────────────────────
GCELLS = 10
CELL   = 5
GSIZE  = GCELLS * CELL
GOX    = (SZ - GSIZE) // 2
GOY    = (SZ - GSIZE) // 2

# Team colour palettes  (NEON theme)
TEAM_COLS = [
    (0x00, 0xEE, 0xFF),   # cyan    – Conway
    (0xFF, 0x66, 0x00),   # orange  – HighLife
    (0xCC, 0x22, 0xFF),   # purple  – Day&Night
    (0x00, 0xFF, 0x88),   # green   – Maze
]

# Simulate a few Battle steps from a seeded random start
NTEAMS = 4
grid = [[0]*GCELLS for _ in range(GCELLS)]
for y in range(GCELLS):
    for x in range(GCELLS):
        if random.random() < 0.48:
            grid[y][x] = random.randint(1, NTEAMS)

def step_battle(g):
    nxt = [[0]*GCELLS for _ in range(GCELLS)]
    for y in range(GCELLS):
        for x in range(GCELLS):
            counts = [0]*NTEAMS
            total  = 0
            for dy in range(-1, 2):
                for dx in range(-1, 2):
                    if dx == 0 and dy == 0: continue
                    ny, nx = y+dy, x+dx
                    if 0 <= ny < GCELLS and 0 <= nx < GCELLS:
                        c = g[ny][nx]
                        if c > 0:
                            total += 1
                            counts[c-1] += 1
            c = g[y][x]
            if c > 0:
                nxt[y][x] = c if total in (2, 3) else 0
            else:
                if total == 3:
                    best = max(range(NTEAMS), key=lambda t: counts[t])
                    nxt[y][x] = best + 1 if counts[best] > 0 else 0
    return nxt

for _ in range(12):
    grid = step_battle(grid)

# Draw the mini grid cells with glow
for y in range(GCELLS):
    for x in range(GCELLS):
        c = grid[y][x]
        if c == 0: continue
        col = TEAM_COLS[c - 1]
        px = GOX + x * CELL
        py = GOY + y * CELL
        # Glow halo
        gc = tuple(min(255, v//2) for v in col)
        draw.rectangle([px-1, py-1, px+CELL, py+CELL], fill=gc + (80,))
        # Cell
        draw.rectangle([px, py, px+CELL-1, py+CELL-1], fill=col + (255,))

# Draw subtle outer circle border
draw.ellipse([2, 2, SZ-3, SZ-3], outline=(60, 60, 80, 200), width=1)

# "CW" text overlay at bottom
try:
    font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 12)
except Exception:
    font = ImageFont.load_default()

draw.text((SZ//2, SZ - 10), "CW", font=font, fill=(200, 200, 220, 220), anchor="mm")

os.makedirs(os.path.dirname(os.path.abspath(OUT_ICON)), exist_ok=True)
img.save(OUT_ICON, "PNG")
print(f"Icon saved → {OUT_ICON}")
