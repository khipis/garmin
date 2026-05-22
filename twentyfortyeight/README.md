# 2048

A full 2048 clone for Garmin watches. Slide tiles in one of four directions, merge equal-valued tiles, and try to reach the **2048** tile — or just chase your best score.

## What is it

A clean, lightweight 2048 with the original rules. Tiles are stored as exponents in a flat `Number` array (0 = empty, 1 = "2", 2 = "4", …) so merge logic is just integer comparisons. Movement on every device works through a manual swipe detector (`onDrag` start/stop) which is more reliable than the built-in `onSwipe` on some Garmin models, plus button mappings for full 4-direction movement on button-only watches.

## How to play

- Each turn, slide the whole 4×4 board **up / down / left / right**. All tiles slide to that edge, and identical neighbours merge.
- After every move a new tile spawns in a random empty slot (90 % a "2", 10 % a "4").
- Reach the **2048 tile** to win — but you can keep going to chase a higher score.
- Game ends when no move is possible. Best score is persisted.

## Controls

**Buttons (4-direction on a 5-button Garmin)**
- `UP` → slide up
- `DOWN` → slide down
- `ENTER` / `SELECT` → slide **right**
- `KEY_MENU` / `onHold SELECT` → slide **left**
- `BACK` → return to menu

**Touch**
- Swipe ← → ↑ ↓ → slide in that direction (uses manual `onDrag` detector for reliability)
- Tap → ignored during play (won't trigger a random move)

## Architecture

| File | Role |
| --- | --- |
| `GameController.mc` | State, score, best, win/lose detection |
| `GridManager.mc`    | Flat exponent grid, spawn helpers, "collapse left" core |
| `MergeEngine.mc`    | Direction-agnostic move that rotates → collapseLeft → un-rotates |
| `Tile.mc`           | Stateless coloured-tile renderer with adaptive font sizing |
| `InputHandler.mc`   | Button + manual swipe detector |
| `UIManager.mc`      | Menu / play / over screens |
| `MainView.mc`       | View + tick |

## Build

```bash
bash _build_all.sh twentyfortyeight
```

Artifacts:
- `_PROD/twentyfortyeight.prg`
- `_STORE/twentyfortyeight.iq`
