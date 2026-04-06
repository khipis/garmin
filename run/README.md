# BitochiRun

Horror chase escape game for Garmin watches. Accelerometer-driven with intense haptic feedback. Part of the Bitochi game family.

## Gameplay

You're trapped in darkness. Find the exit. Run for your life. Something is behind you.

### Game Phases:
1. **Scan** (~25s time limit) - Move your wrist to sweep a flashlight beam through darkness. Find the real exit among decoys and traps
2. **Run** - Shake your wrist to sprint! Dodge obstacles, manage stamina, grab power-ups. The monster is right behind you
3. **Escape or Die** - Reach the exit door or get caught

### 7 Levels / Monsters:
| Level | Monster | Behavior |
|-------|---------|----------|
| 1 | Vexor | Fast but stops to taunt |
| 2 | Undead | Steady relentless chase |
| 3 | Dzikko | Random speed bursts |
| 4 | Rocky | Gets faster with your progress |
| 5 | Batsy | Erratic wobbling speed |
| 6 | Emilka | Slow then sudden spike |
| 7 | Polacco | Slow but constantly creeping faster |

## Features

### Scan Phase
- Flickering flashlight with jitter and dimming
- Monster footstep vibrations getting closer over time
- 25-second time limit (monster finds you if too slow)
- Trap lights that waste your time
- Radar pulse rings for warm/cold indicator
- Random jump scares (monster eyes appear briefly)
- Decoy exits that look like the real one

### Run Phase
- 3-lane obstacle dodging (UP/DOWN buttons)
- Stamina system (can't sprint when exhausted)
- Power-ups: Speed Boost (blue), Shield (green)
- Monster lunges with warning double-vibration
- Progressive heartbeat vibrations (closer = faster + stronger)
- Screen blood-red vignette increasing with danger
- Flickering corridor lights
- Dripping walls, scratches, rubble details
- Player footprint trail
- Monster with teeth, claws, glowing eye trail

### Atmosphere
- Pulsing darkness overlay
- Scratching vibrations
- Between-level horror messages ("You hear something...", "Don't look back")
- Score tracking with high score persistence

## Controls

| Button | Action |
|--------|--------|
| Select | Start / Continue / Retry |
| UP | Dodge left (during run) |
| DOWN | Dodge right (during run) |
| Wrist movement | Scan direction / Sprint speed |
| Back | Exit |

## Build

```bash
cd run
monkeyc -o bin/run.prg -f monkey.jungle -y ../developer_key.der -d fenix7x
monkeydo bin/run.prg fenix7x
```
