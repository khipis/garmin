# BitochiCatapult

Physics-based catapult destruction game for Garmin watches. Retro pixel-art, part of the Bitochi game family.

## Gameplay

Launch Pets characters from a catapult to destroy castles and defeat bosses across 7 rounds of escalating difficulty.

### Phases per shot:
1. **Set Angle** - Oscillating marker, press to lock launch angle (20-75 degrees)
2. **Set Power** - Oscillating power bar, press to lock power. Trajectory preview shown
3. **Flight** - Watch your pet fly! Wind affects trajectory
4. **Impact** - Splash damage destroys blocks and hurts the boss

### 7 Rounds:
| Round | Boss | HP | Castle |
|-------|------|----|--------|
| 1 | Blobby | 45 | Small tower |
| 2 | Chikko | 70 | Twin towers |
| 3 | Dzikko | 100 | Walled fort |
| 4 | Rocky | 140 | Large fortress |
| 5 | Vexor | 185 | Night fortress |
| 6 | Emilka | 160 | Complex castle |
| 7 | Batsy | 200 | Ultimate fortress |

## Features

- Realistic projectile physics with gravity and wind
- 3 block types: Regular (grey), Reinforced (brown, 2 hits), Explosive (red, chain reaction!)
- Critical hits on direct enemy contact (2x damage, gold particles)
- Combo multiplier for consecutive damaging shots
- Dynamic wind per round (shown on HUD)
- Screen shake on impact
- Chain reaction explosions
- Animated clouds (day) / starfield (night, rounds 5+)
- Grass detail, dramatic particle effects
- Boss expressions change (angry when hit, scared at low HP)
- 4 shots per round
- Victory sparkle animation
- Haptic feedback on impacts

## Controls

| Button | Action |
|--------|--------|
| Select | Lock angle / Lock power / Continue |
| Any button | Same as Select |
| Back | Exit |

## Build

```bash
cd catapult
monkeyc -o bin/catapult.prg -f monkey.jungle -y ../developer_key.der -d fenix7x
monkeydo bin/catapult.prg fenix7x
```
