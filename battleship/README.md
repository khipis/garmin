# Battleship

Classic Sea Battle for Garmin watches. Place your fleet on a 10×10 grid, hunt the enemy fleet, and try to sink everything before the AI sinks you.

## What is it

A full Battleship game with three AI difficulty levels:

- **Easy** — random shots, no memory.
- **Medium** — remembers a hit and probes adjacent cells.
- **Hard** — classic HUNT/TARGET with parity-aware hunting (only shoots cells where the smallest remaining ship could possibly fit).

The board uses cell flags packed into a single byte per cell (`CELL_SHIP`, `CELL_SHOT`, `CELL_FLAG`). Ship placement obeys the **no-touch rule** (ships cannot touch even diagonally) and the "halo" of cells around a sunk ship is auto-marked as misses, so you instantly see which cells are safe to skip.

## How to play

- **Setup phase** — place your fleet of 10 ships (1×4, 2×3, 3×2, 4×1) on your 10×10 grid. Cells can't overlap or touch (no neighbour on any of the 8 sides). Auto-place is available.
- **Battle phase** — alternating shots between you and the AI on the enemy grid.
- A shot reveals `Hit` (red), `Miss` (white dot), or `Sunk` (the ship + its halo light up).
- Sink all 10 enemy ships to win; lose all 10 of yours to lose.

## Controls

**Setup phase**
- `UP` → step cursor **right** (column walk, wraps within the ship's legal range)
- `DOWN` → step cursor **down** (row walk, wraps within the ship's legal range)
- Swipe ← / → → orient horizontally
- Swipe ↑ / ↓ → orient vertically
- `SELECT` short → confirm placement
- `SELECT` long → rotate ship (fallback)
- Tap a cell → set cursor + confirm

**Aim / battle phase**
- `UP` → step cursor right (with wrap)
- `DOWN` → step cursor down (with wrap)
- `SELECT` → fire on current cell
- Swipe → 4-direction cursor move
- Tap → fire on tapped cell

## Architecture

| File | Role |
| --- | --- |
| `GameController.mc` | State machine, setup / aim flow, cursor handling |
| `GridManager.mc`    | 10×10 grid, cell flags, `canPlace()` with no-touch rule |
| `ShipManager.mc`    | Fleet definition, ship HP, sink detection |
| `BattleLogic.mc`    | `fire()`, halo-marking on sink, `autoPlace()` |
| `AIController.mc`   | Easy / Medium / Hard target picking |
| `InputHandler.mc`   | Button + swipe + tap routing per phase |
| `UIManager.mc`      | All drawing — setup, aim, HUD, ship status, overlays |
| `MainView.mc`       | View + tick |

## Build

```bash
bash _build_all.sh battleship
```

Artifacts:
- `_PROD/battleship.prg`
- `_STORE/battleship.iq`
