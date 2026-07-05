# BitochiMinigolf

20-hole minigolf course for Garmin smartwatches, with lives, a ball-per-hole
allowance, hazards, and a points-based global leaderboard.

## How to Play

1. Tap away from the ball (or use UP/DOWN) to aim, then press SELECT / tap the
   ball to start charging power.
2. Tap or press SELECT again to fire — the ball rolls with real rolling
   friction and bounces off walls and obstacles.
3. Sink the ball before you run out of balls for that hole, then tap to move on.
4. Run out of balls on a hole → lose a life. Lose all 3 lives (or finish all
   20 holes) and the run ends.

## Features

- **20 hand-designed holes** — straight corridors, doglegs, a windmill, a
  diamond bumper court, a pinball cluster, a spiral, and a Boss Finale combo
  hole, each with its own par and layout.
- **Tunnel-proof billiards-style physics** — adaptive substepping so fast
  shots never punch through thin rails, with side-aware wall reflection.
- **Hazards:**
  - **Water** — ball resets to its last position, +1 stroke penalty.
  - **Sand traps** *(new)* — heavy extra rolling friction; the ball keeps
    going, it just bleeds speed fast. Placed on holes 4, 18 and 20.
  - **Boost pads** *(new)* — conveyor-style push in a fixed direction while
    the ball's centre is inside; thread the gap and get a satisfying kick
    toward the cup. Placed on holes 10 and 20.
  - **Animated obstacles** — a rotating windmill (hole 6) and swinging
    pendulum bumpers (hole 17).
- **3 lives, shrinking ball allowance** — the number of balls you're allowed
  per hole shrinks as the course progresses (and with difficulty), so late
  holes demand cleaner play.
- **Hole-in-one celebration** *(new)* — sinking on your first stroke banks a
  big bonus, shows "HOLE IN ONE!!!", triggers a screen-shake + vibration, and
  counts toward the `aces` leaderboard variant for the run.
- **Flawless Round bonus** *(new)* — finish all 20 holes without ever losing
  a life for a big end-of-run points bonus and a "FLAWLESS ROUND!" badge.
- **Ball trail** *(new)* — a short fading trail follows the ball while it
  rolls, for a bit of extra juice.
- **Cached course rendering** *(new)* — the static parts of each hole
  (fairway, walls, water, sand, boost pads, tee, cup) are rendered once into
  an off-screen bitmap and blitted every frame instead of being redrawn from
  scratch, cutting per-tick draw calls substantially on hazard-heavy holes.
- **Two wall themes** — thin painted rails vs chunky pinball-bumper rails,
  per hole.
- **Difficulty levels** — Easy/Normal/Hard change your ball allowance margin
  (+3/+2/+1 over par), not the hole layouts.

## Controls

- **Tap away from ball** — set aim direction (stays in aim mode to fine-tune)
- **Tap on ball / SELECT** — start charging power, tap/SELECT again to fire
- **UP/DOWN** (in aim) — rotate aim ±10°
- **UP/DOWN** (in power) — fire immediately
- **BACK** — return to menu

## Scoring

Points (not strokes) are the leaderboard metric — higher is better:

- **+500** for sinking a hole, plus **+100** per ball left unused (so a quick
  birdie/eagle scores more than a hole you barely scraped in).
- **+750** hole-in-one bonus, on top of the normal sink reward.
- **+1000** Flawless Round bonus if you never lose a life across all 20 holes.

## Leaderboard

The main score (points, higher is better) is submitted per **difficulty**
variant (`easy` / `normal` / `hard`) so skill levels rank separately. Total
hole-in-ones for the run are also mirrored to an `aces` leaderboard variant,
viewable on the web leaderboard's variant chips for "minigolf".
