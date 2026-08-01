# Backrooms Run

A pseudo-3D psychological horror escape game for Garmin Connect IQ. A real
Wolfenstein-style raycasting engine renders endless yellow rooms in first
person, on a watch, at a stable frame rate and without a single bitmap.

## The run

You noclipped out of reality. Two things are running out at once:

- **Sanity** always drains, three times faster in the dark and faster still
  while something has line of sight on you. Almond water restores it.
- **Torch battery** burns only while the beam is lit. Spare cells are rare, so
  turning the light on is a decision rather than a default.

Reaching an exit does not end the run, it drops you one level deeper — darker,
denser, hungrier. A run ends when sanity hits zero, or at the five-minute cap.

Also down there: keys (open the locked door in front of the exit room) and
artifacts (score, and a permanent count).

## Controls

| Input | Action |
|-------|--------|
| Swipe up · START/SELECT · tap upper screen | Walk forward |
| Swipe left / right · UP / DOWN buttons · tap side | Turn |
| Swipe down · tap lower screen | Use / pick up / listen |
| LIGHT · long press | Torch |
| MENU | Panic sprint (costs breath, then sanity) |
| BACK | Save & quit prompt |

Movement eases in and out: a swipe tops up a short walk window rather than
teleporting you a cell, and turning ramps up and back down.

## What is down there

- **The Stalker** — watches from the end of a corridor, gone by the time you
  reach it, and starts a step closer every few runs. Under the beam it stops
  pretending it has not noticed you.
- **The Shadow** — only exists while the lights are out. Meeting its eye holds
  it still and feeds it; turning away is safe and lets it close in. The torch
  is the one thing that burns it off, which is what the battery is really for.
- **The Mimic** — wears the same exit sign as the real way out. You learn which
  one it was by touching it.

Events do most of the work: the lights die, footsteps, the walls genuinely
rearrange, the corridor stretches, a fake exit wakes up, something follows.

## Modes

- **Endless** — a fresh procedural floor set every run.
- **Daily** — everyone gets the identical maze from today's seed.

## Leaderboards

`Time` (longest run), `Depth` (deepest level), `Escape` (lifetime exits found),
`Daily` (today's seeded run).

## Code map

| File | Role |
|------|------|
| `BrConst.mc` | Tuning, palette ramps, level/entity/event tables |
| `MapGenerator.mc` | Seeded floors as row bitmasks; rooms, corridors, specials |
| `Raycaster.mc` | DDA grid cast, pre-allocated output arrays |
| `Renderer.mc` | Perspective grids, textured wall columns, billboards, post |
| `PlayerController.mc` | Position, camera, easing, collision |
| `EntityManager.mc` | Stalker / Shadow / Mimic behaviour |
| `EventManager.mc` | The floor's mood: darkness, glitch, shake, wall shifts |
| `SaveManager.mc` | Lifetime stats, leaderboard submits, resume blob |
| `BackroomsView.mc` | Game loop, HUD, run end |
| `BackroomsDelegate.mc` | Input manager |
| `BackroomsMenu.mc` | Shared menu / options / multi-board picker |

Three implementation notes worth keeping in mind when editing:

- **Palette.** Garmin MIP panels quantise to four levels per channel, which
  turns subtle dark olives into grey and maroon. Colours are therefore picked
  from ramps that already sit on the device grid, and distance shading selects a
  ramp index rather than multiplying channels. The three planes also sit in
  different hues — grey tiles, yellow wallpaper, brown carpet — because three
  warm greys on that panel become one.
- **Texture without bitmaps.** Surfaces get their grain from perspective grids
  that converge on the vanishing point, a per-column hash of `(cell, u-bucket)`
  that nudges the ramp index so neighbouring columns differ, horizontal trim
  (picture rail, wainscot, skirting), and a dark pixel line at every corner.
  Nothing is sampled and nothing is allocated inside the frame.
- **Determinism.** Floors are rebuilt from `(seed, level)`, so the mid-run save
  is a handful of numbers and the daily challenge is identical for everyone.

`_LOGOS/_compose_backrooms_face.py` is a Python port of the renderer used to
produce the store hero. If you change the constants or the drawing order here,
change them there too or the marketing shot stops matching the game.
