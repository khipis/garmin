# Dots & Boxes — Garmin Connect IQ

A classic pencil-and-paper strategy game built for Garmin smartwatches in Monkey C.

---

## Rules

Players alternate drawing lines between adjacent dots on a 5 × 5 grid.  
When a player draws the **fourth side** of a box, they **claim it and take another turn**.  
The player who claims more of the 16 boxes wins.

---

## Board

```
·─·─·─·─·
│ │   │
·─·─·─·─·
│ ▣ │   │
·─·─·─·─·
│   │ ■ │
·─·─·─·─·
│         │
·─·─·─·─·
│   │   │
·─·─·─·─·

  ─  Red   = your line       │ Blue = AI line
  ▣  Red   = your box        ■ Blue = AI box
  ·  Dot   = corner marker   ═ Yellow = cursor
```

- **25 dots** in a 5 × 5 arrangement  
- **40 edges** — 20 horizontal, 20 vertical  
- **16 boxes** to claim (4 × 4)

---

## Controls

| Input | Action |
|-------|--------|
| **UP / DOWN** | Move cursor to adjacent edge above / below |
| **Previous Page / LEFT** | Move cursor to adjacent edge left |
| **Next Page / RIGHT** | Move cursor to adjacent edge right |
| **SELECT** | Draw selected edge; restart after game over |
| **BACK** | Exit to watch face |

The cursor navigates a virtual grid that alternates between horizontal and vertical edges:

- From a **horizontal** edge: UP/DOWN reach vertical edges; LEFT/RIGHT reach horizontal edges in the same row.  
- From a **vertical** edge: LEFT/RIGHT reach horizontal edges; UP/DOWN reach vertical edges in the same column.

A **yellow cursor** means the edge is free; **orange** means it is already drawn (no action taken).

---

## HUD

```
YOU 5        YOUR TURN        4 AI
W:2                           1:W

          (board)

               7 left
```

| Element | Description |
|---------|-------------|
| `YOU n` / `n AI` | Boxes claimed this game |
| `W:n` / `n:W` | Session wins |
| `YOUR TURN` / `AI...` | Whose turn it is |
| `n left` | Boxes still unclaimed |

---

## AI Strategy

The computer uses a **three-priority greedy** approach:

1. **Claim immediately** — if any open edge completes a box, take it.  
   (Repeated until no more boxes are available in one turn.)

2. **Safe move** — if no completion is possible, prefer edges that do not leave any adjacent box at 3 sides (which would gift the opponent a free box).  
   Randomised start over the edge list adds variety each game.

3. **Minimum sacrifice** — if every remaining edge would gift boxes, pick the one that hands the fewest boxes to the opponent.  
   Noise-based tie-breaking prevents deterministic loops.

This strategy captures all low-hanging fruit, avoids obvious traps, and sacrifices gracefully when chains are unavoidable — making the AI competitive without being unbeatable.

---

## Technical Notes

### Zero-allocation game loop
All board state lives in arrays allocated once in `initialize()`:

| Array | Size | Content |
|-------|------|---------|
| `_edges[40]` | 40 × int | `DC_NONE / DC_PLAYER / DC_AI` per edge |
| `_boxes[16]` | 16 × int | owner of each box |
| `_tmpBr[2]`, `_tmpBc[2]` | 2 × int | scratch for adjacent-box lookups |

No heap allocation occurs during gameplay.

### Edge encoding
```
Horizontal h(r, c)  →  index = r × 4 + c,        r ∈ [0..4],  c ∈ [0..3]
Vertical   v(r, c)  →  index = 20 + r × 5 + c,   r ∈ [0..3],  c ∈ [0..4]
```

### Box side lookup
Box `(br, bc)` sides map to:
```
top    = _edges[br×4 + bc]
bottom = _edges[(br+1)×4 + bc]
left   = _edges[20 + br×5 + bc]
right  = _edges[20 + br×5 + bc + 1]
```
Counting 4 drawn sides completes the box (`_sideCount(br, bc) == 4`).

### Timer
A 420 ms `Timer.Timer` fires `gameTick()`.  
During `DBS_AI` state the AI chooses and draws one edge per tick,  
then repeats if it scored (box-chain effect visible on screen).

### Rendering pipeline
Each `onUpdate` call draws 6 layers in order:
1. Black background clear  
2. Box fills (tinted rectangle + centre ownership dot)  
3. Faint guide lines for all 40 potential edge positions  
4. Drawn edges (bright red / blue)  
5. Yellow/orange cursor lines (3-pixel-wide triple line)  
6. Dots (5 × 5 small circles)  
7. HUD text; game-over overlay when finished

---

## Project Layout

```
dots_boxes/
  source/
    DotsBoxesApp.mc   Application entry point
    GameDelegate.mc   Button / D-pad input handler
    GameView.mc       All game logic and rendering (~320 lines)
  resources/
    drawables.xml
    strings.xml
    launcher_icon.png 70 × 70 unique icon (generated)
  manifest.xml        55 supported Garmin products
  monkey.jungle

_LOGOS/
  gen_dotsboxes_icon.py  PIL script → launcher_icon.png
  gen_dotsboxes_hero.py  PIL script → dotsboxes_hero.png (1440 × 720)
```

---

## Building

```bash
# Compile for the simulator
monkeyc -d fenix7 -f monkey.jungle -o _PROD/dots_boxes.prg \
        -y <developer.key>

# Run in simulator
monkeydoit -d fenix7 -f monkey.jungle
```

---

## Store Assets

| Asset | Location |
|-------|----------|
| Launcher icon (70 × 70) | `dots_boxes/resources/launcher_icon.png` |
| Hero image (1440 × 720) | `_LOGOS/dotsboxes_hero.png` |
