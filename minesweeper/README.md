# Minesweeper

Classic Minesweeper for Garmin watches — six board sizes from 16² up to a monster **100×100** with a scrolling viewport, safe-first-click, iterative flood-fill, persisted best-times per size.

## What is it

A full Minesweeper port that scales gracefully across screen sizes. Boards up to 32² fit on-screen fully; bigger boards switch to a scrolling window that re-centres on the cursor, with a mini-map showing where you are. Cell data is stored as compact `ByteArray`s (3 bytes per cell), so even a 100×100 board fits in ~30 KB of heap. The flood-fill uses an iterative BFS that marks cells revealed at enqueue time — the queue can never overflow.

## How to play

- Open cells without hitting a mine. The number on a revealed cell counts mines in the 8 neighbouring cells.
- Cells with `0` mines around them cascade open automatically.
- Win when every non-mine cell is revealed.
- The first click is **always safe** — a 3×3 mine-free zone is guaranteed around it.

### Sizes & mines (15 % density)

| Preset | Size | Mines |
| --- | --- | --- |
| Classic   | 16×16   | 38   |
| Hard      | 24×24   | 86   |
| Expert    | 32×32   | 153  |
| Insane    | 48×48   | 345  |
| Marathon  | 64×64   | 614  |
| Legend    | 100×100 | 1500 |

## Controls

**Buttons (menu)**
- `UP` / `DOWN` — cycle size
- `SELECT` / `ENTER` — start
- `BACK` — exit

**Buttons (in-game) — two-button cursor**
- `UP` → step cursor **right** with row-wrap (horizontal axis)
- `DOWN` → step cursor **down** with col-wrap (vertical axis)
- `SELECT` short — reveal current cell (or flag if mode = FLG)
- `SELECT` long — toggle flag on current cell (always)
- `KEY_MENU` — toggle reveal/flag mode (fallback for devices without long-press)
- `BACK` — return to menu

**Touch**
- Tap a cell → **reveal** (always, mode-independent)
- Long-press a cell → flag
- Swipe ← → ↑ ↓ → step cursor one cell in that direction
- Tap a size pill in the menu → set that size directly

## Architecture

| File | Role |
| --- | --- |
| `GameController.mc` | State, six size presets, timer, best-time persistence |
| `GridManager.mc`    | ByteArray board, mine placement, BFS flood-fill |
| `Tile.mc`           | Stateless cell renderer (auto-shrinks digits to dots on small cells) |
| `InputHandler.mc`   | Button / swipe / tap routing |
| `MainView.mc`       | Layout (full / viewport), mini-map, HUD, overlays |

## Build

```bash
bash _build_all.sh minesweeper
```

Artifacts:
- `_PROD/minesweeper.prg`
- `_STORE/minesweeper.iq`
