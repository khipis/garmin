# Jump Tower

A Doodle-Jump-style endless climber for Garmin watches. Bounce up an infinite tower of snow-capped platforms, dodge breakables, ride moving platforms, launch off springs and jetpacks, grab coins, and chase your best height through four altitude zones — all the way to space.

## What is it

A vertical infinite-runner with procedural platform generation and a screen-relative physics pass — gravity, jump velocity, and horizontal speed all scale with the watch's screen height so the jump arc feels identical on a Vivoactive and a Fenix. Platforms have white snow caps, icicles, and type-specific accents (spring coil, breakable cracks, moving arrows, jetpack rocket). The backdrop itself changes as you climb: a brick-walled ground floor gives way to a bright sky with drifting clouds, then a starry stratosphere, then deep space with a passing planet.

## How to play

- The hero bounces automatically — every time they touch the **top** of a platform.
- You only steer **horizontally**: the screen wraps left ↔ right.
- Platform types:
  - **Normal** — solid.
  - **Moving** — slides left/right; ride it.
  - **Breakable** — collapses after one jump.
  - **Spring** — sends you twice as high.
  - **Jetpack** — rare, shows up once you're past the first few rungs. Launches you into a ~2 s flight straight through everything above, vacuuming up coins along the way.
- Coins float near the peak of most jumps — grab them for a per-run tally and a lifetime total. Lifetime coins unlock permanent cosmetic frog skins (Ice → Gold → Diamond); your best single-run haul gets its own leaderboard category.
- Climbing 150 m / 400 m / 800 m crosses into a new altitude zone (Sky / Stratosphere / Space) — the world visibly changes and you get a small coin bonus for reaching it.
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
| `GameController.mc`   | State, score, coins/skins/zones, jetpack timer, screen-relative physics scaling, camera scroll |
| `Player.mc`           | Position, velocity, AABB, skin-tinted draw |
| `PlatformManager.mc`  | Procedural generation, recycling, type distribution, coin spawn/collection |
| `Platform.mc`         | Per-platform state (type, movement, breakable countdown, coin) |
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
