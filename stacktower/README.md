# Stack Tower

Endless one-tap block-stacking game. Each level a block slides across the screen — tap to drop it on top of the tower. The overhang is trimmed away, the next block gets narrower, and the camera scrolls up as the tower grows. How high can you build?

## What is it

A wrist-friendly take on "Stack" / "Tower Tap". The game lives in world coordinates and the renderer pans the camera so the player always sees the top few blocks. Speed ramps with height, block colours rotate through a hue sweep for visual depth, and precision drops (overlap within a few pixels) award bonus colour flashes.

## How to play

- A new block slides horizontally across the screen at the current height.
- **Tap** (or press `SELECT`) to drop it.
- Whatever doesn't land on top of the previous block is **chopped off**.
- If the entire block misses, it falls and the game ends.
- Each successful stack adds one floor to your tower, score = number of floors stacked.
- Block speed increases every few floors. A near-perfect drop (≤2 px overhang) plays a small "perfect" effect and keeps the next block at full width.

## Controls

**Buttons**
- `SELECT` / `ENTER` / `UP` / `DOWN` — drop the moving block
- `BACK` — return to menu

**Touch**
- Tap anywhere → drop the block

## Architecture

| File | Role |
| --- | --- |
| `GameController.mc` | State machine, level progression, score, persistence |
| `TowerManager.mc`   | List of stacked blocks, camera, drop / trim physics |
| `Block.mc`          | Position, width, colour, slide direction |
| `InputHandler.mc`   | Input routing |
| `MainView.mc`       | Layout + rendering + tick |

## Build

```bash
bash _build_all.sh stacktower
```

Artifacts:
- `_PROD/stacktower.prg`
- `_STORE/stacktower.iq`
