# Hex Mini

A Hex board game for round Garmin watches. Connect your two opposite sides of a
**7×7** parallelogram grid before the AI does.

## Rules

Hex is a two-player connection game invented by Piet Hein (1942) and John Nash (1948).

| Colour | Player | Objective |
|--------|--------|-----------|
| **Red** | You | Connect the **left** edge (column 0) to the **right** edge (column 6) |
| **Blue** | AI | Connect the **top** edge (row 0) to the **bottom** edge (row 6) |

Players alternate placing one stone per turn on any empty cell. The first player
to complete a connected path of their colour across the board wins.

> **Hex can never end in a draw.** This is a mathematical theorem: once the board
> is full, exactly one player has a connected path.

## Controls

| Input | Action |
|-------|--------|
| UP button | Move cursor one row up |
| DOWN button | Move cursor one row down |
| PAGE UP / left scroll | Move cursor one column left |
| PAGE DOWN / right scroll | Move cursor one column right |
| SELECT / tap | Place a Red stone on the cursor cell |
| SELECT _(game over)_ | Start a new game |
| BACK | Exit to watch menu |

The cursor highlights **yellow** on empty cells and **orange** on occupied cells.
A bright centre dot marks the last stone placed by either player.

## Board Layout

The board is a parallelogram rendered as offset circles (offset hex grid):

```
Row 0:  ○─○─○─○─○─○─○
Row 1:   ○─○─○─○─○─○─○
Row 2:    ○─○─○─○─○─○─○
...
Row 6:          ○─○─○─○─○─○─○
```

Each cell has **6 hex neighbours**: `(r-1,c), (r-1,c+1), (r,c-1), (r,c+1), (r+1,c-1), (r+1,c)`.

**Edge markers:** small coloured dots appear just outside each edge to indicate which
player owns which pair of sides (Red = left/right dots, Blue = top/bottom dots).  
**Direction hints:** `YOU<>` (Red, left-right) and `AI^v` (Blue, top-bottom) are shown
below the board for quick reference.

## AI Strategy

The AI uses **random play with centre bias**:

- For every empty cell the AI computes a score = `(N − |r − mid| − |c − mid|) × 3 + noise(0–4)`.
- The centre cell (3, 3) receives the highest score; cells further from centre score less.
- Small random noise breaks exact ties to add variety.

The centre of a Hex board is strategically dominant (it lies on many potential paths for
both players), so a centre-biased AI provides a reasonable challenge without lookahead.

## Technical Notes

### BFS win check — O(N²) per call with generation counter

`_checkWin(mark)` runs a BFS seeded from the mark's starting edge:
- **Player** (HM_P): seeds from all Red stones in column 0; wins on reaching column 6.
- **AI** (HM_AI): seeds from all Blue stones in row 0; wins on reaching row 6.

The `_bfsVis` array uses a **monotonic generation counter** (`_bfsGen`) so it never
needs to be cleared between calls — a cell is considered visited when
`_bfsVis[idx] == _bfsGen`. This makes each BFS call O(board_cells) instead of
O(board_cells + clear_cost).

Both `_bfsQueue[49]` and `_bfsVis[49]` are pre-allocated in `initialize()`;
no heap allocation occurs during the win check.

### Zero-allocation game loop

- `_cells[49]` — flat int array, row-major
- `_bfsQueue[49]`, `_bfsVis[49]` — pre-allocated BFS buffers
- `_bfsQi`, `_bfsQo` — instance variables (write pointer shared between
  `_checkWin` and `_bfsVisit` without parameter passing)

### Rendering

`onUpdate` runs only on move events (turn-based, not continuous 30 fps).  
Per frame: ≈ 147 grid-line draws + 49 stone fills + 28 edge-band dots + cursor rings.  
All geometry is computed from `_cx(r, c)` / `_cy(r, c)` helper functions:

```
cellX(r, c) = boardX + c * dx + r * (dx / 2)    ← row r offset by r*(dx/2)
cellY(r, c) = boardY + r * dy
```

`dx` and `dy` scale with screen width, so the board fits correctly on all supported
round Garmin watches (260 px to 416 px diameter).

## Files

```
hex_mini/
├── source/
│   ├── HexMiniApp.mc      Application entry point
│   ├── GameDelegate.mc    Input routing
│   └── GameView.mc        All game logic, BFS win check, AI, and rendering
├── resources/
│   ├── launcher_icon.png  70×70 round icon
│   ├── drawables.xml
│   └── strings.xml
├── manifest.xml
└── monkey.jungle
```

## Build

```bash
# From the garmin workspace root:
bash _build_all.sh hex_mini

# Or manually:
monkeyc -o _PROD/hex_mini.prg -f hex_mini/monkey.jungle \
        -y developer_key.der -d fenix8solar51mm -l 0
```
