# Drwal

A Timberman-style lumberjack arcade game for Garmin watches. Chop the tree as fast as you can, switch sides to dodge branches, and race the energy bar before it — or a branch — ends your run. Sessions last 10-30 seconds; restart is instant.

## What is it

A minimal, ultra-responsive reflex game: the tree scrolls toward the player one segment per chop, each segment carrying a branch on at most one side (or none). Every input is a single, instant action — switch side and chop in the same frame, no delays, no blocking animations. Difficulty (branch density, energy drain) scales continuously with your live score, and a small energy bar forces constant action so runs stay short and tense.

## How to play

- The lumberjack always stands beside the trunk, on the **left** or **right**.
- Chopping the current segment while standing on the side with a branch = instant game over.
- The opposite side is always safe — a segment never has a branch on both sides, so there's always a way out.
- An energy bar drains continuously and refills a little on every successful chop; let it hit zero and the run ends too.
- Chopping fast (inside ~0.5 s of the previous chop) builds a **combo** that adds bonus points on top of the flat +1 per chop.
- Score = chops + combo bonus. Best score is persisted per difficulty.

## Controls

**Buttons**
- `UP` / `KEY_UP` — chop from the **left**
- `DOWN` / `KEY_DOWN` — chop from the **right**
- `SELECT` / `ENTER` — chop again on the current side (single-button fallback)
- `BACK` — return to menu

**Touch**
- Tap left half / right half of the screen — chop from that side
- On the menu: tap a row to activate it

**Game over**
- Any tap / button press — instantly start a new run
- `BACK` — return to the menu

## Menu

Chess-style 3-row menu, settings persisted across app restarts:
- **Diff** — Easy / Normal / Hard (affects branch density, energy drain and refill)
- **START**
- **LEADERBOARD** — global scores for the current difficulty

## Architecture

| File | Role |
| --- | --- |
| `GameController.mc`  | State machine, chop resolution, energy/difficulty curve, menu + leaderboard wiring |
| `InputHandler.mc`     | Maps buttons/taps/swipes to instant chop / menu actions |
| `PlayerSystem.mc`     | Lumberjack side + swing/shake animation timers (cosmetic only) |
| `TreeGenerator.mc`    | Fixed-size scrolling window of tree segments, fair branch generation |
| `CollisionSystem.mc`  | Branch-vs-player hit test |
| `ScoreSystem.mc`      | Score, combo bonus, persisted best |
| `RenderSystem.mc`     | Draws sky/ground, trunk, branches, lumberjack — pure, stateless, no per-frame allocation |
| `UIManager.mc`        | HUD (score/energy bar/combo), chess-style menu, game-over overlay |
| `MainView.mc`         | `WatchUi.View` — layout, 50 ms tick, input entry points |
| `DrwalApp.mc`         | Application entry point |

## Leaderboard

Submits `score` under variant = current difficulty (`Easy` / `Normal` / `Hard`) via the shared `_shared/leaderboard` module. See `LEADERBOARD.md` at the repo root.
