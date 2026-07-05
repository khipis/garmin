# BitochiFish

Fishing game with casting and fish fighting for Garmin smartwatches.

## How to Play

1. Tap to start the power bar, tap again to cast
2. Wait for a bite — react quickly when "BITE!" appears
3. Fight the fish by countering its pulls with wrist movement
4. Keep line tension balanced: too high = snap, too low = escape

## Features

- Power bar casting system
- Accelerometer-based fight controls (tilt to counter fish pulls)
- Line tension mechanic — balance is key
- 10 fish types: Minnow, Shrimp, Perch, Roach, Bass, Carp, Trout, Pike, Catfish, Tuna
- Each fish type has unique strength and appearance
- **Rarity system** — every hooked fish rolls Runt / Normal / Big / GIANT (10/68/17/5%),
  shifting its size, fight difficulty and final weight. GIANT catches get a shiny
  golden tint, extra sparkle, a bigger vibration and a bonus particle burst.
- **Randomised weight** — final weight = per-species base range × rarity multiplier
  × a small extra jitter, so no two catches (even same species/rarity) weigh exactly
  the same.
- Water surface with animated waves and ripple effects
- Splash and catch particle systems
- Combo scoring for consecutive catches
- Vibration intensity scales with tension danger

## Controls

- **Tap** — cast / set hook / advance
- **Tilt** — counter fish pull direction during fight

## Progression

- Fish difficulty scales with catches
- Bigger fish = more points but harder fights
- Combo multiplier for streaks
- Rarer catches (Big/GIANT) award bonus points on top of the species/combo formula

## Leaderboards

- Main "FISHING" board — total session score (submitted at game over)
- **"biggest-fish" board** — your all-time heaviest catch, submitted the instant it
  beats your personal record. Carries a small metadata blob (species + rarity) so
  the web leaderboard at bitochi.com can render a graphical, colour-coded fish
  avatar next to each entry instead of a plain number — GIANT catches glow gold.
