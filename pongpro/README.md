# Pong Pro

A polished Pong for Garmin Connect IQ — you vs. AI, first to the score limit wins, with three AI difficulty levels and proper paddle-hold physics.

## What is it

Classic Pong with deliberately tuned physics: angle reflection on paddle contact, vertical "english" added based on where the ball hits, and a small speed boost per paddle hit so rallies escalate. AI ranges from a simple ball-tracker (Easy) to a predictive trajectory with wall-bounce projection (Hard). Continuous paddle motion uses `onKeyPressed` / `onKeyReleased` so holding a button moves the paddle smoothly instead of one step at a time.

## How to play

- First player to the score limit wins the match.
- In the menu: pick AI difficulty (Easy / Medium / Hard) with `UP` / `DOWN` and start with `SELECT`.
- During the rally: keep your paddle aligned with the ball; bounce it past the AI.

## Controls

**Buttons (menu)**
- `UP` / `DOWN` — cycle AI difficulty
- `SELECT` / `ENTER` — start match
- `BACK` — exit

**Buttons (in-match)**
- Hold `UP` — move paddle up
- Hold `DOWN` — move paddle down
- `BACK` — return to menu

**Touch**
- Tap top half / bottom half → nudge paddle up / down (one step per tap)
- Swipe up / down → continuous-direction paddle motion until released

## Architecture

| File | Role |
| --- | --- |
| `GameController.mc` | State machine, score, serve / play / over phases, hold-motion driver |
| `Ball.mc`           | Position, velocity, angle reflection helpers |
| `Paddle.mc`         | Position, height, clamping |
| `AIController.mc`   | Easy / Medium / Hard strategies (track / lead / predict) |
| `InputHandler.mc`   | Hold-aware key routing + menu nav + swipe |
| `MainView.mc`       | Layout, render, tick |

## Build

```bash
bash _build_all.sh pongpro
```

Artifacts:
- `_PROD/pongpro.prg`
- `_STORE/pongpro.iq`
