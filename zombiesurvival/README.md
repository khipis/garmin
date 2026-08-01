# Zombie Survival: Last Stand

An idle base defence for Garmin Connect IQ, driven by the steps you actually
walk.

You never run a character. You spend the day earning scrap from real movement,
you spend it on walls and turrets, and at 21:00 local the horde arrives on its
own. The defences fight it whether the watch is on your wrist or in a drawer.
The whole game is the hour before that — looking at the countdown and the
line **WE WILL NOT HOLD**, and deciding what one more upgrade is worth.

## Loop

1. **Day** — steps and workouts pay scrap; spend it on the base screen
2. **Countdown** — every screen carries `WAVE IN 4h 07m`
3. **Night** — at 21:00 the wave resolves by itself, once per calendar day
4. **Result** — held, or overrun

Open the watch during the wave and you see it play out: the horde walking in
down three lanes, your turrets firing, the wall coming apart. You cannot steer
any of it. The one thing presence buys you is **YOUR RIFLE** — hold SELECT and
the survivor at the barricade shoots at whatever is closest. It is a bonus for
turning up, never the plan.

Miss the night entirely and it is resolved headless on next open, in chunks
across a few frames so the watchdog stays happy, and the result screen is
waiting for you.

## Win and loss

Holding unlocks the next night, which is bigger and tougher. Being overrun
costs you **nothing you bought**: the same night comes back tomorrow, the wall
is rebuilt to full, and you keep every level and a reduced salvage payout.
A loss costs a day, not progress — the pressure is the calendar, not a wipe.

## What you buy

| Family | Items |
|--------|-------|
| Structure | Walls, Gate |
| Defences | MG Nest, Mortar, Tesla Coil, Spike Pit, Razor Wire, Your Rifle |
| Systems | Auto-Repair, Plating, Salvage |

Fifteen levels each, cost growing quadratically — income is flat (a day's
walking is a day's walking however deep you are), so anything gentler and a
committed player runs out of things to buy inside three months.

## Enemies

| Type | Reads as |
|------|----------|
| Walker | baseline shambler |
| Runner | leans forward, fast, fragile |
| Brute | wide shoulders, exposed ribs, armoured |
| Crawler | low silhouette, slips under fire |
| Spitter | acid sac, ranged damage on the wall |
| Screamer | jaw hanging open, pulls the wave forward |
| Abomination | every 5th night, hunched, furnace in the chest |

Each night's composition is generated from a seed derived from the night
number, so the preview screen and the wave you watch are the same wave.

## Simulation

`BattleSim.mc` is the only combat code. It runs frame-by-frame when you are
watching and headless when you are not, off the same tick function, so an
offline night and a watched night resolve identically apart from a ±12%
damage jitter that keeps the preview honest about being a guess.

`_balance.py` is a Python port of `BattleSim` and `WaveGen` used to sweep the
cost and difficulty curves over simulated months of play. Keep it in sync when
either formula changes.

## Boards

Furthest Night · Strongest Fort · Most Kills · Nights Held —
at [bitochi.com](https://bitochi.com)

## Controls

- **UP / DOWN** — move the cursor on the base screen
- **SELECT** — buy the selected upgrade; during a wave, hold to fire the rifle
- **Swipe / tap the bottom bar** — move between base and tonight's preview
- **BACK** — menu

## Source layout

| File | Holds |
|------|-------|
| `ZsConst.mc` | every tuning table and the 64-colour palette |
| `WaveGen.mc` | deterministic wave composition per night |
| `BattleSim.mc` | the simulation, watched and headless |
| `ZsArt.mc` | the scene: sky, city, street, barricade, turrets, sprites |
| `ZsHud.mc` | the base, preview, result and supply panels |
| `ZombieView.mc` | screen-flow state machine, daily clock, offline catch-up |
| `ZombieModel.mc` | persistent base, defence levels and lifetime stats |

`_LOGOS/_compose_zombie_face.py` is a Python port of `ZsArt.mc` used to render
store artwork without the simulator; keep it in sync when the geometry or the
palette changes.
