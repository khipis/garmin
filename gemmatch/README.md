# Gem Match

A snappy match-3 time-attack game for Garmin watches — swap adjacent gems, line up three or more in a row or column, and chase cascading combos before the 90-second timer runs out.

## What is it

Bejeweled-style match-3 distilled to fit a watch. The board is a flat integer array (no per-cell objects), match detection runs in two passes per swap, gravity + refill are iterative, and cascades up to depth 8 are resolved synchronously without stuttering the UI. The board auto-reshuffles when no valid move remains.

## How to play

- You have **90 seconds** to score as many points as possible.
- Pick a gem, then pick (or swap to) an **orthogonal neighbour** to swap them.
- A valid swap creates a line of **3+ identical gems** in a row or column. Matched gems disappear, gems above fall down, fresh ones drop in from the top.
- If the refill creates new matches, they auto-resolve as a **cascade** — each step multiplies the score (10 pts × cells × cascade depth).
- A swap that doesn't create a match is **reverted** (no penalty in this build — it just costs you time).
- Best score is persisted between runs.

## Controls

**Buttons**
- `UP` → step cursor **LEFT** with col-wrap (horizontal axis)
- `DOWN` → step cursor **DOWN** with row-wrap (vertical axis)
- `SELECT` short → pick gem; second `SELECT` on a neighbour = swap
- `SELECT` while picked, on the same cell = cancel pick
- `BACK` → drop pick / return to menu

**Touch**
- Tap a gem → pick it (or swap if a neighbour is already picked)
- Swipe ← → ↑ ↓ → move cursor one step in that direction

## Architecture

| File | Role |
| --- | --- |
| `GameController.mc` | State, cursor + selection, scoring, cascade orchestration |
| `GridManager.mc`    | Board model — flat-int storage, gravity + refill, validity checks |
| `MatchEngine.mc`    | Two-pass match detection + clear |
| `Tile.mc`           | Stateless gem renderer |
| `InputHandler.mc`   | Button + touch routing |
| `MainView.mc`       | Layout + drawing + 250 ms tick driver |

## Build

```bash
bash _build_all.sh gemmatch
```

Artifacts:
- `_PROD/gemmatch.prg`
- `_STORE/gemmatch.iq`
