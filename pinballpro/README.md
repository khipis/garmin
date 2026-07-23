# Pinball Pro

A premium NES-arcade-style pinball game for Garmin watches with **seven** hand-crafted tables, multi-ball, combos & multipliers, missions, jackpots, skill shots, ball-save, nudge/tilt, and substep-stable flipper physics — wrapped in a juicy FX layer (spark particles, floating score popups, screen shake, event banners, tone/vibe feedback).

## What is it

Seven distinct tables (Classic / Nova / Derby / Stinger / Eclipse / **Vortex** / **Comet**) sharing a tuned physics engine, each with its own theme colours and decorative playfield inlay. Up to three balls can be in play simultaneously (multi-ball is awarded by clearing the drop-target bank). The renderer is a 40 Hz tick driver; physics integrate the ball in `SUBSTEPS = 3` slices per tick so a fast ball can't tunnel through the flippers, and the flippers' rotation is **also** substepped so the sweep itself is sampled at intermediate angles.

## How to play

- Pick a **table** in OPTIONS, then press START.
- A ball parks at the launcher; tap (or `SELECT`) to release — a **launch power meter** oscillates while the ball is parked. Release inside the lit **skill-shot band** for a big bonus.
- Hit bumpers (+100), knock down drop targets (+50 each, +500 + extra ball + bonus-multiplier when all are down), poke slingshots (+25 + sling kick).
- **Combos**: chain hits to ramp a x1..x6 multiplier that scales every award; the chain decays if you stop scoring.
- **Missions**: each table has a 3-step objective chain (hit N bumpers / clear the bank / hit N slings). Each step pays out; the final step grants an extra ball, then the chain loops.
- **Jackpot**: builds during multi-ball and is collected by clearing the bank while 2+ balls are live.
- **Ball save**: a drain in the first few seconds after a launch kicks the ball back into play (once per ball).
- **Nudge/Tilt**: press `SELECT` during play to shove the ball — but over-nudge and the table **TILTS** (flippers die briefly and the end-of-ball bonus is lost).
- Every 10 000 points → +1 extra life. Game over when all lives + balls are drained.

## Controls

**Buttons**
- `UP` or `DOWN` (press / release) → both flippers (hold to keep them up)
- `SELECT` / `ENTER` → launch / lock power / **nudge** during play / dismiss screens
- `BACK` → return to menu

**Touch**
- Tap anywhere on the playfield → both flippers pulse (~400 ms)
- Tap on launch screen → launch with the currently-shown power
- An `onDrag`-based tap fallback also fires the flippers on devices where `onTap` is unreliable

## Options

- **Table** — pick one of the seven tables (also the leaderboard variant).
- **Effects** — ON/OFF toggle for tone/vibe feedback.

## Architecture

| File | Role |
| --- | --- |
| `GameController.mc` | State, score, lives, multi-ball, table selection, launch meter, substep collision loop |
| `Ball.mc`           | Position, velocity, alive flag, comet-trail |
| `Flipper.mc`        | Capsule (segment + collision radius) + thin visual radius; substep-able rotation |
| `DropTarget.mc`     | Knockable rectangle target |
| `Slingshot.mc`      | Triangle bumper with active-edge normal |
| `PhysicsEngine.mc`  | Forces, advance, wall / bumper / rect / slingshot / flipper collision routines |
| `TableLibrary.mc`   | Pure factory returning the bumpers / drops / slings, theme, art style, and mission chain for each table |
| `Effects.mc`        | Pre-allocated spark-particle + score-popup pools (the juice layer) |
| `InputHandler.mc`   | Button + tap + drag-fallback routing |
| `MainView.mc`       | 40 Hz tick driver, render order, HUD, launch overlay, game-over screen |

## Build

```bash
bash _build_all.sh pinballpro
```

Artifacts:
- `_PROD/pinballpro.prg`
- `_STORE/pinballpro.iq`
