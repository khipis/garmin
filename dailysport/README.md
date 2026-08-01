# Daily Sport Challenge

One skill test a day, identical for every player on the planet. The challenge is
derived from the date itself, so there is no server deciding anything — two
watches on opposite sides of the world open the app on the same morning and get
the same sport, the same objective and the same conditions.

Six sports rotate through it. All art is drawn from `Dc` primitives; there are
no bitmaps, and every position is derived from the screen size, so a 208px round
watch and a 454px AMOLED run the same simulation at different densities.

## Controls

Three taps, always the same three, whatever the sport.

| Beat | Input | What it sets |
|---|---|---|
| Aim | tap / SELECT | locks the launch angle off the sweeping meter |
| Power | tap / SELECT | locks the launch speed off the sweeping meter |
| Release | tap / SELECT | the timing window — how cleanly the shot comes out |

Missing the release window does not void the shot, it skews the angle. The
tighter your release, the closer the projectile flies to the line you aimed.

MENU opens the game menu. BACK ends a live run into the result card, and from
there pops back to the shared menu.

## The rotation

| Sport | The shot | Perfect | Scores |
|---|---|---|---|
| BASKETBALL | jump shot at a hoop | swish | rim, bank |
| FOOTBALL | free kick over a keeper | top corner | any goal |
| ARCHERY | flat, fast arrow | gold | red, blue |
| TENNIS | serve past the net cord | ace | ball in |
| GOLF | chip at a pin | holed | tap-in, on the green |
| HILL RIDE | ski jump off a lip | K-point | big air, landed |

Each sport supplies its own launch band, so the aim meter never spends most of
its sweep on angles nobody would use — a free kick and a chip are not played
from the same range.

**Which sport, which day.** A plain hash would happily serve archery four days
running. Instead each six-day cycle is a permutation of the roster (a stride
coprime with six, plus an offset), so every sport comes round exactly once per
cycle and the order still changes week to week. Tomorrow's sport is shown on the
result card.

## Objectives

The objective rotates independently of the sport, giving 24 combinations.

| Objective | Win condition |
|---|---|
| SPRINT | most scores before the clock runs out |
| PERFECT | only the perfect result counts |
| STREAK | longest unbroken run of scores |
| TARGET | the target moves |

## Fitness, and what it can and cannot buy

Steps and active minutes convert into **extra ranked attempts** and energy;
calories convert into coins. Fitness never converts into points. A player who
walked 20,000 steps gets more goes at the same challenge, not a better score per
go — otherwise the daily ranking would measure the day's walk instead of the
day's skill.

## Practice

Any sport, any day, unranked and free. Practice runs never touch the
leaderboard, the streak or the personal best, so there is no reason not to use
them to learn a sport before its day comes round.

## Unlocks

Three projectile skins (standard, golden, flame) and four venues (day, night,
sunset, stadium), earned against lifetime totals. Cosmetic only.

## Leaderboard

Scores post to the global board under a `<sport>-<objective>` variant, so a
football sprint and a golf streak are ranked separately and every board is a
like-for-like comparison. Runs are stored locally and upload when the watch next
syncs, so the game is fully playable offline.

## Source layout

| File | Role |
|---|---|
| `DailySportApp.mc` | app entry, view and delegate wiring |
| `GameEngine.mc` | the clock, the objective, the score, the aim/power/release state machine |
| `DsSport.mc` | the sport interface, the roster and the day → sport permutation |
| `SportBase.mc` | shared layout, power curve, flight loop, guide and FX for every sport but basketball |
| `SportBasketball.mc`, `SportFootball.mc`, `SportArchery.mc`, `SportTennis.mc`, `SportGolf.mc`, `SportHillRide.mc` | one sport each: geometry, verdict, field art |
| `PhysicsEngine.mc` | projectile integration, drag, bounce, trajectory prediction |
| `ChallengeManager.mc` | the daily seed → sport + objective + conditions |
| `ProgressionManager.mc` | streaks, energy, personal bests, unlocks |
| `LeaderboardManager.mc` | variant naming and score submission |
| `FitnessIntegration.mc` | steps and active minutes → attempts, calories → coins |
| `UIManager.mc` | briefing card, HUD, meters, result screen |
| `DsArt.mc`, `DsSportArt.mc` | drawing primitives, shared and per-sport |
| `DailySportMenu.mc` | the shared Bitochi menu hooks and the attract screen |

`GameEngine` never learns what sport it is running. A sport supplies the
geometry, the simulation and the field art; the four outcomes (perfect, two
lesser scores, miss) mean the same thing everywhere even though every sport has
its own word for them. That fixed vocabulary is what lets one challenge manager,
one scoring table and one leaderboard serve a ski hill and a free kick without
knowing about either.

## Adding a sport

1. Subclass `DsSportBase`, implementing `_place` (field geometry), `_verdict`
   (what happened mid-flight), `_deadEnd` (the shot is over and scored nothing)
   and `_drawScene`.
2. Add its id and display name to `DsSports.ROSTER` / `IDS`, its constructor to
   `DsSports.create`, and its vocabulary to `DsSports.nouns`.
3. Bump `DsSports.count()` and the cycle length in `indexForDay`.
4. Add its label to `DS_SPORTS` in `leaderboard/index.html` so the new variants
   render with a name instead of a slug.
