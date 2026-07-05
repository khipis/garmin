# BitochiCatapult

Medieval catapult siege game for Garmin smartwatches.

## How to Play

1. Set your launch angle
2. Set your power
3. Fire a projectile at the enemy castle
4. Destroy the castle and defeat the enemy boss

## Features

- 16 unique rounds with escalating difficulty
- 16 fairy tale-themed backgrounds (enchanted forest, lava, ice, candy, etc.)
- 16 unique enemy bosses from Grumblor to Darkstar
- Wind system affecting projectile trajectory
- Destructible castle with physics-based blocks
- Camera preview of castle before each round
- Shop system with 8 power-ups (Mega Bomb, Fire Shot, Piercer, Triple, Poison,
  Cluster, **Homing Shot**, **Frost Shot**) plus Ammo +3, in a scrollable list
- **Homing Shot** — gently curves in flight toward the boss, forgiving small
  aiming misses
- **Frost Shot** — shatters any block it touches instantly and freezes the
  boss in place for a few seconds, making the follow-up shot easy money
- Parallax scrolling backgrounds, cached into an off-screen bitmap and
  repainted only when needed for smoother, faster rendering during the long
  aim/power phases
- Particle effects on impact

## Controls

- **Tap** — cycle through angle → power → fire
- **Tap** during preview — skip camera scout

## Scoring

- Points for castle blocks destroyed and enemy damage
- Gold earned per round for the shop
- Grade system at game completion

## Leaderboard

Besides the main score, a completed match also mirrors two extra stats to
their own global leaderboard variants, so bragging rights aren't just about
how far you got:

- `damage` — total HP damage dealt to bosses across the whole match
- `shots` — total shots fired across the whole match

Both are viewable on the web leaderboard's variant chips for "catapult".
