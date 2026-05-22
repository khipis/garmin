# Pinball Pro

A NES-arcade-style pinball game for Garmin watches with five hand-crafted tables, multi-ball, drop targets, slingshots, a launch power meter, and substep-stable flipper physics.

## What is it

Five distinct tables (Classic / Nova / Derby / Stinger / Eclipse) sharing a tuned physics engine. Up to three balls can be in play simultaneously (multi-ball is awarded by clearing the drop-target bank). The renderer is a 40 Hz tick driver; physics integrate the ball in `SUBSTEPS = 3` slices per tick so a fast ball can't tunnel through the flippers, and the flippers' rotation is **also** substepped so the sweep itself is sampled at intermediate angles.

## How to play

- Pick a **table** in the menu, then press start.
- A ball parks at the launcher; tap (or `SELECT`) to release — a **launch power meter** oscillates while the ball is parked, lock it in at the moment you want the desired strength.
- Hit bumpers (+100), knock down drop targets (+50 each, +500 + extra ball when all are down), poke slingshots (+25 + sling kick).
- Every 10 000 points → +1 extra life.
- Game over when all lives + balls are drained.

## Controls

**Buttons**
- `UP` or `DOWN` (press / release) → both flippers (hold to keep them up)
- `SELECT` / `ENTER` → launch / lock power / dismiss screens
- `BACK` → return to menu

**Touch**
- Tap anywhere on the playfield → both flippers pulse (~400 ms)
- Tap on launch screen → launch with the currently-shown power
- An `onDrag`-based tap fallback also fires the flippers on devices where `onTap` is unreliable

## Architecture

| File | Role |
| --- | --- |
| `GameController.mc` | State, score, lives, multi-ball, table selection, launch meter, substep collision loop |
| `Ball.mc`           | Position, velocity, alive flag, comet-trail |
| `Flipper.mc`        | Capsule (segment + collision radius) + thin visual radius; substep-able rotation |
| `DropTarget.mc`     | Knockable rectangle target |
| `Slingshot.mc`      | Triangle bumper with active-edge normal |
| `PhysicsEngine.mc`  | Forces, advance, wall / bumper / rect / slingshot / flipper collision routines |
| `TableLibrary.mc`   | Pure factory returning the bumpers / drops / slings for each table |
| `InputHandler.mc`   | Button + tap + drag-fallback routing |
| `MainView.mc`       | 40 Hz tick driver, render order, HUD, launch overlay, game-over screen |

## Build

```bash
bash _build_all.sh pinballpro
```

Artifacts:
- `_PROD/pinballpro.prg`
- `_STORE/pinballpro.iq`
