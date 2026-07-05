# Pong Pro

A polished Pong for Garmin Connect IQ — you vs. AI, first to the score limit wins, with three AI difficulty levels and proper paddle-hold physics.

## What is it

Classic Pong with deliberately tuned physics: angle reflection on paddle contact, vertical "english" added based on where the ball hits, and a small speed boost per paddle hit so rallies escalate — serves also start a little faster as the match score climbs, and the ball's colour shifts from cool cyan to hot pink as it nears top speed, so escalation is visible, not just numerical. AI ranges from a simple ball-tracker (Easy) to a predictive trajectory with wall-bounce projection (Hard). Continuous paddle motion uses `onKeyPressed` / `onKeyReleased` so holding a button moves the paddle smoothly instead of one step at a time.

On top of that, a power-up pickup floats to the centre of the court every ~7-10 seconds of live play:

| Power-up | Effect |
| --- | --- |
| 🔵 **MULTIBALL** | Spawns a second ball for the rest of the rally — whichever ball exits first still scores the point, but juggling two balls gets chaotic fast |
| 🟢 **PADDLE UP** | Grows the paddle that most recently returned the ball by 50% for ~8 seconds |
| 🔴 **SHRINK RAY** | Shrinks the *opponent's* paddle (of whoever last returned the ball) by 35% for ~8 seconds |

Any ball touching the pickup triggers it — a big pulsing screen-edge flash + banner announces which one fired, and the affected paddle gets a coloured halo (green = grown, red = shrunk) for the buff's duration. The AI can trigger and benefit from power-ups exactly like the player, so it's a genuine two-sided arms race.

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
| `GameController.mc` | State machine, score, serve / play / over phases, hold-motion driver, power-up spawn/effect logic |
| `Ball.mc`           | Position, velocity, angle reflection helpers, speed-based colour, multiball cloning |
| `Paddle.mc`         | Position, height, clamping, grow/shrink resize + buff halo |
| `PowerUp.mc`        | Floating pickup: spawn position, pulse animation, AABB hit test, icon |
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
