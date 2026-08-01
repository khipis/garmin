# Hero logo (`_LOGOS`) — MAKE_GAME

## Spec

| Item | Value |
|------|--------|
| Output | `_LOGOS/<slug>_hero.png` |
| Size | **1440×720** (2:1) |
| Layout | Watch + game screen **left** · title + **By Bitochi** **right** |
| Site copy | `leaderboard/heroes/<slug>_hero.png` (`HERO_BASE = 'heroes'`) |
| Store | `assemble_submit.py` → `_SUBMIT/<app>/screenshot_1.png` |
| Catalog | `_LOGOS/_manifest.json` entry (`dir`, `app_name`, `desc`, …) |
| Root README | `![slug](_LOGOS/slug_hero.png)` |

## Visual recipe

1. Atmosphere background (dark game-tinted gradient — not flat white unless intentional).
2. Left half: Garmin-style round watch with bezel; face = real gameplay screenshot (sim crop or in-game capture). Screen must look circular / clipped to the watch face.
3. Right half: large **GAME NAME** (uppercase or Title Case matching brand), below it **By Bitochi** (smaller, muted).
4. Leave margins for stamps (top-left ~80px, bottom-right ~80px).

## Pipeline

```bash
# A) Compose base (watch left + title right)
python3 .cursor/skills/make-game/scripts/gen_hero.py \
  --slug mygame --title "My Game" \
  --screen /path/to/gameplay.png \
  --stamp

# Or compose only, then stamp that one file:
python3 .cursor/skills/make-game/scripts/gen_hero.py \
  --slug mygame --title "My Game" --screen shot.png
python3 .cursor/skills/make-game/scripts/stamp_one.py mygame
```

`stamp_one.py` applies:

1. **LEADERBOARD** badge top-left (vivid accent from image) — **not idempotent**
2. **bitochi.com** cyan pill bottom-right — safe to re-run

Repo-wide stamps (`_LOGOS/_stamp.py`, `_stamp_leaderboard.py`) process **every** `*_hero.png` — do **not** re-run leaderboard stamp on the whole folder or badges stack.

## Screenshot source

- Prefer Connect IQ simulator capture of live gameplay (not the menu).
- Crop to the round face (black bezel edge) before passing `--screen`, or pass a square face crop and let `gen_hero.py` circular-mask it.
- AI full-bleed heroes: generate watch-left / title-right composition, then `diceroyale/_resize_hero.py`-style center-crop to 1440×720, then `stamp_one.py`.

## After hero

```bash
cp _LOGOS/<slug>_hero.png leaderboard/heroes/<slug>_hero.png
# update _LOGOS/_manifest.json if maintaining the catalog
# root README.md thumbnail row
```
