# Gem Match

A snappy match-3 time-attack game for Garmin watches — swap adjacent gems, line
up three or more in a row or column, and chase real animated chain reactions
(with power-gem bomb detonations) before the clock, move count, or your nerve
runs out.

## What is it

Bejeweled-style match-3, supercharged for a watch screen. The board is a flat
integer array (no per-cell objects), match detection runs in two passes per
swap, and every cascade step is now **fully animated**: matched gems flash,
clear, and the survivors visibly tumble down under gravity (accelerating,
gravity-style easing) while fresh gems drop in from above — then the board is
rescanned. If the fall reveals a new match, the flash → fall loop repeats,
so you *watch* the chain reaction unfold instead of getting an instant score
jump. Cascades chain up to depth 8 and the board auto-reshuffles when no valid
move remains.

### 💥 Power gems & chain reactions
Line up **4 or 5** identical gems and one of them survives as a pulsing **bomb
gem** instead of clearing. Later resolve that bomb — by matching it, swapping
directly into it, or catching it in a neighbouring explosion — and it detonates
a **3×3 blast**. Blasts can reach other bombs sitting nearby, which detonate in
turn: a single well-placed match can set off a board-wide chain reaction, each
step scoring `10 × cells cleared × chain depth`. Bomb detonations trigger a
screen shake and a "BOOM!" banner; multi-step chains show an escalating
color-coded "CHAIN xN" banner (cyan → orange → red the deeper it goes).

### ✨ Visual polish
- Every gem is now a layered "jewel" — drop shadow, coloured body, glossy
  highlight facet and a sparkle dot — instead of a single flat shape.
- Bomb gems pulse between orange and red with a lit-fuse spark cross.
- Checkerboard cell shading, floating "+score" popups per cascade step, and a
  colour-escalating chain banner make every combo feel bigger than the last.

## How to play

- **Time Attack** (default): score as many points as possible before the
  clock (30 s – 3 min) runs out.
- **Zen**: no timer — play until you press BACK.
- **Moves**: a fixed move budget (10/15/20/30); every successful swap spends
  one move.
- Pick a gem, then pick (or swap to) an **orthogonal neighbour** to swap them.
- A valid swap creates a line of **3+ identical gems**. 4+ leaves a bomb gem
  behind. Matched gems clear, gems above fall, fresh ones drop in — watch for
  chain reactions as the board resettles.
- A swap that doesn't create a match is **reverted** — unless you're swapping
  directly into a bomb, which always detonates.
- Best score is persisted per mode; longest chain and bombs popped are shown
  on the game-over screen and submitted to the global leaderboard as bonus
  stats.

## Controls

**Buttons**
- `UP` → step cursor **LEFT** with col-wrap (horizontal axis)
- `DOWN` → step cursor **DOWN** with row-wrap (vertical axis)
- `SELECT` short → pick gem; second `SELECT` on a neighbour = swap
- `SELECT` while picked, on the same cell = cancel pick
- `BACK` → drop pick / return to menu (ends the round in Zen)

**Touch**
- Tap a gem → pick it (or swap if a neighbour is already picked)
- Swipe ← → ↑ ↓ → move cursor one step in that direction

## Scoring

| Event | Points |
| --- | --- |
| Cleared cell, cascade step N | `10 × N` per cell (bomb blasts count every cell they clear) |
| Bomb detonation | No flat bonus — but blasts typically clear far more cells, multiplying the step's score |
| Longest chain / bombs popped | Tracked per run, shown on game-over, submitted as `chain` / `bombs` leaderboard variants |

## Architecture

| File | Role |
| --- | --- |
| `GameController.mc` | State, cursor + selection, scoring, animated FLASH→FALL cascade state machine, bomb-swap handling, leaderboard submission |
| `GridManager.mc`    | Board model — flat-int storage, gravity + refill (plain and animated/`fallFrom`-tracking variants), validity checks |
| `MatchEngine.mc`    | Two-pass match detection, bomb-spawn selection (runs of 4+), bomb blast marking + chain propagation, clear |
| `Tile.mc`           | Gem + bomb renderer — layered shading, pulsing bomb visual, glow flash |
| `InputHandler.mc`   | Button + touch routing |
| `MainView.mc`       | Layout + drawing (incl. fall-animation interpolation, screen shake, chain/boom popups) + 50 ms tick driver |

## Build

```bash
bash _build_all.sh gemmatch
```

Artifacts:
- `_PROD/gemmatch.prg`
- `_STORE/gemmatch.iq`
