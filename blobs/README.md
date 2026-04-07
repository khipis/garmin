# Bitochi Blobs

Free-for-all artillery deathmatch on a scrolling battlefield. Destroy all enemy blobs before they destroy you.

## Gameplay

Turn-based FFA combat on randomly generated terrain with a map **2x wider than the screen**. Camera scrolls to follow the action. You (blue blob) fight 2–4 AI enemies that scale in number and toughness.

### Controls

| Input | Action |
|-------|--------|
| **Tilt** (accelerometer) | Move blob (MOVE phase) / Aim angle (AIM phase) |
| **Tap** (select/enter) | Confirm move → Confirm fire |
| **Up/Down** buttons | Cycle through 6 weapons |

### Turn Flow

1. **MOVE** — Tilt to hop left/right (40px energy limit per turn). Tap when done.
2. **AIM** — Tilt to set angle (10°–80°). Power bar oscillates. Tap to fire.
3. Watch the shot fly, camera follows the projectile.
4. Explosion, damage, terrain craters. Next blob's turn.

### Weapons (6)

| Weapon | Dmg | Blast | Speed | Special |
|--------|-----|-------|-------|---------|
| **ROCKET** | 1 | 20px | Fast | Reliable all-rounder |
| **GRENADE** | 1 | 26px | Medium | Bounces twice before exploding |
| **MEGA** | 2 | 36px | Slow | Power bar 50% faster — high risk/reward |
| **SNIPER** | 1 | 12px | Very fast | 75% wind resistance — precision long-range |
| **MIRV** | 1×3 | 16px×3 | Medium | Splits into 3 explosions on impact |
| **QUAKE** | 1 | 50px | Medium | Horizontal blast only — massive crater, hits wide |

### Mechanics

- **Scrolling map** — 520px wide battlefield (2x screen), camera auto-follows active blob and projectiles
- **Minimap** — bottom bar shows all blob positions and camera viewport
- **Destructible terrain** — every explosion carves craters; blobs fall if ground disappears
- **Free-for-all** — AI blobs target player (65% bias) or each other; friendly fire happens
- **Movement** — each turn you get 40px of tilt-controlled movement before firing
- **Wind** — shifts each turn, affects all weapons (Sniper resists 75%)
- **Proximity damage** — edge hits from 2-damage weapons deal only 1

### Progression

| Rounds | Blobs | AI HP |
|--------|-------|-------|
| 1–2 | 3 (1v2) | 2 |
| 3–4 | 4 (1v3) | 2 |
| 5–6 | 4 (1v3) | 3 |
| 7–8 | 5 (1v4) | 3 |
| 9+ | 5 (1v4) | 4 |

Player always has 3 HP. AI accuracy improves with rounds.

### AI Behavior

- Targets player 65% of the time, other AI 35%
- Picks MEGA/MIRV when target is at 1 HP
- Compensates for wind when aiming
- Moves randomly 0–2 hops per turn
- Accuracy error shrinks from ±22° (round 1) to ±4° (round 13+)

### Visual Themes

5 rotating sky/terrain themes: Night, Crimson, Forest, Frost, Desert.

## Build

```bash
SDK="/path/to/connectiq-sdk/bin"
"$SDK/monkeyc" -d fenix7 -f blobs/monkey.jungle -o blobs/bin/bitochiblobs.prg -y developer_key.der
```
