# BitochiJump

Ski jumping simulator for Garmin watches. Physics-based with retro pixel-art style, part of the Bitochi game family.

## Gameplay

Compete with 5 Pets characters across 2 rounds of ski jumping. Master the inrun speed, nail the takeoff timing, and control your lean during flight for maximum distance.

### Jump Phases:
1. **Character Select** - Choose your jumper (UP/DOWN to browse, SELECT to start)
2. **Inrun** - Speed bar oscillates, press to lock speed at the right moment
3. **Takeoff** - Timing window with sweet spot. Press/shake at the perfect moment for maximum quality
4. **Flight** - Control lean with UP/DOWN buttons or wrist tilt. Forward lean = more lift but more drag
5. **Landing** - Telemark bonus for correct lean position on touchdown

### 5 Jumpers:
| Character | Style | Special |
|-----------|-------|---------|
| Chikko | Neurotic chicken | Balanced, panics |
| Foczka | Happy seal | Great flopper |
| Doggo | Loyal dog | Fast zoomer |
| Vexor | Angry demon | +15% speed, harder control |
| Emilka | Graceful girl | +35% lift, weaker takeoff |

## Features

- Realistic aerodynamic physics (lift, drag, gravity, wind)
- Variable wind with gusts during flight
- K-point and HS hill markers
- 2-round competition format with cumulative scoring
- Parallax mountain backgrounds
- Trees along the hillside
- Crowd at the bottom
- Snow particles affected by wind
- Trail effect behind jumper in flight
- Perfect takeoff flash effect
- Speed bar with sweet spot zone
- Wind indicator with arrows
- Score = distance + style (takeoff quality + landing + lean bonus)
- Haptic feedback on takeoff and landing

## Controls

| Button | Action |
|--------|--------|
| UP | Previous jumper / Lean forward |
| DOWN | Next jumper / Lean back |
| Select | Start / Jump / Continue |
| Physical shake | Takeoff trigger |
| Back | Exit |

## Build

```bash
cd jump
monkeyc -o bin/jump.prg -f monkey.jungle -y ../developer_key.der -d fenix7x
monkeydo bin/jump.prg fenix7x
```
