# OPTIONS rollout — add a real setting to every "empty options" game

## Goal
Each listed game currently has `:options => []` in its `<Name>Menu.mc`. The shared
"Full version" row is now hidden, so these games would show an EMPTY OPTIONS screen.
Add **exactly one** meaningful, gameplay-affecting setting per game that:

1. Appears as a cycler on the shared OPTIONS screen (via `GmOption`).
2. **Persists** across app restarts (GmOption already writes `Application.Storage`
   on cycle — you just add it to the config; no extra persistence code needed).
3. Is **read at game start** and actually changes gameplay.
4. **Segments the global leaderboard**: the game must submit scores with a
   variant string that matches the chosen setting, AND the menu's `lbVariant()`
   must return that same string so the LEADERBOARD row shows the matching board.

Do NOT re-enable the Full version row. Do NOT touch `_shared/`. Keep each game's
existing art, colors, title, and gameplay intact — only add the one setting.

## The exact pattern (reference: minigolf, already done)

### 1) `<Name>Menu.mc` — add the option + variant
```monkey_c
// in buildXMenu():
:options => [
    new GmOption("<KEY>", "<LABEL>", ["<V0>","<V1>","<V2>"], <DEFAULT_IDX>)
]

// in the Hooks class:
function lbVariant() as Lang.String {
    var names = ["<var0>", "<var1>", "<var2>"];   // must match submit strings
    var i = <DEFAULT_IDX>;
    try {
        var v = Application.Storage.getValue("<KEY>");
        if (v instanceof Lang.Number && v >= 0 && v < names.size()) { i = v; }
    } catch (e) {}
    return names[i];
}
```
Make sure `using Toybox.Application;` and `using Toybox.Lang;` are imported in the menu file (most already are).

### 2) Gameplay view — read the setting at init and apply it
Find where the game view initializes / starts a round. Read the stored index and
translate it into whatever the game uses (speed multiplier, gap px, lives, gravity,
count, deck size, etc.). Example:
```monkey_c
var idx = 1;
try {
    var v = Application.Storage.getValue("<KEY>");
    if (v instanceof Number && v >= 0 && v <= 2) { idx = v; }
} catch (e) {}
// then map idx -> concrete gameplay parameter(s)
```
The effect MUST be real and noticeable (not cosmetic). Prefer difficulty/speed/count.

### 3) Submit with the matching variant
Find every `Leaderboard.submitScore(...)` / `submitScoreWithMeta(...)` /
`showPostGame(...)` call for this game and pass the SAME variant string that
`lbVariant()` returns for the current setting. Add a small helper in the view:
```monkey_c
hidden function _lbVariant() {
    var names = ["<var0>","<var1>","<var2>"];
    return names[<the idx you read at init>];
}
```
Then: `Leaderboard.submitScore(LB_GAME_ID, score, _lbVariant());`
and if the game shows a post-game card: `Leaderboard.showPostGame(LB_GAME_ID, _lbVariant(), "<TITLE>");`

If a game currently submits with variant `""` or a fixed string, REPLACE it with
the per-setting variant. If a game has a secondary variant (e.g. "aces"), leave that
as-is.

### 4) Build & verify
```
SDK="/Users/kkorolczuk/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b"
"$SDK/bin/monkeyc" -o /tmp/<app>.prg -f <app>/monkey.jungle -y developer_key.der -d fenix8solar51mm -l 0
```
Must print `BUILD SUCCESSFUL` (run from repo root `/Users/kkorolczuk/work/garmin`).

## Per-game assignments (setting is a strong suggestion — adapt names to the code,
## but keep ONE setting, keep it gameplay-affecting, and segment the LB)

| game | KEY | LABEL | values | default idx | variant strings | gameplay effect |
|---|---|---|---|---|---|---|
| arcade | arc_axes | Axes | ["3","5","7"] | 1 | ax3/ax5/ax7 | number of axes/throws per game |
| flappypidgeon | fp_gap | Gap | ["WIDE","NORMAL","TIGHT"] | 1 | wide/normal/tight | pipe gap size |
| dinosaur | dino_spd | Speed | ["NORMAL","FAST","INSANE"] | 0 | s0/s1/s2 | base run/scroll speed |
| run | run_spd | Speed | ["NORMAL","FAST","INSANE"] | 0 | s0/s1/s2 | base run/scroll speed |
| serpent | sp_spd | Speed | ["SLOW","NORMAL","FAST"] | 1 | slow/normal/fast | snake step rate |
| bricks | br_diff | Difficulty | ["EASY","NORMAL","HARD"] | 1 | easy/normal/hard | ball speed / paddle width |
| moon | moon_diff | Difficulty | ["EASY","NORMAL","HARD"] | 1 | easy/normal/hard | gravity / fuel |
| jumptower | jt_diff | Difficulty | ["EASY","NORMAL","HARD"] | 1 | easy/normal/hard | rise speed / platform gap |
| jazzball | jb_diff | Difficulty | ["EASY","NORMAL","HARD"] | 1 | easy/normal/hard | ball count / speed |
| fish | fish_diff | Difficulty | ["EASY","NORMAL","HARD"] | 1 | easy/normal/hard | bite window / reel difficulty |
| edgesurvivor | es_diff | Difficulty | ["EASY","NORMAL","HARD"] | 1 | easy/normal/hard | spawn rate / speed |
| catapult | cat_diff | Difficulty | ["EASY","NORMAL","HARD"] | 1 | easy/normal/hard | wind / target distance |
| parachute | pc_wind | Wind | ["CALM","BREEZY","GUSTY"] | 1 | calm/breezy/gusty | horizontal wind strength |
| boxing | box_diff | Difficulty | ["EASY","NORMAL","HARD"] | 1 | easy/normal/hard | opponent speed / damage |
| blackjack | bj_decks | Decks | ["1 DECK","2 DECKS","6 DECKS"] | 2 | d1/d2/d6 | number of decks in the shoe |
| poker | pk_hands | Hands | ["10 HANDS","20 HANDS","40 HANDS"] | 1 | h10/h20/h40 | session length before game over (score = chips at end) |
| bomb | bomb_diff | Difficulty | ["EASY","NORMAL","HARD"] | 1 | easy/normal/hard | inspect the game and map to its main difficulty knob (mine count / timer / grid) |

Notes:
- If a game's gameplay genuinely can't support the suggested setting after reading
  the code, pick the closest sensible alternative (still one setting, still
  gameplay-affecting, still segmenting the LB) and note what you chose.
- Keep default index so the DEFAULT play experience is unchanged from today where
  possible (e.g. if a game was effectively "normal", default to the NORMAL index).
- Report a short table: game | KEY | values | variant | what gameplay param it drives | BUILD result.
