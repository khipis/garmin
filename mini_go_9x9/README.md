# Bitochi Mini Go 9×9

A full 9×9 Go game for round Garmin watches (fenix, epix, fr, venu, vivoactive series).

## What is Go?

Go is the world's oldest board game — two players (Black and White) take turns placing stones on a 9×9 grid.  
The goal is to surround more territory than your opponent while capturing their stones.

---

## Rules (simplified Japanese)

| Rule | Implementation |
|------|----------------|
| **Capture** | A group of stones with no empty adjacent intersections (liberties) is removed from the board. |
| **Suicide** | You may not place a stone that immediately leaves your own group with zero liberties — unless it captures an opponent group first. |
| **Ko** | You may not play a move that returns the board to the exact position it was in immediately before your last move (simple anti-repeat). |
| **Passing** | Press **BACK** to pass your turn. |
| **Game end** | When both players pass consecutively the game ends. |
| **Scoring** | Japanese scoring: territory you surround + opponent stones you captured. White receives **+7 komi** to compensate for Black moving first. |

---

## Controls

| Input | Action |
|-------|--------|
| **UP button** | Move cursor up |
| **DOWN button** | Move cursor down |
| **Scroll-up / onPreviousPage** | Move cursor left |
| **Scroll-down / onNextPage** | Move cursor right |
| **SELECT** | Place stone (or start a new game when game over) |
| **BACK** | Pass your turn (or start a new game when game over) |

---

## Gameplay

1. You play as **Black** and always move first.
2. Navigate the cursor (green highlight) to the intersection you want.
3. Press **SELECT** to place a stone.  
   If the move is illegal the cursor briefly flashes **red** — pick another spot.
4. The AI (White) responds immediately.
5. A small dot inside the last-placed stone indicates the most recent move.
6. Pass with **BACK** when you have no profitable moves left.  
   Two consecutive passes end the game and trigger automatic scoring.

---

## AI Opponent

The AI uses a fast heuristic (no minimax / tree search):

1. **Capture priority** — plays at the single liberty of any opponent group in *atari* (+12 score bonus).
2. **Defensive priority** — saves own groups in atari (+8 score bonus).
3. **Weighted scoring** — prefers intersections near the centre of the board; adjacent opponent groups get extra weight.
4. **Random noise** — small random term (0–3) prevents repetitive play.

All 81 candidate positions are evaluated in `O(81 × avg_group_size)` — comfortably within one frame.

---

## Visual Guide

| Element | Appearance |
|---------|-----------|
| Board | Golden / wood-tone background |
| Grid lines | Dark brown lines |
| Star points (hoshi) | Small brown dots at rows/cols 2, 4, 6 |
| Black stone | Dark circle with subtle top-left highlight |
| White stone | Light circle with grey border + white highlight |
| Last-move marker | Small contrasting dot inside the stone |
| Cursor | Bright green double-rectangle outline |
| Illegal move | Cursor flashes red briefly |

---

## Technical Notes

### Board representation
- Flat `int[81]` array: `grid[y*9+x]` — 0 = empty, 1 = Black, 2 = White.
- A separate `prevGrid[81]` stores the board before each move for the ko check.

### Flood-fill (BFS) — generation counter trick
All group-finding and territory-counting reuse three pre-allocated scratch arrays (`_vis[81]`, `_grp[81]`, `_stk[81]`).  
Instead of zeroing `_vis` before each BFS call (81 writes), a monotonically increasing `_gen` counter is used.  
A cell is "visited in the current BFS" when `_vis[cell] == _gen`. This makes each BFS call truly O(group_size).

### Territory counting
At game end, `Board.calcScore()` flood-fills all empty regions.  
Each region that is surrounded exclusively by Black counts as Black territory; same for White.  
Mixed regions are *dame* (neither player's territory).

### AI performance
`AI.chooseMove()` iterates all 81 empty intersections, calling `Board.getGroupLiberties()` (public BFS wrapper) for each adjacent stone — at most 4 calls per candidate, each O(group_size).  
Total per AI turn: O(81 × 4 × avg_group_size) ≈ a few hundred operations.

---

## File Structure

```
mini_go_9x9/
├── source/
│   ├── MiniGoApp.mc        – AppBase entry point
│   ├── GameDelegate.mc     – Input routing (BehaviorDelegate)
│   ├── Board.mc            – Board state, capture logic, scoring
│   ├── AI.mc               – Heuristic AI (White player)
│   ├── GameController.mc   – Turn management, pass counting, game-over
│   └── GameView.mc         – Rendering + layout constants
├── resources/
│   ├── strings.xml
│   ├── drawables.xml
│   └── launcher_icon.png
├── manifest.xml
├── monkey.jungle
└── README.md
```

---

## Build

```bash
# Quick dev build (fenix 8 Solar 51 mm)
bash _build_all.sh mini_go_9x9

# Or build all apps
bash _build_all.sh
```

Artefacts land in `_PROD/mini_go_9x9.prg` (sideload) and `_STORE/mini_go_9x9.iq` (Connect IQ Store upload).

---

*Part of the Bitochi Garmin Games collection.*
