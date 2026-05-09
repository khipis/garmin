# Tic Tac Pro

A 5×5 Tic-Tac-Toe variant for round Garmin watches where you need **4 in a row** to win.

## Gameplay

- You play as **X** (blue), the AI plays as **O** (red-orange).
- Place four marks in a row — horizontally, vertically, or diagonally — to win.
- If all 25 cells are filled without a winner, the game ends in a draw.
- The session score (X wins : O wins) persists across games until you exit.

## Controls

| Input | Action |
|-------|--------|
| UP button | Move cursor up |
| DOWN button | Move cursor down |
| PAGE UP / left scroll | Move cursor left |
| PAGE DOWN / right scroll | Move cursor right |
| SELECT | Place your mark |
| SELECT _(game over)_ | Start a new game |
| BACK | Exit to watch menu |

The cursor is **yellow** on empty cells and **orange** on occupied cells (can't place there).

## Win Condition

Four connected marks in a straight line in any of eight directions.  
When the game ends, the winning line is highlighted in **green**.

## AI Strategy

The AI follows a three-level priority hierarchy:

1. **Win** — if the AI can complete 4 in a row, it does so immediately.
2. **Block** — if the player is one move away from winning, the AI blocks it.
3. **Heuristic fallback** — when neither threat exists, the AI scores every empty cell:
   - Centre preference (closer to the centre = higher score).
   - Line-extension bonus: rewards moves that lengthen existing O lines  
     (3-in-a-row bonus ≫ 2-in-a-row ≫ 1-in-a-row, in all four axes).
   - Small random noise breaks exact ties for variety.

The heuristic naturally creates **forks** (two simultaneous 3-in-a-row threats) because a move that scores high on two axes at once receives additive bonuses.

## Visual Style

| Element | Colour |
|---------|--------|
| Background | Very dark navy `#080810` |
| Grid lines | Medium slate `#3A3A5A` |
| X marks | Bright blue `#00AAFF` |
| O marks | Red-orange `#FF4422` |
| Cursor (empty cell) | Yellow `#FFFF00` |
| Cursor (occupied) | Orange `#FF6600` |
| Winning line | Bright green `#00FF44` |

## Grid Size

The game ships as a **5×5** board. To switch to a **7×7** board (still 4 in a row),
change the single constant at the top of `source/GameView.mc`:

```monkeyc
const GRID_N = 7;   // 7×7 board
```

The rendering and AI both derive all dimensions from `GRID_N`, so no other changes
are needed.

## Technical Notes

### Win detection — O(N × (N−W)) per call
`_checkWin(col)` scans all axis-aligned windows of length `WIN_LEN` across the grid.
For a 5×5/W=4 board that is 28 windows; for 7×7 it is 88 windows — negligible on any
hardware.

When a win is found, the four winning cell indices are written to `_winLine[0..3]` so
the renderer can draw the highlight line and the victory overlay without a second pass.

### AI — zero heap allocations
`_findThreat` and `_bestScoredMove` iterate over the flat `int[25]` cells array.
Temporary placements in `_findThreat` are applied and immediately rolled back in-place:
no auxiliary arrays or objects are created.

`_axisScore` counts consecutive friendly marks in both directions along an axis using
simple pointer arithmetic on the flat array; early exit once a gap is found.

### AI "thinking" delay
After the player places a mark the state transitions to `GS_AI`.
A 300 ms repeating timer fires and executes the AI on the next tick.
This gives the player a moment to see their own move before the AI responds and keeps
the UI feeling natural without blocking the watch UI thread.

### Memory footprint
- `_cells`  — `int[25]`  (100 bytes on 32-bit platforms)
- `_winLine` — `int[4]`   (16 bytes)
- One `Timer.Timer` instance
- No animation buffers, no particle arrays

## Files

```
tic_tac_pro/
├── source/
│   ├── TicTacProApp.mc      Application entry point
│   ├── GameDelegate.mc      Input routing
│   └── GameView.mc          All game logic, AI, and rendering
├── resources/
│   ├── launcher_icon.png    70×70 round icon
│   ├── drawables.xml
│   └── strings.xml
├── manifest.xml
└── monkey.jungle
```

## Build

```bash
# From the garmin workspace root:
bash _build_all.sh tic_tac_pro

# Or manually:
monkeyc -o _PROD/tic_tac_pro.prg -f tic_tac_pro/monkey.jungle \
        -y developer_key.der -d fenix8solar51mm -l 0
```
