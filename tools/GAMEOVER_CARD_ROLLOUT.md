# Game-Over Card rollout playbook

## Goal
Fix cramped / overlapping end-of-run "summary card" text across games. On
high-DPI watches (e.g. 416×416 fenix 8) the old cards used HARD-CODED pixel
offsets (`by + 30`, `by + 46`, `by + bh - 14`) while fonts scale with DPI, so
the lines overlap and become unreadable.

A shared, font-height-aware renderer already exists and is available to every
game that links `../_shared/leaderboard` (all these games do):

```
GameOverCard.draw(dc, sw, sh, title, titleColor, lines, footer, accent)
```

- `dc`         — the draw context.
- `sw, sh`     — screen width/height (use the vars already in scope in that
                 function: `_sw/_sh`, `sw/sh`, `_ctrl.screenW/screenH`, or
                 `dc.getWidth()/dc.getHeight()` if none exist).
- `title`      — the big title string ("GAME OVER", "MISS", "TIME UP", "YOU WIN"…).
- `titleColor` — the title colour int (keep the game's existing colour).
- `lines`      — an **array of `[text, colorInt]`** stat rows, in top-to-bottom
                 order (e.g. `["Score " + score, 0xFFFFFF]`). May be empty `[]`.
- `footer`     — the bottom hint string ("Tap to retry", "Tap for menu",
                 "Any key for menu"…). Pass `""` or `null` to omit.
- `accent`     — the box border colour (use the border colour the card used; if
                 unsure use the title colour).

The renderer measures fonts with `dc.getFontHeight`, auto-sizes the box to the
content, vertically centres every line with guaranteed spacing, and centres the
card on screen. It uses FONT_SMALL for the title and FONT_XTINY for lines/footer.

## What to change
For each file: find the **end-of-run summary card** — a block that draws a
rounded rectangle box, then a title, then stat line(s), then a footer hint.
Replace ONLY that block with a single `GameOverCard.draw(...)` call that
reproduces the SAME title text/colour, the SAME stat lines (same variable
expressions and any conditional NEW BEST / Best branches → build the `lines`
array conditionally BEFORE the call), and the SAME footer text.

Build the array conditionally, e.g.:

```monkeyc
var lines = [ ["Score " + ctrl.score.format("%d"), 0xFFFFFF] ];
if (ctrl.score == ctrl.best) { lines.add(["NEW BEST!", 0x22FF88]); }
else if (ctrl.best > 0)      { lines.add(["Best " + ctrl.best.format("%d"), 0x88AABB]); }
GameOverCard.draw(dc, _sw, _sh, "GAME OVER", 0xFF4466, lines, "Tap to retry", 0xFF4466);
```

## Rules
- Preserve exact strings, number formatting, and conditional logic.
- If the game has BOTH a win card and a lose card (different title/colour),
  convert BOTH.
- Convert only boxed **stat-summary** cards. DO skip: pure menu screens, HUD,
  in-game transient banners, and win/lose screens that are NOT a boxed summary
  (e.g. a full-screen animation). If a listed file has no such card (only a
  footer-hint string), SKIP it and report "no card".
- Keep it minimal: don't touch unrelated code. Don't rename anything.
- Do NOT edit the shared helper.

## Build check (run after editing all files in your batch)
```
SDK="/Users/kkorolczuk/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b"
"$SDK/bin/monkeyc" -o /Users/kkorolczuk/work/garmin/_PROD/<app>.prg \
  -f /Users/kkorolczuk/work/garmin/<app>/monkey.jungle \
  -y /Users/kkorolczuk/work/garmin/developer_key.der -d fenix8solar51mm -l 0
```
`<app>` is the top folder name. Every game in these batches uses
`developer_key.der` (NOT the old key). A successful build prints
`BUILD SUCCESSFUL`.

## Report back
Per app: converted? (yes / no-card), how many cards, and build result
(SUCCESSFUL / FAILED + first error line).
