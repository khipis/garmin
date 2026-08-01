# Tower Defense

Top-down tower defense for Garmin Connect IQ. 30 waves, 7 towers with 4 visible
upgrade tiers, 7 enemy types with boss fights every 5th wave, wave modifiers,
two player abilities, and an economy where hoarding pays interest.

All art is drawn from `Dc` primitives — there are no bitmaps. Every position is
derived from the playfield square, so a 208px round watch and a 454px AMOLED run
the same game at different densities.

## Controls

Everything is reachable with four buttons; touch is a shortcut layered on top.

| Action | Button | Touch |
|---|---|---|
| Move cursor between build pads / menu rows | UP / DOWN | swipe up / down |
| Confirm (build, upgrade, sell, start wave, retry) | SELECT | tap the bottom sheet |
| Open the ability picker (from the map) | MENU or long press | tap an ability chip |
| Back out of any open sheet | MENU or long press | swipe left, or tap the map |
| Select a specific pad or tower | — | tap it |
| Save and exit mid-run | BACK | BACK |

The bottom sheet always names exactly what SELECT will do right now, and shows
`UP/DN n/total` while a sheet is open, so no action is ever hidden.

**Cursor slots.** Between waves the cursor walks all build pads plus one extra
**START WAVE** slot after the last pad. During a wave the START slot disappears
and the cursor stays on the pads, so towers can still be upgraded, retargeted or
sold under fire.

**Sheets.** Selecting an empty pad opens the shop (7 towers + BACK). Selecting a
built tower opens UPGRADE / TARGET / SELL / BACK. MENU from the map opens
AIRSTRIKE / DEEP FREEZE / BACK. The two ability chips are always visible at the
left and right edges with their cost and a radial cooldown sweep.

## Towers

Tiers run 1–4. Each tier adds damage, cuts cooldown, extends range and visibly
changes the silhouette; tier 4 unlocks the special. Gold pips on the plinth show
the tier without selecting the tower. Sell refunds **60%** of everything invested.

| Tower | Cost | Role | Air | Tier-4 special |
|---|---|---|---|---|
| TURRET | 45 | Cheap all-rounder | yes | twin barrel |
| FROST | 70 | Pulses a slow onto everything in range | yes | deep chill |
| ARCHER | 75 | Fast, longest cheap range | yes | double shot |
| FLAME | 85 | Short cone, shreds swarms | no | burn stacks |
| CANNON | 95 | Slow lobbed shell with splash | no | wide blast |
| TESLA | 130 | Chains between nearby enemies, pierces armor | yes | 4× chain |
| SNIPER | 150 | Huge single hit, pierces armor | yes | crit ×2 |

Each tower has its own targeting priority, cycled from the tower sheet:
**FIRST** (furthest along the path), **STRONGEST** (most HP), **CLOSEST**.
Towers swing to face their target rather than snapping, and keep tracking while
they reload.

## Enemies

| Enemy | Behaviour | Counter |
|---|---|---|
| GRUNT | Baseline walker | anything |
| RUNNER | Fast, fragile | FROST, FLAME |
| TANK | 3× HP, armored, slow | CANNON, SNIPER |
| FLYER | Ignores the road, flies straight to the base | ARCHER, TESLA, TURRET |
| SHIELD | Heavy flat armor, immune to chip damage | SNIPER, TESLA (pierce) |
| HEALER | Beams health into wounded neighbours | kill it first |
| BOSS | Every 5th wave, 10× HP, one rotating ability | stacked raw damage |

Boss abilities rotate **RAGE** (speeds up when hurt) → **WARD** (cycles a heavy
armor shell) → **SUMMON** (spawns escorts beside itself) → **REGEN** (steady
trickle that punishes a slow kill).

## Wave modifiers

Announced on the build screen before the wave, with the counter it wants:

- **SWARM** — many, weaker; wants splash
- **ARMORED** — extra flat armor; wants big hits
- **BLITZ** — 35% faster; wants slows
- **AIR RAID** — mostly flyers; cannons and flame cannot reach them
- **BOSS** — every 5th wave

## Abilities

| Ability | Cost | Cooldown | Effect |
|---|---|---|---|
| AIRSTRIKE | 65c | ~23s | Bombs the 5 enemies nearest the base, ignoring armor |
| DEEP FREEZE | 40c | ~17s | Chills every enemy on the field and chips them |

## Economy

- Kill rewards scale with enemy type (5c grunt → 70c boss).
- Wave-clear bonus: `18 + wave × 4` (+6 on HARD).
- **Interest**: 6% of your unspent bank each wave clear, capped at 45c — so
  skipping a build is a real strategic option, not just a mistake.
- Daily check-in from the shared `Progress` streak adds starting coins.

## Feedback loop

Every wave clear shows a summary: coins earned, the two towers that actually did
the work (kills and damage that wave), leaks, and one concrete suggestion derived
from what went wrong — flyers leaking with no anti-air, armor soaking more than a
third of your damage with no piercing tower, a tower that never fired, or a bank
you are sitting on. On defeat the same diagnosis appears next to the wave you
died on and your leak count, and SELECT restarts the same map instantly.

## Options (persisted via `GmOption` → `Application.Storage`)

- **Map** — BEND / SNAKE / RING / GATE / DAILY
- **Difficulty** — EASY / NORMAL / HARD (base HP 25 / 18 / 12)
- **Pace** — NORMAL / FAST (enemy and projectile speed)
- **Coach tips** — ON / OFF (the post-wave suggestion line)

### Maps

- **BEND** — long straights; range and travel time, easy to learn
- **SNAKE** — stacked switchbacks; one pad can cover two lanes
- **RING** — a spiral of corners into a central base
- **GATE** — an hourglass that pinches twice; a centre pad hits both lanes
- **DAILY** — layout and every wave derived from a seed shared by all players on
  a given calendar day, always on NORMAL for fairness

## Score / leaderboard

```
score = wave × 1000 + kills × 12 + coins + damage / 10  (+6000 for clearing all 30)
```

Two boards are submitted per run: the score board and a `-wave` auxiliary board
carrying the furthest wave reached.

Variants: `bend-normal`, `bend-easy`, `bend-hard`, `snake-*`, `ring-*`, `gate-*`,
and `daily`. The `-wave` board appends `-wave` to the same string, e.g.
`snake-hard-wave`. Map names 0–2 keep their original spelling so previously
seeded boards stay comparable.

## Shared stack

- `_shared/menu` — unified menu, OPTIONS, entitlement hook
- `_shared/leaderboard` — submit + post-game + daily challenge
- `_shared/menu/SaveResume` — mid-run save on BACK (`exportSave` / `loadResume`
  carry map, difficulty, seed, wave, coins, base HP, ability cooldowns and every
  tower's type, pad, tier, targeting mode and invested cost)
- `_shared/progress` — daily check-in streak / coin bonus

## Files

| File | Role |
|---|---|
| `BitochiTowerDefenseApp.mc` | Entry point, pushes the shared menu |
| `TowerDefenseMenu.mc` | `GameHooks` wiring, options, signature menu art |
| `BitochiTowerDefenseView.mc` | Simulation + draw order; all pools allocated once |
| `BitochiTowerDefenseDelegate.mc` | Button and touch input |
| `TdArt.mc` | Every pixel: terrain, towers, enemies, projectiles, FX, HUD |
| `TdConst.mc` | Enums, pool sizes, palette and all balance tables |
| `TdMap.mc` | Four path layouts and their build pads |
