# Gobblet Mini — Garmin Connect IQ

A compact adaptation of the classic Gobblet strategy game, built for Garmin smartwatches in Monkey C.

---

## Rules

Players alternate placing or moving pieces on a **4 × 4 grid**.  
**Win** by getting **4 pieces in a row** (row, column, or diagonal) with your *top-visible* pieces.

### Key mechanic — Gobbling

A larger piece can be placed on top of any smaller piece, covering it.  
The hidden piece is **not gone** — it is still in the stack and will be revealed if the covering piece moves away.

**Gobbling is allowed:**
- From hand onto any smaller top piece
- From board piece onto any smaller top piece (on a different cell)

### Piece inventory

Each player starts with **12 pieces**: 3 of each of 4 sizes (tiny → small → medium → large).  
Once a hand piece is played it is on the board; you can still move it, but never return it to hand.

---

## Board & Sizing

```
┌────┬────┬────┬────┐
│ ● ●│  ○ │  ○ │ ● ●│   ● = AI  (Blue)
├────┼────┼────┼────┤   ○ = YOU (Red)
│  ○ │ ● ●│    │ ●  │
├────┼────┼────┼────┤   ● ● = large piece covering smaller
│ ●  │  ○ │ ●  │  ○ │
├────┼────┼────┼────┤   Small digit at top-left of cell
│  ○ │    │  ●●│  ○ │   = number of stacked pieces (≥2)
└────┴────┴────┴────┘
```

- **4 × 4 grid** = 16 cells
- Pieces sized **1 (smallest) → 4 (largest)**; drawn as circles with nested rings
- Stack depth displayed as a digit (e.g. `2`) in the cell corner

---

## Controls

| Input | Phase | Action |
|-------|-------|--------|
| **UP / DOWN** | Browse / Destination | Move grid cursor row |
| **◀ Prev Page / LEFT** | Browse / Destination | Move grid cursor left; cycle size picker left |
| **▶ Next Page / RIGHT** | Browse / Destination | Move grid cursor right; cycle size picker right |
| **SELECT** on own board piece | Browse | Pick up piece → destination phase |
| **SELECT** on empty / enemy cell | Browse | Open size picker overlay |
| **◀ ▶** | Size picker | Cycle available hand sizes |
| **SELECT** | Size picker | Confirm size → destination phase |
| **SELECT** | Destination | Place / move piece (green cursor = valid) |
| **SELECT** (same source cell) | Destination | Cancel move |
| **BACK** | Size picker / Destination | Cancel, return to browse |
| **SELECT** | Game over | Start a new game |

### Cursor colours

| Colour | Meaning |
|--------|---------|
| Yellow | Own board piece — can pick up |
| Grey | Navigation (no action) |
| Green | Valid destination — can place/move here |
| Orange | Same cell as source — tap to cancel |
| Dark red | Invalid destination — piece too small |

---

## HUD

```
W:2        YOUR TURN        1:W
 ○1 ○2 ○3 ○4     ← player hand (size → count)
 
       [4×4 board]

 ●1 ●2 ●3 ●4     ← AI hand (size → count)
```

Dim icon = no more pieces of that size remaining.

---

## AI Strategy

The AI evaluates every legal move (place from hand + board-to-board moves) with a **one-ply lookahead**, scoring each resulting position:

| Priority | Condition | Score |
|----------|-----------|-------|
| Immediate win | AI gets 4 in a row | +10 000 |
| Avoid own loss | Move reveals player's 4-in-a-row | −9 000 |
| AI progress | Lines with AI pieces only: count² | positive |
| Player threat | Lines with player pieces only: count² × 2 | negative |
| Near-win block | Player has 3-in-a-line, no AI piece | −80 extra |

Larger hand pieces are tried first; the highest-scoring move wins.

---

## Technical Notes

### Zero-allocation loop

All board state is pre-allocated in `initialize()`:

| Array | Size | Content |
|-------|------|---------|
| `_stack[64]` | 64 × int | `cell * GSIZES + stackDepth` → piece value 1–8 (0 = empty) |
| `_depth[16]` | 16 × int | Stack depth per cell |
| `_ph[4]`, `_aih[4]` | 4 × int each | Hand piece counts by size-index |
| `_lines[40]` | 40 × int | 10 win-check lines × 4 cell indices |
| `_psz[4]`, `_hpsz[4]` | 4 × int each | Piece radii (board and HUD strip) |

No heap allocation occurs during gameplay.

### Piece encoding

```
value v = (owner − 1) × 4 + size     (1 ≤ v ≤ 8,  0 = empty)

owner = (v − 1) / 4 + 1              (1=player, 2=AI)
size  = (v − 1) % 4 + 1              (1=tiny … 4=large)
```

### Stack semantics and undo

`_place(val, cell)` pushes onto `_stack[cell*4 + depth]` and increments `_depth[cell]`.  
`_pop(cell)` decrements `_depth[cell]` and returns the value — the previously covered piece
is automatically restored as the new top.  
AI move simulation uses push → evaluate → pop to undo without extra buffers.

### Timer

A 500 ms `Timer.Timer` fires `gameTick()`.  
During `GMS_AI` state the timer executes one AI turn, evaluates win conditions, then hands control back to the player.

### Rendering pipeline

Each `onUpdate` draws 5–7 layers:
1. Background clear
2. Grid lines
3. Board-source highlight (yellow rect) + valid-destination corner dots
4. Top-visible piece per cell (halo → colour circle → inner ring)
5. Stack-depth digit (if > 1)
6. Cursor (coloured rectangle + corner ticks)
7. HUD (session wins, turn text, player/AI hand strips)
8. Size-picker overlay (when active)
9. Game-over overlay (when finished)

---

## Project Layout

```
gobblet_mini/
  source/
    GobbletMiniApp.mc   Application entry point
    GameDelegate.mc     Input handler
    GameView.mc         All game logic and rendering (~420 lines)
  resources/
    drawables.xml
    strings.xml
    launcher_icon.png   70 × 70 icon (generated)
  manifest.xml          55 Garmin products
  monkey.jungle

_LOGOS/
  gen_gobblet_icon.py   PIL → launcher_icon.png
  gen_gobblet_hero.py   PIL → gobblet_hero.png (1440 × 720)
```

---

## Building

```bash
monkeyc -d fenix7 -f monkey.jungle -o _PROD/gobblet_mini.prg \
        -y <developer.key>
```

---

## Store Assets

| Asset | Path |
|-------|------|
| Launcher icon (70 × 70) | `gobblet_mini/resources/launcher_icon.png` |
| Hero image (1440 × 720) | `_LOGOS/gobblet_hero.png` |
