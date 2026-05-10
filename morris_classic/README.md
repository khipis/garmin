# Morris Classic

A full Nine Men's Morris (Mill) game for round Garmin watches. Play all three
phases — place, move, and fly — against an AI opponent.

## Rules

Nine Men's Morris is a two-player strategy game dating back to ancient Rome.

| Colour | Player | Objective |
|--------|--------|-----------|
| **Red** | You | Form mills (3 in a row) and reduce AI to < 3 pieces |
| **Blue** | AI | Same |

### Phases

| Phase | Trigger | Action |
|-------|---------|--------|
| **Place** | Pieces in hand > 0 | Place one piece on any empty node per turn |
| **Move** | All 9 placed, board > 3 | Slide one piece to an adjacent empty node |
| **Fly** | Exactly 3 pieces on board | Move any piece to any empty node |

### Mills

A **mill** is 3 of your pieces in a straight line on the same ring or cross-line.
When you form a mill you immediately remove one opponent piece.

- You **cannot** remove a piece that is part of a mill, unless all opponent pieces are in mills.
- A player loses when they have **fewer than 3 pieces** (after placing all 9),
  or when they have **no legal moves** in the Move phase.
- There are **16 possible mills** (8 horizontal rows + 8 vertical columns).

> **The game cannot end in a draw** once one player drops below 3 pieces.

## Board Layout

```
0-----------1-----------2
|           |           |
|   3-------4-------5   |
|   |       |       |   |
|   |   6---7---8   |   |
|   |   |       |   |   |
9--10--11      12--13--14
|   |   |       |   |   |
|   |  15--16--17   |   |
|   |       |       |   |
|  18------19------20   |
|           |           |
21----------22----------23
```

**24 nodes** arranged as 3 concentric squares. Adjacent nodes are connected by
lines. Middle-side nodes on each square also connect to the corresponding
middle-side node on the adjacent square (the 8 cross-line edges).

## Controls

| Input | Action |
|-------|--------|
| UP button | Move cursor to upper neighbour node |
| DOWN button | Move cursor to lower neighbour node |
| PAGE UP / left scroll | Move cursor to left neighbour node |
| PAGE DOWN / right scroll | Move cursor to right neighbour node |
| SELECT / tap | **Place phase** — place stone on cursor node |
| SELECT / tap | **Move phase** — first: select own piece; second: choose destination |
| SELECT / tap | **Remove phase** — remove highlighted AI piece |
| SELECT *(game over)* | Start a new game |
| BACK | Exit to watch menu |

**HUD labels:**
- `PLACE` / `MOVE` / `FLY` — current phase, player's turn
- `DEST` — piece selected, choose where to slide/fly
- `TAKE!` — mill formed, select opponent piece to remove
- `AI...` — AI is thinking (450 ms pause)
- `H:n` — pieces remaining in hand (placing phase)
- `B:n` — pieces currently on the board

**Cursor colours:**
- Yellow ring — standard cursor
- Orange ring — cursor hovering over a re-selectable own piece
- Red ring — cursor hovering over a removable AI piece
- Double orange ring on selected piece, green rings on valid destinations

## AI Strategy

The AI uses a **priority-layered greedy heuristic** with no lookahead:

1. **Immediate mill** — if any empty node completes a 3-in-a-row: take it (score 1000).
2. **Block player mill** — if player would form a mill at an empty node: block it (score 500).
3. **Potential mill bonus** — prefer nodes in open lines that already contain AI pieces
   (`aiCount × 12` per qualifying mill line).
4. **Centre bias** — mild preference for the centre region of the board (`(6 − |dx| − |dy|) × 2`).
5. **Noise** — small random perturbation `(0–4)` breaks exact ties.

During the Remove phase the AI removes the strategically most valuable player piece
(centre-biased), preferring non-milled pieces per standard rules.

## Technical Notes

### Zero-allocation game loop

All board data is pre-allocated in `initialize()`:

| Array | Size | Purpose |
|-------|------|---------|
| `_nodes[24]` | 24 × int | Current stone colour per node |
| `_adj[96]` | 24 × 4 × int | Adjacency (up to 4 neighbours, −1 = empty slot) |
| `_mills[48]` | 16 × 3 × int | All 16 mill triplets |
| `_nav[96]` | 24 × 4 × int | Cursor navigation (UP/DOWN/LEFT/RIGHT) |
| `_gx[24]`, `_gy[24]` | 24 × int each | Grid position (0–6) for rendering |
| `_edges[64]` | 32 × 2 × int | Line segments to draw |

No heap allocations occur during play. Total static board data ≈ 1.6 KB.

### Mill detection — O(16) per call

`_inMill(n, col)` iterates all 16 mill triplets and returns `true` if any
triplet containing node `n` has all three cells occupied by `col`.

`_wouldMill(n, col)` temporarily sets `_nodes[n] = col`, calls `_inMill`,
then restores `MC_EMPTY`. Used only by the AI scorer on confirmed-empty nodes.

### Rendering

`onUpdate` is event-driven (`requestUpdate()` called only on state changes —
no continuous animation loop). Per frame:

- 32 board line draws
- 24 node fills (empty / player / AI, with optional mill highlight)
- Conditional overlay rings (valid destinations, removable pieces, cursor)
- HUD text (score, hand count, status label)
- Optional game-over rectangle

All geometry computed from `_nx(i) = _bx + gx[i] × step` and
`_ny(i) = _by + gy[i] × step`, scaling automatically to screen width.

### Timer

A 450 ms repeating `Timer.Timer` drives the AI turn (`MGS_AI`) and the
brief post-remove display pause (`MGS_AI_RM`). It no-ops in all other states.

## Files

```
morris_classic/
├── source/
│   ├── MorrisClassicApp.mc    Application entry point
│   ├── GameDelegate.mc        Input routing (navigate / doAction)
│   └── GameView.mc            All game logic, AI, and rendering
├── resources/
│   ├── launcher_icon.png      70×70 round icon (generated by _LOGOS script)
│   ├── drawables.xml
│   └── strings.xml
├── manifest.xml               55 supported products
└── monkey.jungle
```

## Build

```bash
# From the garmin workspace root:
bash _build_all.sh morris_classic

# Or manually:
monkeyc -o _PROD/morris_classic.prg -f morris_classic/monkey.jungle \
        -y developer_key.der -d fenix8solar51mm -l 0
```
