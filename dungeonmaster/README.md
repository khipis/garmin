# Dungeon Master: Watch Crawler

First-person pseudo-3D dungeon crawler RPG for Garmin Connect IQ, in the spirit
of *Dungeon Master* and *Eye of the Beholder* — compressed into a 2–10 minute
expedition. Fifteen floors down, and the only way to win is to climb back out.

Everything on screen is drawn from `Dc` primitives. There is not a single bitmap
in the app.

## Controls

The design rule: a fenix with no touchscreen must reach every system — spells,
items, gear, map — using only the five hardware buttons.

| Input | Action |
|-------|--------|
| SELECT / tap / swipe up | Context action, and **confirm** in every menu |
| UP / swipe left | Turn left, and **move the cursor up** in every menu |
| DOWN / swipe right | Turn right, and **move the cursor down** in every menu |
| swipe down | Sound the walls for a secret, or take the stairs you're standing on |
| MENU (long SELECT) | Open the pack; press again to cycle its three pages |
| BACK | Leave a submenu, then offer to save and exit |

The primary action is context-sensitive: whatever blocks the corridor decides
whether you walk, open a door, force a lock, sound a wall, drink from a fountain
or swing a sword. The prompt above the HUD always says which.

In combat, UP/DOWN move around a five-slot action wheel and SELECT confirms.
**SPELLS** and **ITEMS** open a second wheel of the same shape; BACK steps back
out of it. The pack's three pages are items, the character sheet, and the full
explored map.

## Systems

| Module | Role |
|--------|------|
| `DmConst.mc` | Tile codes, monster/item/spell/XP tables, zone light ramps, seeded `DmRng` |
| `DungeonMap.mc` | Floor grid + `DungeonGenerator` (rooms, archetypes, doors, secrets, traps, features) |
| `Raycaster.mc` | `Camera` + DDA raycaster; exposes distance, side, wall offset and hit tile |
| `DungeonRenderer.mc` | Masonry walls, sconces and light pools, flagstones, sprites, all the props |
| `CharacterSystem.mc` | Stats, XP/levels, mana, inventory, equipment, fitness bonus |
| `CombatSystem.mc` | Turn resolution, spell effects, per-monster and per-boss behaviour |
| `BitochiDungeonMasterView.mc` | Game engine, every screen, save/leaderboard |

Movement is on a grid — tile centres, cardinal facing — so the raycaster needs
no trigonometry, and rays are only re-cast when the camera actually moves. The
renderer allocates every scratch buffer once in `initialize()`; nothing in
`onUpdate` or the timer allocates.

## Look

Wall dressing is *derived*, never stored. A hash of `(tileX, tileY, side)`
decides whether a face carries a torch, moss, an alcove or a banner, so the
decoration costs zero RAM, stays put as you walk around it, and rebuilds
identically from a saved seed.

The palette is the other half of it. The weakest panels in the catalogue are
ARGB2222 — two bits per channel, 64 colours in total — and multiplying a brown
by a light factor makes its channels cross those four levels at different
moments, so a receding wall visibly lurches from tan to rose to grey. Instead
each of the five zones has a hand-picked six-rung light ramp whose every entry
is already a legal colour, and surfaces pick a rung rather than doing arithmetic:
walls at the rung, mortar and floor below it, ceiling lower still. The picture is
pixel-identical on a MIP fenix and an AMOLED venu, and every step is deliberate.

Per floor you get: coursed masonry with staggered joints, soot-dark stones, moss
and cracks, alcoves with skulls, hanging banners, iron sconces whose flame
flickers and whose light pools across the surrounding columns, plank-and-iron
doors (locked ones wear a riveted lock plate), a beamed ceiling, receding
flagstones, and a real descending stairwell.

## Dungeon

Floors are generated from `(seed, floor)` and are therefore reproducible — which
is how the save system stores a seed instead of a map, and how the **daily
dungeon** hands everyone the identical layout.

- 4–6 rooms linked by L-corridors, drawn from six archetypes: plain, crypt,
  library, treasury, arena, pillared hall
- Doors, locked doors, and up to three secrets per floor: a **stash**, a **vault**
  of gold, or a **passage** shortcut
- Traps: **spikes**, **dart** (poisons), **pit** (heavy, but drops you onward),
  **glyph** (burns and drains mana)
- Features: **old shrine** (pray free, or offer gold for better odds — it can
  bless or curse), **fountain** (heals and refills mana, but roughly one in five
  is tainted), **wandering trader** (potions, ethers, keys, bombs, and one weapon
  upgrade)
- Five zones of three floors each — the Old Keep, the Catacombs, the Flooded
  Halls, the Obsidian Depths, the Infernal Vault — each with its own stone,
  torch colour and monster mix
- A named boss on floors 5, 10 and 15. Floor 15's is the way out.

Locked doors can always be forced at the cost of HP, so a missing key can never
seal off the stairs — a key just saves you the blood.

## Monsters

| Monster | From | Tell |
|---------|------|------|
| Rat swarm | 1 | swarms — many small bites |
| Goblin | 1 | erratic — may swing twice |
| Skeleton | 2 | winds up, then hits hard |
| Spider | 2 | venomous fangs |
| Cultist | 4 | drains life and mana |
| Dead knight | 4 | heavy plate — blunt it down |
| Wraith | 7 | half-real — blows pass through |
| Ogre | 7 | slow slam — can stun |
| Demon | 10 | hellfire ignores armour |
| **Skeleton King** | 5 | raises bone armour |
| **Ancient Guardian** | 10 | stone form, then a quake |
| **Dungeon Beast** | 15 | enrages when wounded |

Any non-boss can turn up as an elite: **Savage** (hits harder), **Ironhide**
(soaks more), **Venomous** (always poisons) or **Arcane** (burns mana and bites
through armour). Elites carry a coloured aura and a fatter health bar.

The tell is printed under the health bar. Knowing the pattern is what makes the
fight tactical rather than a dice roll.

## Combat

```
damage = weapon + strength + small swing - enemy defense
```

Randomness is a narrow band, not the deciding factor. Crit chance scales with
luck; with the Amulet of Shadow a crit also opens a bleed.

- **ATTACK** — reliable
- **POWER** — 1.9×, three-turn cooldown
- **SPELL** — opens the spell wheel
- **GUARD** — halves the incoming hit and steadies you for a little HP
- **ITEM** — potion, ether or fire bomb

| Spell | Mana | Effect |
|-------|------|--------|
| Fireball | 7 | burns through armour |
| Frost Nova | 5 | freezes the next turn |
| Mend | 6 | restores health |
| Ward | 5 | absorbs the next blows |

Mages pay one less for everything, the Amulet of Focus another two. Mana trickles
back as you walk, and refills on the stairs.

## Loot and gear

Six tiers of weapon (Rusted Blade → Iron Sword → Steel Falchion → Crystal Blade
→ Rune Axe → **Demon Edge**) and six of armour (Rags → Padded Coat → Leather Mail
→ Chain Hauberk → Knight Plate → **Guardian Plate**). The character sheet shows
what each swap actually did to your numbers.

Also in the dark: gold, health potions, ether vials, scrolls of sight (reveal the
floor), iron keys, fire bombs, four rings (+4 STR / +3 DEF / +12 mana / +4 luck)
and three amulets (+25 max HP / spells cost 2 less / +3 magic and bleeding crits).

Rings and amulets always present as **LEGENDARY FIND**; high-tier gear as **RARE
FIND**. A rare drop should feel rare, so it gets its own card, its own colour and
its own light rays.

## Heroes and progression

| Class | HP | STR | DEF | MAG | LUCK | Mana | Kit |
|-------|----|-----|-----|-----|------|------|-----|
| Warrior | 46 | 7 | 4 | 0 | 2 | 8 | 2 potions, scroll |
| Rogue | 34 | 6 | 2 | 2 | 6 | 14 | 2 potions, scroll, bomb |
| Mage | 28 | 3 | 2 | 7 | 3 | 30 | potion, 2 ethers, 2 scrolls |
| Paladin | 42 | 5 | 5 | 4 | 2 | 20 | 2 potions, scroll |

XP comes from kills, newly mapped ground, every find, every secret and every
descent. Each level offers a choice: **+12 HP**, **+2 STR**, **+2 DEF**,
**+2 MAG and +8 mana**, or **+2 LUCK**.

## Score

```
score = deepestFloor×1000 + gold + level×60 + kills×25
      + secrets×80 + bossKills×400 + 2500 if you escaped
```

Submitted once per run with the floor, class and escape flag attached, so the web
board can show how the run ended. Variants: `normal`, `hard`, `daily`.

Death always names its cause — the monster and the floor, the trap, the cursed
shrine, the poisoned fountain, or the door that held when you did not.

## Options (persisted)

- **Hero** — Warrior / Rogue / Mage / Paladin
- **Difficulty** — Easy / Normal / Hard
- **Dungeon** — Random / Daily
- **Rumble** — haptic feedback on hits, finds and level-ups
- **Screen shake** — off for anyone who would rather it stayed still

Stored through the shared OPTIONS screen, so choices survive leaving the app.

## Fitness

Steps become **Adventure Energy**: up to 60 starting gold and two extra potions.
Active minutes add up to 10 max HP. Both are capped, so the day's walk helps a
run without replacing skill.

## Shared stack

`_shared/menu` (unified menu + OPTIONS), `_shared/leaderboard` (submit, post-game,
messages, daily), `_shared/menu/SaveResume` (mid-run save, auto-checkpointed on
every descent and level-up), `_shared/progress` (login streak).

The save holds the seed plus only what changed: which monsters died, what was
taken, which secrets were found and traps sprung, your sheet, and the explored
map as 16-bit row masks. Geometry and every stat table are rebuilt.

## Devices

Requires Connect IQ 4.0 (the shared menu, leaderboard and storage stack), which
is what sets the floor. **66 products / 80 device targets build clean**, from the
128 KB Instinct E up to the fenix 8. Watches older than CIQ 4.0 — vivoactive 3,
fr235 and the rest — cannot run the shared stack at all and are not listed in the
manifest.

```bash
monkeyc -o dungeonmaster.iq -f dungeonmaster/monkey.jungle -y developer_key.der -e -r
```
