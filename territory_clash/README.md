# Territory Clash

A simplified Go-like territory control game for Garmin watches.  
Place Black stones to surround territory and capture White (AI) groups.

## Rules

### Objective

Control more territory than the AI when the game ends.

### Board

9×9 intersection grid. You play **Black**, the AI plays **White**.  
Players alternate placing one stone per turn on any empty intersection.

### Capture

After any stone is placed, every **opponent group** (set of connected same-colour stones)
with **zero liberties** (no empty intersections orthogonally adjacent to any stone in the group)
is removed from the board. Removed stones become captures.

- Suicide is illegal: you cannot place a stone if your resulting group would have zero liberties
  (unless the placement itself causes captures that free your group).

### Game end

The game ends when:
1. The board is completely full, **or**
2. Both players **pass** consecutively.

Press **BACK** to pass. After one pass, you will see "1 pass" in the top strip;
if the AI also passes, the game ends.

### Scoring (Japanese-style territory + captures)

```
Score = empty cells surrounded exclusively by your stones
      + opponent stones you captured during the game
```

Tied scores result in a draw.  
At the end, territory is visualised as small coloured squares on empty intersections.

---

## Controls

| Input | Action |
|-------|--------|
| **↑ (Up)** | Move cursor up |
| **↓ (Down)** | Move cursor down |
| **← (Previous Page)** | Move cursor left |
| **→ (Next Page)** | Move cursor right |
| **SELECT / Tap** | Place stone · new game (when over) |
| **BACK** | Pass turn · exit app (when over) |

---

## Display

```
┌─────────────────────────────────────┐
│ AI(W)  cap:3             W:2        │  ← top strip (AI captures + AI session wins)
│                                     │
│  ┌─────────────────────────────┐    │
│  │  •     Go board 9×9         │    │
│  │    ●   ○   ●                │    │  ● = Black (you)  ○ = White (AI)
│  │      ⊙   ●   ○             │    │  ⊙ = cursor (orange ring)
│  │    ●   ○   ●   ○           │    │  · = last-move dot
│  └─────────────────────────────┘    │
│                                     │
│ W:1  You(B)  cap:2  BACK=pass       │  ← bottom strip
└─────────────────────────────────────┘
```

- **Orange ring** = cursor; confirms the selected intersection
- **Red ring** = cursor on an occupied cell (cannot place)
- **Last-move dot** = contrasting dot in the centre of the most recently played stone
- **Small squares** (end game) = territory owned by each player

### Star points (tengen and corner-stars)

The 9×9 board shows five traditional reference dots:
`(2,2)` `(6,2)` `(4,4)` `(2,6)` `(6,6)`.

---

## AI

The AI evaluates every empty cell using a **heuristic score**:

| Condition | Bonus |
|-----------|-------|
| Centre preference | 18 − 2 × Manhattan distance from (4,4) |
| Adjacent player group in atari (1 liberty) | +30 (capture opportunity) |
| Adjacent AI group in atari (1 liberty) | +20 (save own group) |
| Random noise | +0..6 |

The highest-scored legal move is played. If that move turns out to be
suicide (after full capture resolution), the AI falls back to the first
available legal cell.

---

## Technical notes

- **9×9 board** → 81 cells. All arrays pre-allocated in `initialize()`:
  `_board[81]`, `_visit[81]`, `_queue[81]`, `_terr[81]` (no game-loop heap allocation).
- **BFS group/liberty check** — O(N²) per call. Used in:
  - `_placeStone`: up to 4 capture checks + 1 suicide check per move.
  - `_aiEval`: up to 8 liberty checks per candidate cell (centre + defence heuristics).
  - `_calcScore`: single full-board BFS sweep at game end.
- **AI cost per turn** — at most 81 candidate cells × 8 BFS calls × O(81) per BFS
  ≈ 52,000 array accesses; in practice much less (most adjacency checks find empty cells
  immediately). Comfortably fits within the 700 ms AI timer tick.
- **Adaptive layout** — `_step`, `_boardX`, `_boardY`, `_stoneR` all computed from
  `dc.getWidth()` / `dc.getHeight()`, supporting screens from 260 px to 416 px.
- **Suicide simplification** — captures are applied first; suicide is only rejected
  when no captures occurred AND the resulting own group has zero liberties.
  (The extremely rare edge case where captures happen AND own group is still captured
  is treated as legal to avoid board-state undo complexity.)

---

## Project structure

```
territory_clash/
├── source/
│   ├── TerritoryClashApp.mc   — entry point
│   ├── GameDelegate.mc        — input routing
│   └── GameView.mc            — game logic + rendering (~430 lines)
├── resources/
│   ├── drawables.xml
│   ├── strings.xml
│   └── launcher_icon.png      — 70×70 generated icon
├── manifest.xml               — app ID: 0d3e5814-d995-49d1-bfb0-c9e1e5028a92
├── monkey.jungle
└── README.md

_LOGOS/
├── gen_territory_icon.py      — generates launcher_icon.png (70×70)
└── gen_territory_hero.py      — generates territory_hero.png (1440×720)

_STORE/   — (place signed .iq here for Connect IQ Store)
_PROD/    — (compiled .prg output)
```
