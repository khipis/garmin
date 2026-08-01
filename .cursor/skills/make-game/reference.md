# MAKE_GAME — full reference

Canonical clones: **jazzball** (simple B), **bomb** (SaveResume), **sudoku** (ASC), **fish** (Progress). Playbooks: `tools/MENU_CONVERSION.md`, `LEADERBOARD.md`.

## Scaffolding

| Path | Purpose |
|------|---------|
| `<slug>/manifest.xml` | Unique UUID, entry, products, permissions |
| `<slug>/monkey.jungle` | `source;../_shared/leaderboard;../_shared/menu` (+ `;../_shared/progress`) |
| `source/Bitochi*App.mc` | `logLaunch` + `getInitialView` → menu |
| `source/*Menu.mc` | GameHooks + MenuConfig |
| `source/*View.mc` / `*Delegate.mc` | Gameplay (Family A/B/C) |
| `resources/strings.xml` | AppName |
| `resources/drawables.xml` + `launcher_icon.png` | ~70×70 |
| `title.md` / `description.md` | Store copy helpers |
| `README.md` | Controls, scoring, save |

**Permissions:** `Communications` (LB). Add `Sensor` for tilt/accel/gyro. `minSdkVersion="4.0.0"`. Store version is portal-side (upload bumps N+1), not XML.

## Menu / hooks

`MenuConfig`: `:gameId :title1 :title2 :col1 :col2 :brand :bg :circle :accent :lbTitle :hooks :options`  
`brand` default `"by Bitochi"`.

| Hook | Role |
|------|------|
| `startGame()` | Required — clear save + push gameplay |
| `hasResume` / `resumeGame` | SaveResume |
| `drawArt` | Signature art ~±40×±22 of center |
| `lbVariant` | Must match submit variant |
| `footerText` | Best/wins |
| `openBoard` | Multi-board (fish) |
| `hasReset` / `resetProgress` | Idle wipe |

`GmOption(key, label, values, defaultIndex)` — stores index. `.gatedFrom(i)` → Entitlement.

Shared menu rows include **RESUME** when `hasResume()` is true (plus START / OPTIONS / HOW TO PLAY / LEADERBOARD / NICKNAME).

## Leaderboard

```mc
Leaderboard.submitScore(gameId, score, variant);
Leaderboard.showPostGame(gameId, variant, "TITLE");
```

Optional: `submitScoreWithMeta`, `submitScoreAux`, `submitScoreBatch`. Never raw parallel `makeWebRequest` — use shared queue. Reuse one `Timer` in wait loops (never `new Timer.Timer()` each tick).

ASC: `leaderboard/src/index.ts` → `ASC_GAMES` (+ `ASC_GAMES_SET` if used) and `leaderboard/index.html` → `ASC_GAMES_HOF`. Deploy worker after.

Web: `GAMES` `{ id, label, ciq, lb? }`, `GAME_DESCS`, `GAME_GENRES`. Heroes: `heroes/<id>_hero.png`.

## SaveResume

Keys: `sr_<gameId>`. API: `exists` / `load` / `save` / `clear` / `confirmExit(gameId, method(:exportSave))`.

- `exportSave` → Dictionary (prompt) or null (pop quietly)
- `startGame` clears; win/lose clears
- Checkpoint mid-run for long sessions
- No network/clear in `onHide` while save Menu2 is up

## Progress

Jungle `../_shared/progress`. `Progress.checkIn()` after `logLaunch` (fish). Coins/XP/owns for cosmetics.

## Build / store

1. Add slug to `_build_all.sh` `APPS=(...)`
2. `./_build_all.sh <slug> store` → `_STORE/<slug>.iq`
3. `store-upload/apps.config.json` entry with `"iq": "_STORE/<slug>.iq"`
4. First publish: create app in Garmin portal (title, icon, `_LOGOS` screenshot)
5. `cd store-upload && node index.mjs upload --only <slug> --headless --rm-on-success`
6. Descriptions: `descriptions.json` + `describe --only <slug> --publish`

Also: `assemble_submit.py` APPS if still used; root README hero thumb.

## Pitfalls

- Phantom BACK after swipe/drag — arm gesture, swallow ~800ms (`blobs`)
- `lbVariant` ≠ submit → wrong board
- ASC missing → inverted ranks
- `hidden` not on module functions / timer callbacks
- Don’t redefine shared class/const names
- Folder ≠ submit id → web `lb:` key

## End-to-end checklist

1. Scaffold + UUID + products + permissions  
2. Jungle → shared paths  
3. Resources (strings, icon)  
4. Gameplay Family A/B/C  
5. Menu + `logLaunch`  
6. `submitScore` + `showPostGame` (+ ASC)  
7. Optional SaveResume / Progress  
8. Build green  
9. Hero 1440×720 + stamps + site `heroes/`  
10. Website catalog  
11. `_build_all.sh` + store-upload config  
12. Upload (if asked)  
13. Root README  
