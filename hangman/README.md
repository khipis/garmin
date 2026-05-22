# Hangman

A text-based word-guessing game for Garmin watches. Pick from four categories and three difficulty tiers, then tap your way through the on-screen keyboard before the gallows fills in.

## What is it

A faithful Hangman with a notebook-paper visual style. Words come from a built-in offline list grouped by category and length. The on-screen keyboard layout adapts to the watch screen and uses a very forgiving hit-test so any tap snaps to the nearest letter — important on small round screens where individual cells are only a few pixels wide.

## How to play

- Pick a **Category** (animals / food / technology / sports) and a **Difficulty** (Easy / Medium / Hard — short / medium / long words).
- Tap letters on the on-screen keyboard (or step through them with the buttons + SELECT) to guess.
- Correct letters reveal in the masked word; wrong letters draw a new piece of the hangman.
- Win = word fully revealed. Lose = full hangman.
- Total wins counter is persisted between runs.

## Controls

**Buttons (menu)**
- `UP` / `DOWN` — walk between rows (Category / Difficulty / Start)
- `SELECT` / `ENTER` — cycle the value on the current row, or start when on START
- `BACK` — exit

**Buttons (in-game)**
- `UP` / `DOWN` — move letter cursor up / down
- `SELECT` short — move cursor right
- `SELECT` long — guess current letter
- `BACK` — return to menu

**Touch**
- Tap anywhere → snap to nearest letter and guess it (so the whole screen is a tap target)
- Swipe ← → ↑ ↓ → move letter cursor

## Architecture

| File | Role |
| --- | --- |
| `GameController.mc`  | State, word selection, guess bitmask, win/lose detection |
| `WordList.mc`        | Offline word lists, category/difficulty filtering |
| `HangmanRenderer.mc` | Stateless gallows + figure renderer (stage 0..N) |
| `UIManager.mc`       | Menu / play / overlay drawing + keyboard layout |
| `InputHandler.mc`    | Button / swipe / drag-based-tap routing |
| `MainView.mc`        | View + cached keyboard layout for tap routing |

## Build

```bash
bash _build_all.sh hangman
```

Artifacts:
- `_PROD/hangman.prg`
- `_STORE/hangman.iq`
