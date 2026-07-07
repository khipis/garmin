# Unified Menu — per-game conversion playbook

Goal: replace every game's hand-drawn main menu with the shared, unified menu in
`_shared/menu`, while preserving each game's vibe (title text/colours + a small
signature graphic) and moving its settings into the shared OPTIONS screen.

The shared module is DONE and validated on three pilots. Study these before
converting anything — they are the canonical references, one per architecture:

- Family A (MainView + InputHandler):        `pongpro/source/PongMenu.mc`, `MainView.mc`, `InputHandler.mc`, `PongProApp.mc`
- Family B (Bitochi*View + Bitochi*Delegate): `blobs/source/BlobsMenu.mc`, `BitochiBlobsView.mc`, `BitochiBlobsApp.mc`
- Family C (GameView + GameDelegate):         `tic_tac_pro/source/TicTacMenu.mc`, `GameView.mc`, `TicTacProApp.mc`

Shared API (in `_shared/menu`, all globally available once jungle includes it):
- `GameMenuView(cfg)` + `GameMenuDelegate(view)` — the root menu (always 3 rows: START / OPTIONS / LEADERBOARD).
- `MenuConfig(dict)` — keys: `:gameId :title1 :title2 :col1 :col2 :brand :bg :circle :accent :lbTitle :hooks :options`.
    - `:title2`, `:col2`, `:brand`, `:bg`, `:circle`, `:accent` are optional (sensible defaults). `brand` defaults to "by Bitochi".
- `GameHooks` — subclass and override: `startGame()` (REQUIRED), `drawArt(dc,cx,cy,w,h)`, `lbVariant()`, `footerText()`.
- `GmOption(key,label,valuesArray,defaultIndex)` — a settings cycler persisted in Application.Storage as the selected index. `.gatedFrom(i)` marks indices >= i as premium (routes to unlock while locked).
- `Entitlement.isUnlocked(gameId)` — foundation for full-version gating (already wired into OPTIONS).

## Steps for EACH game

### 1. jungle
Ensure `base.sourcePath` ends with `;../_shared/menu` (append after `../_shared/leaderboard`). Example:
```
base.sourcePath = source;../_shared/leaderboard;../_shared/menu
```

### 2. Create `<app>/source/<Name>Menu.mc`
Define a `<Name>Hooks extends GameHooks` and a `build<Name>Menu()` factory returning `[view, delegate]`.
- `startGame()`: push the game's REAL gameplay view + delegate with `WatchUi.pushView(v, new <Delegate>(v), WatchUi.SLIDE_LEFT)`.
- `drawArt(dc,cx,cy,w,h)`: reproduce the game's signature mini-graphic from its OLD `_drawMenu`/`drawMenu` (the little demo/logo/icon), re-centred around `(cx,cy)`. If the old menu had no graphic, draw a small tasteful emblem from the game's palette (a few shapes). Keep it within ~±40px of cx and ~±22px of cy.
- `lbVariant()`: return the SAME variant string the game submits to the leaderboard (read the difficulty/mode from Storage and map identically). If the game submits with `""`, return `""`.
- `footerText()`: if the old menu showed a best/wins/streak line, return it (read from Storage), else return null.

`MenuConfig`:
- `:gameId` = the game's leaderboard id (from `Leaderboard.logLaunch("...")` / `submitScore("...")`).
- `:title1`/`:title2` = the title lines from the old menu (keep the two-line split if it had one; otherwise title1 only). Match the old title COLOURS via `:col1`/`:col2`.
- `:bg`/`:circle` = the old menu background + round-inset colours (copy the hex the old `_drawMenu` used).
- `:accent` = green-ish START accent, default `0x34D399` unless the game had a distinct accent.
- `:lbTitle` = the title the game passed to `LbScoresView(...)` (usually the uppercase name).
- `:options` = one `GmOption` per SETTING the old menu had (difficulty, speed, mode, size, players…). REUSE the game's existing Storage key(s) if it already persisted them; otherwise pick a new key `"<prefix>_<name>"` and make the game read it at start. Values array = the display strings the old menu cycled through, in the SAME order/index the game expects.

### 3. App `getInitialView()`
Replace the body with `return build<Name>Menu();`.

### 4. Refactor the gameplay view to be menu-less (auto-start + BACK→menu)

Common rules for all families:
- The gameplay view must DROP STRAIGHT INTO PLAY (no in-game menu). Read all settings from Storage at start.
- Wherever the code did `if (state == GS_MENU) { drawMenu(dc); return; }` in `onUpdate`, replace with `if (state == GS_MENU) { <startGame>(); }` (then fall through to normal drawing).
- "Return to menu" (BACK, and any game-over "back to menu") must POP this view: delegate `onBack` → `WatchUi.popView(WatchUi.SLIDE_RIGHT)` (or return false so the framework pops). Do NOT return to an in-game menu state.
- Game-over "play again"/"new game" should RESTART the game in place (call the start/round function), NOT go to a menu.
- Remove menu navigation from the delegate/inputs (the shared delegate handles the menu now). Keep gameplay inputs.
- Keep ALL gameplay + leaderboard submit logic untouched.

Family A (see pongpro): auto-start on first `onUpdate` after layout via a `_started` flag; over-state SELECT/tap/swipe → restart; `onBack` pops.

Family B (see blobs): read settings in `initialize()`; in `onShow()` add `if (gameState == GS_MENU) { <startRound>(); }` (guard so returning from the post-game standing card does NOT restart); `onUpdate` menu branch → start; keep the delegate's sensor cleanup but have `onBack` return false / pop.

Family C (see tic_tac_pro): add `_applySettings()` that reads Storage keys and configures the board, call it before starting in `initialize()` (do NOT set `_state = GS_MENU` at the end); `onUpdate` menu branch → `_startGame()`; `doBack()` → `return false;`; game-over action → `_startGame()`.

### 5. Build & verify (MUST be green)
```
SDK="/Users/kkorolczuk/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b"
"$SDK/bin/monkeyc" -o /tmp/<app>.prg -f <app>/monkey.jungle -y developer_key.der -d fenix8solar51mm -l 0
```
Iterate until `BUILD SUCCESSFUL`. Fix any errors you introduced. Do not leave a game failing.

## Gotchas
- `hidden` is NOT allowed on functions inside a `module` (only inside classes).
- Don't redefine shared consts (`GM_START`, etc.) or shared class names.
- Monkey C dictionaries in `MenuConfig` use symbol keys (`:gameId => ...`).
- Method refs: subclass `GameHooks`; don't pass raw `method(:x)` into config.
- If a game has NO settings, `:options => []` (OPTIONS will still show "Full version" unlock — that's intended).
- Preserve the exact leaderboard variant the game already uses on submit; `lbVariant()` must match it or the LEADERBOARD row shows the wrong board.
- Some games read a setting only inside their old menu cycle handlers — make sure the gameplay path now reads it from Storage at start.
