# Flappy Pidgeon

A Garmin-flavoured "Flappy Bird" clone — tap to flap, skim through the gaps between obstacles, and chase your best distance as the world scrolls faster and faster.

## What is it

An endless-runner with very simple kinematics (one vertical velocity, one gravity constant) and procedurally generated obstacle pillars. The pidgeon is drawn procedurally (no PNG sprites), so the game runs identically on every screen size. Difficulty scales smoothly: gap height shrinks, world speed grows, and pillar spacing tightens.

## How to play

- Tap (or press a button) to **flap** — gives the bird a small upward kick.
- Avoid the top, bottom, and any obstacle pillars.
- Each pillar passed = +1 score. Best distance is persisted.
- Hitting a pillar or the ground ends the run.

## Controls

**Buttons**
- Any key (`UP`, `DOWN`, `SELECT`, `ENTER`) → flap
- `BACK` → return to menu

**Touch**
- Tap anywhere → flap

## Architecture

| File | Role |
| --- | --- |
| `GameController.mc`  | State, score, difficulty scaling, game over |
| `Bird.mc`            | Position, velocity, AABB collider, procedural sprite draw |
| `ObstacleManager.mc` | Spawns, recycles, and draws the pipe pairs |
| `Physics.mc`         | Gravity / flap constants and the AABB helper |
| `InputHandler.mc`    | Tap / button → flap |
| `MainView.mc`        | Render loop + tick |

## Build

```bash
bash _build_all.sh flappypidgeon
```

Artifacts:
- `_PROD/flappypidgeon.prg`
- `_STORE/flappypidgeon.iq`
