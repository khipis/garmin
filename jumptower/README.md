# Jump Tower

A Doodle-Jump-style endless climber for Garmin watches. Bounce up an infinite tower of snow-capped platforms, dodge breakables, ride moving platforms, launch off springs, and chase your best height.

## What is it

A vertical infinite-runner with procedural platform generation and a screen-relative physics pass — gravity, jump velocity, and horizontal speed all scale with the watch's screen height so the jump arc feels identical on a Vivoactive and a Fenix. The backdrop is a procedurally tiled brick wall with floating snow specks; platforms have white snow caps, icicles, and type-specific accents (spring coil, breakable cracks, moving arrows).

## How to play

- The hero bounces automatically — every time they touch the **top** of a platform.
- You only steer **horizontally**: the screen wraps left ↔ right.
- Platform types:
  - **Normal** — solid.
  - **Moving** — slides left/right; ride it.
  - **Breakable** — collapses after one jump.
  - **Spring** — sends you twice as high.
- Camera scrolls up as you climb; falling below the bottom of the screen ends the run.
- Score = peak height reached. Best is persisted.

## Controls

**Buttons**
- `UP` / `KEY_MENU` — move left
- `DOWN` / `ENTER` — move right
- `BACK` — return to menu

**Touch**
- Tap left half / right half → move left / right (held while finger is down)
- Swipe ← / → → start moving in that direction

## Architecture

| File | Role |
| --- | --- |
| `GameController.mc`   | State, score, screen-relative physics scaling, camera scroll |
| `Player.mc`           | Position, velocity, AABB, draw |
| `PlatformManager.mc`  | Procedural generation, recycling, type distribution |
| `Platform.mc`         | Per-platform state (type, movement, breakable countdown) |
| `Physics.mc`          | Gravity / jump constants (rescaled at runtime by screen height) |
| `InputHandler.mc`     | Tap / button / swipe → horizontal intent |
| `MainView.mc`         | Brick-wall background, snow caps, platforms, player, HUD |

## Build

```bash
bash _build_all.sh jumptower
```

Artifacts:
- `_PROD/jumptower.prg`
- `_STORE/jumptower.iq`
