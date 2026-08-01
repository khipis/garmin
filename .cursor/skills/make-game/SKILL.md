---
name: make-game
description: >-
  Scaffold and ship a new Garmin Connect IQ game for the bitochi.com catalog:
  shared menu/LB/_shared wiring, optional SaveResume and Progress, hero logo
  (_LOGOS 1440x720 with watch left, title and By Bitochi right, LEADERBOARD and
  bitochi.com stamps), website + worker entries, _build_all.sh, store packaging
  and upload. Use when the user says MAKE_GAME, make a new game, scaffold a
  Connect IQ title, add a game to the leaderboard site, or generate a store hero.
---

# MAKE_GAME — ship a new Bitochi game

Repo: `garmin/`. Clone **jazzball** (simple), **bomb** (SaveResume), **sudoku** (ASC), **fish** (Progress).

Ask only: **slug**, **title**, score ASC vs DESC, SaveResume yes/no, Progress yes/no, one-line pitch + genre. Then execute every applicable step. Do not commit/push/upload unless asked.

Details: [reference.md](reference.md) · Code: [TEMPLATES.md](TEMPLATES.md) · Art: [HERO.md](HERO.md)

## Pipeline

### 1. Identity + scaffold

| Field | Rule |
|-------|------|
| `slug` | lowercase folder = LB `gameId` (prefer same string everywhere) |
| `entry` | `Bitochi{Name}App` |
| UUID | new `iq:application id=` |
| Permissions | `Communications`; + `Sensor` if tilt/gyro |
| Jungle | `source;../_shared/leaderboard;../_shared/menu` (+ `;../_shared/progress`) |

Copy products list from bomb/jazzball. Resources: `AppName`, `launcher_icon.png` (~70×70), drawables.xml.

### 2. Shared menu (required)

`{Name}Menu.mc` + App `getInitialView()` → `build{Name}Menu()`; `onStart` → `Leaderboard.logLaunch(slug)`.

Implement `GameHooks`: `startGame`, `drawArt`, `lbVariant`, `footerText`; optional `hasResume`/`resumeGame`.

Gameplay has **no** in-game main menu — settings from Storage; BACK pops (or SaveResume). Architectures: A MainView+InputHandler · B BitochiView+Delegate · C GameView+Delegate (`tools/MENU_CONVERSION.md`).

### 3. Leaderboard (required)

On game-over:

```mc
Leaderboard.submitScore(slug, score, variant);
Leaderboard.showPostGame(slug, variant, "TITLE");
```

ASC (lower better): add to `leaderboard/src/index.ts` `ASC_GAMES` (+ `ASC_GAMES_SET`) and `leaderboard/index.html` `ASC_GAMES_HOF`; deploy worker when shipping.

Never parallel raw `makeWebRequest`; reuse one Timer in wait loops.

### 4. SaveResume (optional)

`_shared/menu/SaveResume.mc` — keys `sr_<gameId>`.

- Hooks: `hasResume` / `resumeGame` / `startGame` clears  
- BACK: `SaveResume.confirmExit(slug, method(:exportSave))`  
- Export full live state; checkpoint long runs; clear on win/lose  
- Phantom BACK after swipe: see blobs  

### 5. Progress (optional)

Jungle `../_shared/progress`; `Progress.checkIn()` after `logLaunch` (fish pattern).

### 6. Website

`leaderboard/index.html`: `GAMES` `{ id, label, ciq }`, `GAME_DESCS`, `GAME_GENRES`. Copy hero → `leaderboard/heroes/<slug>_hero.png`. Mismatch folder/submit → `lb:` key.

### 7. Hero `_LOGOS` (required)

**1440×720**: watch + gameplay left · **NAME** + **By Bitochi** right · stamps TL LEADERBOARD + BR bitochi.com.

```bash
python3 .cursor/skills/make-game/scripts/gen_hero.py \
  --slug <slug> --title "Title" --screen path/to/face.png --stamp
# or stamp only:
python3 .cursor/skills/make-game/scripts/stamp_one.py <slug>
cp _LOGOS/<slug>_hero.png leaderboard/heroes/<slug>_hero.png
```

Do **not** re-run `_LOGOS/_stamp_leaderboard.py` on the whole folder (stacks badges). See [HERO.md](HERO.md).

### 8. Build + store config

1. Add slug to `_build_all.sh` `APPS=(...)`  
2. `./_build_all.sh <slug> store` → `_STORE/<slug>.iq`  
3. `store-upload/apps.config.json`: `"iq": "_STORE/<slug>.iq"` (+ appId after first portal create)  
4. Upload only if asked:  
   `cd store-upload && node index.mjs upload --only <slug> --headless --rm-on-success`  
5. Root `README.md` hero thumb; optional `_LOGOS/_manifest.json`, `descriptions.json`

### 9. Done when

- [ ] Opens on shared menu; START / OPTIONS / HTP / LB / NICK work  
- [ ] RESUME only with save; START clears  
- [ ] Score + variant correct; ASC/DESC on site  
- [ ] Exit save prompt if enabled  
- [ ] Hero stamped; site catalog + heroes copy  
- [ ] Store build green; config points at IQ  

## Agent default order

1. Confirm identity + flags  
2. Scaffold + jungle + App/Menu/View/Delegate  
3. LB (+ ASC) + optional SaveResume/Progress  
4. Website + hero  
5. `_build_all.sh` + store config; build; upload only on request  
