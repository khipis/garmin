# Connect Four Lite

A classic Connect Four game for round Garmin watches. Drop coloured discs into a
**7×6** grid and connect **4 in a row** — before the AI does.

## Gameplay

- You play as **Red**, the AI plays as **Yellow**.
- Select a column with LEFT/RIGHT, then drop your disc with SELECT.
- Discs fall by gravity to the lowest empty row.
- First to connect 4 in a row — horizontally, vertically, or diagonally — wins.
- A draw is declared when all 42 cells are filled.
- The session score (YOU : AI) persists across games until you exit.

## Controls

| Input | Action |
|-------|--------|
| UP button / PAGE UP / scroll left | Move column cursor left |
| DOWN button / PAGE DOWN / scroll right | Move column cursor right |
| SELECT / tap | Drop disc into selected column |
| SELECT _(game over)_ | Start a new game |
| BACK | Exit to watch menu |

**Drop preview:** while choosing a column, a ghost outline shows exactly where
your disc will land.  
**Full column:** a dim dot appears above any column that is already full.

## Visual Style

| Element | Colour |
|---------|--------|
| Background | Very dark navy `#060610` |
| Board frame | Dark blue `#0A1850` |
| Empty cells | Very dark `#101028` |
| Player discs | Bright red `#FF2200` |
| AI discs | Golden yellow `#FFCC00` |
| Drop preview | Dark-red fill + red outline |
| Column indicator | Red filled dot with pointer |
| Winning ring | Bright green `#00FF55` |
| Winning line | 6-parallel-line green stroke |

## AI Strategy

Three-level priority system:

1. **Win** — scans all 7 columns; takes the first position that completes 4 in a row.
2. **Block** — scans all 7 columns for the player's immediate winning threat and blocks it.
3. **Heuristic** — scores each valid column:
   - **Centre preference**: column 3 gets the highest bonus; columns further from centre get less.
   - **Line-extension bonus**: temporarily places the disc, counts consecutive same-colour discs in all four axes (horizontal, vertical, ↘, ↙). Lines of 3 score highest, 2 = medium, 1 = small.
   - **Noise**: small random offset (0–3) breaks exact ties for variety.

The heuristic naturally creates strategic threats (e.g., building two simultaneous
3-in-a-row lines) because the additive bonuses reward moves that extend multiple axes
at once.

## Technical Notes

### Win detection — 69 windows scanned
`_checkWin(mark)` tests all length-4 windows across four directions:
- Horizontal: 4 windows × 6 rows = 24
- Vertical:   3 windows × 7 cols = 21
- Diagonal ↘: 4 × 3 = 12
- Diagonal ↙: 4 × 3 = 12

On a win, `_winLine[4]` stores the four winning cell indices so the renderer can draw
the highlight ring and line stroke without a second pass.

### Zero-allocation game loop
- `_cells` — flat `int[42]` array, row-major (row 0 = top)
- `_winLine` — `int[4]`, reused every check
- `_dropRow(col)` — linear scan of at most 6 cells; no intermediate objects
- `_findWinningCol` — temporary cell mutations rolled back in-place
- `_scoreCol` — temporary disc placement and immediate restore; 4 axis scans, no allocations
- Ghost row computation cached once per `onUpdate` (avoids 42 redundant `_dropRow` calls)

### AI latency
After the player drops a disc, `_state` transitions to `GS_AI`.  
The 350 ms repeating timer fires once, executes `_aiDrop()`, then returns to `GS_PLAY`.
This delay lets the player see their disc before the AI responds.

## Files

```
connect_four_lite/
├── source/
│   ├── ConnectFourLiteApp.mc   Application entry point
│   ├── GameDelegate.mc         Input routing
│   └── GameView.mc             All game logic, AI, and rendering
├── resources/
│   ├── launcher_icon.png       70×70 round icon
│   ├── drawables.xml
│   └── strings.xml
├── manifest.xml
└── monkey.jungle
```

## Build

```bash
# From the garmin workspace root:
bash _build_all.sh connect_four_lite

# Or manually:
monkeyc -o _PROD/connect_four_lite.prg -f connect_four_lite/monkey.jungle \
        -y developer_key.der -d fenix8solar51mm -l 0
```
