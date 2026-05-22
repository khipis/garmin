# Sudoku

Classic Sudoku for Garmin Connect IQ — solve a 4×4 quick game in a coffee break, or settle in for a full 9×9 Easy / Medium / Hard puzzle on your wrist.

## What is it

A complete on-watch Sudoku with handcrafted difficulty curves. Puzzles are generated from a bank of pre-baked solutions and re-symbolised on the fly, so every game is unique but the runtime cost stays well inside the device's watchdog budget (no recursive solver on the watch). Times and best scores are persisted per mode.

## How to play

- Fill every row, every column, and every block with the digits 1..N (4 or 9) without repetition.
- **Quick** — 4×4 board, blocks are 2×2. Great for a 2-minute game.
- **Classic** — 9×9 board, blocks are 3×3. Three difficulty levels (Easy / Medium / Hard) differ in the number of pre-filled clues.
- Use the **error-check** mode that fits your style:
  - *Relaxed* — wrong digits are highlighted in red, you can fix them.
  - *Strict* — wrong digits end the run; only mistake-free solves count.
- The HUD shows elapsed time. Best times per mode/difficulty are stored persistently.

## Controls

**Buttons (5-button Garmin)**
- `UP` / `DOWN` — move cursor vertically
- `KEY_MENU` / `onPrevious` — move cursor left
- `KEY_NEXT` — move cursor right
- `SELECT` short press — cycle the digit on the current cell
- `SELECT` long press — clear the current cell
- `BACK` — drop edits / return to menu

**Touch**
- Tap a cell → move cursor there
- Tap an already-selected cell → cycle digit
- Swipe ← → ↑ ↓ → move cursor

## Architecture

| File | Role |
| --- | --- |
| `GameController.mc` | State machine, mode/difficulty, timer, persistence |
| `SudokuGrid.mc`     | Board model — cell values, fixed-cell mask, error mask |
| `SudokuGenerator.mc`| Pre-baked solution bank + symbol re-labelling + clue removal |
| `InputHandler.mc`   | Button + touch routing |
| `UIManager.mc`      | All drawing — menu, grid, HUD, win/lose overlays |
| `MainView.mc`       | View / tick driver |

## Build

```bash
bash _build_all.sh sudoku
```

Artifacts:
- `_PROD/sudoku.prg`  — sideload for debugging
- `_STORE/sudoku.iq`  — Connect IQ Store-ready bundle
