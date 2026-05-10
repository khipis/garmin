# Makao Lite

A polish card game for Garmin watches — match cards by rank or suit, and use
special cards to outmanoeuvre the AI opponent.

## Rules

Makao is the Polish equivalent of Crazy Eights / UNO.

### Objective

Be the first player to empty your hand.

### Playing a card

A card may be played if it matches the **top card of the discard pile** by:

- **Rank** — e.g. any 7 on a 7, any Queen on a Queen, or
- **Suit** — e.g. any Club on a Club.

### Special cards

| Card | Effect |
|------|--------|
| **2** | Next player must draw 2 cards (or counter with another 2/3 to chain) |
| **3** | Next player must draw 3 cards (stackable with 2/3) |
| **J** (Jack) | Opponent's next turn is skipped |
| **A** (Ace) | Player who played it chooses the active suit |

**Draw-chain stacking:** if a 2 is on top (pending draw = 2) and you play
another 2, the opponent must draw 4; add a 3 for 7, etc.  
You can only counter a draw chain with another 2 or 3 — any other card is
invalid while a pending draw is active.

### Drawing from deck

Select the **DRAW** button (rightmost slot in the hand strip) to draw.  
When a pending draw is active, the DRAW button shows `+N` and pressing it
draws all N cards at once, ending your turn.

### Turn end

Your turn ends when you:
- Play a valid card (Ace additionally opens the suit picker), or
- Press DRAW.

Drawing a card always ends the turn; the drawn card cannot be played
immediately.

---

## Controls

| Input | Action |
|-------|--------|
| **← (Previous Page / Left)** | Move hand cursor left |
| **→ (Next Page / Right)** | Move hand cursor right / suit picker right |
| **↑↓ (Up / Down)** | Also moves suit picker left/right |
| **SELECT / Tap** | Play highlighted card · confirm suit · draw · new game |
| **BACK** | Exit app |

### Suit picker

Appears automatically when you play an Ace.  
Use ← / → to cycle through H · D · C · S, then SELECT to confirm.

---

## Display

```
┌──────────────────────────────┐
│ W:2               2:W        │  ← session wins (you:ai)
│        AI: 7 cards           │  ← AI info
│                              │
│  ┌──┐  TURN   ┌──────┐      │
│  │░░│  label  │ 9 H  │      │  ← deck back + top card
│  │░░│         │      │      │
│  └──┘    42   │  H   │      │  ← deck remaining count
│                └──────┘      │
│              Hand: 5         │
│ ┌──┐┌──┐┌──┐┌──┐  ┌──────┐ │  ← hand strip (scrollable)
│ │AH││KD││2S││JC│  │ DRAW │ │  ← last slot = DRAW button
│ └──┘└──┘└──┘└──┘  └──────┘ │
└──────────────────────────────┘
```

- **Green border** = card is valid to play
- **Yellow background** = cursor / selected card
- **Dimmed background** = card cannot be played now
- `+N` on DRAW button = forced draw accumulated

---

## AI strategy

1. **Forced draw present** — counter with 2 or 3 if available; otherwise draw all.
2. **Normal play priority** — Jack > 2 > 3 > Ace > regular card.
3. **Ace suit selection** — picks the suit of which it holds the most cards.
4. **Draw + play** — after drawing 1 card, plays it immediately if valid.

---

## Technical notes

- **52-card deck** (4 suits × 13 ranks). Deal: 5 cards each + 1 top card.
- **Zero game-loop allocation** — all arrays (`_deck[52]`, `_pHand[52]`,
  `_aiHand[52]`, `_tmpSuits[4]`) are pre-allocated in `initialize()`.
- **Fisher-Yates shuffle** — in-place, O(n).
- **Timer-driven AI** — 650 ms delay per AI action for readable pacing.
  Jack skips are also resolved by the timer, showing a brief "SKIPPED!" banner.
- **Adaptive layout** — card and play-area sizes computed from `dc.getWidth()`
  / `dc.getHeight()`, compatible with all screen sizes from 260 px to 416 px.
- **Deck exhaustion** — if the deck runs out, drawing silently yields 0 cards
  and the turn passes; the game continues from hands.

---

## Project structure

```
makao_lite/
├── source/
│   ├── MakaoLiteApp.mc   — entry point
│   ├── GameDelegate.mc   — input routing
│   └── GameView.mc       — game logic + rendering (~400 lines)
├── resources/
│   ├── drawables.xml
│   ├── strings.xml
│   └── launcher_icon.png
├── manifest.xml
├── monkey.jungle
└── README.md

_LOGOS/
├── gen_makao_icon.py     — generates launcher_icon.png (70×70)
└── gen_makao_hero.py     — generates makao_hero.png (1440×720)

_STORE/                   — (place signed .iq here for Connect IQ Store)
_PROD/                    — (compiled .prg output)
```
