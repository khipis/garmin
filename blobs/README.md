# Bitochi Blobs

Artillery deathmatch game for Garmin Connect IQ watches. Destroy the enemy blob before it destroys you.

## Gameplay

Turn-based artillery combat on randomly generated terrain. You are the **blue blob**, facing off against an **AI opponent** that gets tougher each round.

### Controls

| Input | Action |
|-------|--------|
| **Tilt** (accelerometer) | Aim angle (10°–80°) |
| **Tap** (select/enter) | Fire at current power |
| **Up/Down** buttons | Cycle weapon |

### Weapons

| Weapon | Damage | Blast Radius | Speed | Notes |
|--------|--------|-------------|-------|-------|
| **ROCKET** | 1 HP | Medium (20px) | Fast | Reliable all-rounder |
| **GRENADE** | 1 HP | Large (26px) | Medium | Bounces twice — great for lobbing over hills |
| **MEGA BOMB** | 2 HP | Huge (36px) | Slow | Power bar oscillates 50% faster — high risk, high reward |

### Mechanics

- **Destructible terrain** — explosions carve craters, blobs fall if ground is destroyed beneath them
- **Wind** — changes direction and strength each turn, affects all projectiles
- **Proximity damage** — edge hits from MEGA BOMB deal reduced (1 HP) damage; center hits deal full
- **Self-damage** — standing too close to your own explosion costs 1 HP
- **Smoke trails** and **dirt splashes** on grenade bounces for visual feedback

### Progression

- Each round is a fresh deathmatch on new terrain
- **Player HP**: always 3
- **AI HP**: 3 (rounds 1–2) → 4 (rounds 3–5) → 5 (rounds 6–8) → 6 (round 9+)
- **AI accuracy** improves with rounds (starts sloppy, becomes precise ~round 13)
- **AI weapon selection** is strategic — picks MEGA BOMB when you're at 1 HP
- **AI compensates for wind** in its aim calculations
- **Win streak** is your score — saved persistently via Application.Storage

### Visual Themes

5 rotating sky/terrain themes across rounds:
1. **Night** — deep blue sky, green grass
2. **Crimson** — red/pink sunset, dry terrain
3. **Forest** — dark green atmosphere
4. **Frost** — purple/grey sky, slate ground
5. **Desert** — warm browns and sand tones

### UI Features

- "YOUR TURN!" / "ENEMY TURN" flash between turns
- Weapon name with color in HUD, `< ROCKET >` arrows hint at Up/Down switching
- Wind strength indicator with directional arrows
- HP shown as fraction (e.g. `3/3`, `2/6`) for both blobs
- Floating damage numbers on hits
- "DODGED!" when AI misses, "DIRECT HIT!" / "CRITICAL!" for center hits
- "NEW BEST!" flash when setting a streak record
- Victory firework particles on win

## Build

```bash
SDK="/path/to/connectiq-sdk/bin"
"$SDK/monkeyc" -d fenix7 -f blobs/monkey.jungle -o blobs/bin/bitochiblobs.prg -y developer_key.der
```

## Project Structure

```
blobs/
├── manifest.xml
├── monkey.jungle
├── resources/
│   ├── drawables.xml
│   ├── launcher_icon.png
│   └── strings.xml
├── source/
│   ├── BitochiBlobsApp.mc
│   ├── BitochiBlobsDelegate.mc
│   └── BitochiBlobsView.mc
└── bin/
    └── bitochiblobs.prg
```
