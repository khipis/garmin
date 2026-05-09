# Bitochi Othello Blitz

A complete Othello (Reversi) game for round Garmin watches with flip animation and a position-weight AI opponent.

---

## Rules

| Rule | Detail |
|------|--------|
| **Board** | 8×8 grid, starting with 2 Black + 2 White discs in the centre. |
| **Goal** | Have the most discs of your colour when the game ends. |
| **Valid move** | Place a disc so that at least one straight line (horizontal, vertical, or diagonal) of opponent discs is sandwiched between the new disc and an existing disc of yours. |
| **Capture** | All opponent discs along every valid sandwiching line are flipped to your colour. |
| **Pass** | If you have no valid move your turn is skipped automatically ("PASS!" is shown briefly). |
| **Game end** | When neither player has any valid move. Score = disc count on board. |

---

## Controls

| Input | Action |
|-------|--------|
| **UP button** | Cursor up |
| **DOWN button** | Cursor down |
| **Scroll-up / onPreviousPage** | Cursor left |
| **Scroll-down / onNextPage** | Cursor right |
| **SELECT** | Place disc (or new game when game over) |
| **BACK** | Exit to watch face |

The cursor turns **orange** when the highlighted cell is not a valid move. Small bright-green dots mark all legal positions.

---

## Flip Animation

After each disc placement, all captured opponent discs play a 300 ms squish-flip animation:

1. **Tick 0** (immediate) — placed disc appears; opponents still show old colour at full size.
2. **Tick 1** (+100 ms) — captured discs squish to ~⅔ height (old colour).
3. **Tick 2** (+200 ms) — captured discs squish to ~⅓ height, colour changes to new owner.
4. **Tick 3** (+300 ms) — `applyFlips()` commits the change; discs pop back to full size.

Implemented with `fillRoundedRectangle` height `= disc_radius × animTick / ANIM_TICKS`, no allocations.

---

## AI Opponent

The AI plays as **White** and uses a single-ply greedy heuristic evaluated across all 64 cells:

```
score = position_weight × 3 + flip_count + random_noise(0–2)
```

**Position weight table** (classic Othello strategy):

```
+40 -12 +20 +20 +20 +20 -12 +40   ← corners are highest
-12 -20  -5  -5  -5  -5 -20 -12   ← X-squares are worst
+20  -5 +10   0   0 +10  -5 +20
+20  -5   0 +10 +10   0  -5 +20
 …  (symmetric)
+40 -12 +20 +20 +20 +20 -12 +40
```

The AI strongly avoids squares adjacent to unclaimed corners (negative weights) and targets corners whenever possible. The `flip_count` secondary term provides a tiebreaker in equal-weight areas.

All computation is O(64 × 8 × 8) per move — well within a single 100 ms timer tick.

---

## Technical Notes

### Flip collection without allocation
`Board._cd()` scans each of the 8 directions with a **rollback pointer** (`ts = flipCount`). Opponent discs are tentatively added to `flipBuf`. If no anchoring own-disc is found at the end of the chain, `flipCount` is rolled back to `ts` — zero allocation, zero auxiliary buffer.

### Disc count tracking
`blackCount` / `whiteCount` are kept in sync via `placeDisc` (add 1) and `applyFlips` (add/subtract `flipCount`). The HUD reads these directly — no O(64) count loop per frame.

### State machine (100 ms timer)
```
GS_PLAYER  ──SELECT──►  GS_ANIM_P  ──animTick=0──►  GS_AI
    ▲                                                    │
    └─── _advanceTurn ◄── GS_ANIM_AI ◄── _doAiMove ◄───┘
```
Pass scenarios short-circuit: if the next player has no valid moves, `GS_AI` fires immediately (with a brief "PASS!" overlay), or `GS_OVER` is set if neither side can move.

### Valid-move cache
`_validMoves[64]` is computed once when transitioning to `GS_PLAYER` (not every frame). Dot rendering and cursor colour check read this pre-computed array in O(1).

---

## File Structure

```
othello_blitz/
├── source/
│   ├── OthelloApp.mc     – AppBase entry point
│   ├── GameDelegate.mc   – Input routing
│   ├── Board.mc          – Flip logic, validity, disc counts
│   ├── AI.mc             – Position-weight greedy AI (White)
│   └── GameView.mc       – Rendering, state machine, 100 ms timer
├── resources/
│   ├── strings.xml
│   ├── drawables.xml
│   └── launcher_icon.png
├── manifest.xml
├── monkey.jungle
└── README.md
```

---

## Build

```bash
bash _build_all.sh othello_blitz
```

Artefacts: `_PROD/othello_blitz.prg` (sideload) · `_STORE/othello_blitz.iq` (Connect IQ Store).

---

*Part of the Bitochi Garmin Games collection.*
