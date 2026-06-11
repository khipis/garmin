# Leaderboard Integration Analysis

---

## ✅ Implementation status (skeleton)

A **shared Monkey C library** now lives in `_shared/leaderboard/`:

| File | What it provides |
|------|------------------|
| `Leaderboard.mc` | `module Leaderboard` — `submitScore(game,score,variant)`, `loadUser/saveUser/hasUser`, config (`API_BASE`), `buildName()` |
| `LbViews.mc` | `LbNameEntryView`/`Delegate` (wheel keyboard for username), `LbScoresView`/`Delegate` (fetches + renders top-10), `LbFetch` (GET helper), `LbBadge` (gold menu-row drawer) |

### 🟢 LIVE
- **Backend deployed:** Cloudflare Worker `garmin` at `https://garmin.krzysztofkorolczuk2.workers.dev`, D1 `bitochi-leaderboard` schema applied.
- **`Leaderboard.API_BASE`** points at the live worker.
- **ASC sorting:** the worker keeps a per-game `ASC_GAMES` set so time/move/stroke
  games (`sudoku`, `minesweeper`, `solitaire`, `lightsout`, `minigolf`, `battleship`)
  rank **lower = better**. Clients just render the pre-ranked `top` list — no
  client-side sort logic and no score negation.

**Username:** stored per-app in `Application.Storage["lb_user"]`. Entered once via the
wheel keyboard (`LbScoresView` auto-prompts on first open), then remembered. The
scores panel scrolls (UP/DOWN), shows a fixed `bitochi.com` footer, and supports
**hold-to-rename**.
> ⚠️ Garmin has no cross-app shared storage, so each game keeps its own copy.

### Rollout recipe (applied to every game below)
1. `monkey.jungle` → append `;../_shared/leaderboard` to `base.sourcePath`
2. `manifest.xml` → add `<iq:uses-permission id="Communications"/>`
3. Menu → add a gold `LbBadge.drawRow` `LEADERBOARD` row; ~18% smaller, space-aware
   geometry so rows never overlap on round watches; `openLeaderboard()` pushes
   `LbScoresView(GAME_ID, VARIANT, TITLE)` + `new LbScoresDelegate(v)` on activate
4. Game over / completion → `Leaderboard.submitScore(GAME_ID, score, VARIANT)`

### ✅ Integrated games (all build clean, PROD `-l 2` + STORE)

| Game | game_id | Metric | Variant | Sort |
|------|---------|--------|---------|------|
| stacktower | `stacktower` | floors | difficulty | DESC |
| twentyfortyeight | `twentyfortyeight` | score | — | DESC |
| flappypidgeon | `flappypidgeon` | pillars | — | DESC |
| jumptower | `jumptower` | height | — | DESC |
| gemmatch | `gemmatch` | timed score | — | DESC |
| dinosaur | `dinosaur` | survival score | — | DESC |
| shadowclonerunner | `shadowclonerunner` | distance | — | DESC |
| edgesurvivor | `edgesurvivor` | survival score | — | DESC |
| serpent | `serpent` | combo score | — | DESC |
| run (Monster Escape) | `run` | progress | — | DESC |
| blobs | `blobs` | eliminations | — | DESC |
| manpac | `manpac` | points | — | DESC |
| pixelinvaders | `pixelinvaders` | points | difficulty | DESC |
| catapult | `catapult` | 16-round points | — | DESC |
| pinballpro | `pinballpro` | points | table | DESC |
| skijump | `skijump` | jump points | jumper | DESC |
| pongpro | `pongpro` | match score | AI difficulty | DESC |
| diceroyale | `diceroyale` | scorecard | mode | DESC |
| sudoku | `sudoku` | solve time (s) | mode-difficulty | **ASC** |
| minesweeper | `minesweeper` | solve time (s) | board size | **ASC** |
| parachute | `parachute` | landing points | — | DESC |
| blackjack | `blackjack` | peak bankroll | — | DESC |
| poker | `poker` | peak stack | — | DESC |
| checkers | `checkers` | win streak | difficulty | DESC |
| chess | `chess` | win streak | difficulty | DESC |
| othello_blitz | `othello` | disc count (win) | — | DESC |
| tic_tac_pro | `tictacpro` | win streak | difficulty | DESC |
| connect_four_lite | `connectfour` | win streak | difficulty | DESC |
| battleship | `battleship` | shots to win | AI difficulty | **ASC** |
| solitare | `solitaire` | solve time (s) | — | **ASC** |
| lightsout | `lightsout` | move count | board size | **ASC** |
| hangman | `hangman` | win streak | category-difficulty | DESC |
| minigolf | `minigolf` | total strokes | course | **ASC** |
| fish | `fish` | session catch value | — | DESC |
| bricks | `bricks` | points | — | DESC |
| moon | `moon` | composite landing | — | DESC |
| jazzball | `jazzball` | accumulated % | — | DESC |

> Win-streak games persist their streak in `Application.Storage` (`<game>_streak`),
> incrementing on a player win vs AI and resetting to 0 on loss/draw.

---

# Game-by-game analysis

> Analiza wszystkich gier pod kątem globalnego leaderboard — czy się nadają,
> jaka metryka, czy potrzebne warianty (`variant` field), co należy dodać.

---

## Legenda

| Symbol | Znaczenie |
|--------|-----------|
| ✅ | Gotowe / dobre do wdrożenia bez zmian |
| 🔧 | Wymaga małych zmian w kodzie gry |
| 🏗️ | Wymaga średnich zmian (nowy tryb/metryka) |
| ❌ | Nie nadaje się do leaderboard |
| `variant` | Pole wariantu które gra powinna wysyłać razem ze score |

---

## Tier 1 — Idealne (score already exists, high replayability)

### 🎮 Flappy Pidgeon ✅
- **Metryka:** liczba filarów (score = pillar count)
- **Wariant:** brak — jeden bezstanowy tryb
- **Co wysłać:** `{ game:"flappypidgeon", score:N }`
- **Co dodać w grze:** wywołanie POST /score po game over

---

### 🎮 Stack Tower ✅
- **Metryka:** liczba pięter ułożonych (score = floors)
- **Wariant:** brak
- **Co wysłać:** `{ game:"stacktower", score:N }`
- **Co dodać:** POST /score po game over

---

### 🎮 Jump Tower ✅
- **Metryka:** maksymalna osiągnięta wysokość
- **Wariant:** brak (ale można `variant:"easy"/"normal"/"hard"` z `difficulty`)
- **Co wysłać:** `{ game:"jumptower", score:N }` lub z wariantem trudności
- **Co dodać:** POST /score po game over; ewentualnie uwzględnić `difficulty`

---

### 🎮 Gem Match ✅
- **Metryka:** punkty za 90 sekund (`score`)
- **Wariant:** brak (jeden tryb czasowy)
- **Co wysłać:** `{ game:"gemmatch", score:N }`
- **Co dodać:** POST /score po upływie czasu

---

### 🎮 2048 (twentyfortyeight) ✅
- **Metryka:** najwyższy wynik przed zablokowaniem planszy
- **Wariant:** brak
- **Co wysłać:** `{ game:"twentyfortyeight", score:N }`
- **Co dodać:** POST /score przy game over / win

---

### 🎮 Dinosaur ✅
- **Metryka:** score (zwiększa się ~30/s, zależy od przeżycia)
- **Wariant:** brak
- **Co wysłać:** `{ game:"dinosaur", score:N }`
- **Co dodać:** POST /score przy death

---

### 🎮 Shadow Clone Runner ✅
- **Metryka:** score (dystans / przeżycie)
- **Wariant:** brak
- **Co wysłać:** `{ game:"shadowclonerunner", score:N }`
- **Co dodać:** POST /score przy death

---

### 🎮 Edge Survivor ✅
- **Metryka:** czas przeżycia / score (fazy trudności)
- **Wariant:** brak
- **Co wysłać:** `{ game:"edgesurvivor", score:N }`
- **Co dodać:** POST /score przy death

---

### 🎮 Manpac ✅
- **Metryka:** punkty (pellets + duchy)
- **Wariant:** `level` startowy (1–N) — gracze mogą zaczynać od wyższego poziomu
- **Co wysłać:** `{ game:"manpac", score:N, variant:"level-1" }` (wariant opcjonalny)
- **Co dodać:** POST /score po game over

---

### 🎮 Serpent ✅
- **Metryka:** długość węża / combo punkty (`_combo * _level`)
- **Wariant:** brak
- **Co wysłać:** `{ game:"serpent", score:N }`
- **Co dodać:** POST /score po śmierci

---

### 🎮 Pixel Invaders ✅
- **Metryka:** punkty za zestrzelone wrogie statki
- **Wariant:** `"easy"` / `"normal"` / `"hard"` (PI_DIFF_EASY/NORMAL/HARD już w kodzie)
- **Co wysłać:** `{ game:"pixelinvaders", score:N, variant:"normal" }`
- **Co dodać:** POST /score; przekazać `difficulty` jako `variant`

---

### 🎮 Catapult ✅
- **Metryka:** suma punktów za 16 rund (zniszczone bloki + obrażenia wroga)
- **Wariant:** brak (rundy są sekwencyjne, nie do wyboru)
- **Co wysłać:** `{ game:"catapult", score:N }`
- **Co dodać:** POST /score po rundzie 16

---

### 🎮 Blobs ✅
- **Metryka:** liczba wyeliminowanych wrogich blobów / fale przeżyte
- **Wariant:** tryb 1P vs tryb 2P (jeśli istnieje) — `variant:"solo"`
- **Co wysłać:** `{ game:"blobs", score:N }`
- **Co dodać:** POST /score po game over

---

### 🎮 Monster Escape (run) ✅
- **Metryka:** score (progress bar + timer)
- **Wariant:** brak
- **Co wysłać:** `{ game:"run", score:N }`
- **Co dodać:** POST /score po śmierci

---

## Tier 2 — Dobre z wariantami

### 🎮 Ski Jump 🔧
- **Metryka:** łączny wynik skoku (dystans + styl + lądowanie)
- **Wariant:** **JUMPER** — gra ma 6 zawodników (Stoch / Kraft / Lindvik / Kobayashi / Prevc / Granerud), każdy może być osobną kategorią leaderboard
  - Alternatywnie: jeden globalny ranking bez rozróżnienia zawodnika
- **Co wysłać:** `{ game:"skijump", score:N, variant:"Stoch" }` lub bez wariantu
- **Co dodać:** POST /score po lądowaniu; dołączyć `_jumperNames[_jumperIdx]` jako variant

---

### 🎮 Pinball Pro 🔧
- **Metryka:** punkty (co 10 000 → dodatkowe życie, wysoki score = długa gra)
- **Wariant:** **STÓŁ** — 5 stołów: `CLASSIC` / `NOVA` / `DERBY` / `STINGER` / `ECLIPSE`
- **Co wysłać:** `{ game:"pinballpro", score:N, variant:"CLASSIC" }`
- **Co dodać:** POST /score przy game over; przekazać `TableLibrary.NAMES[tableIdx]`

---

### 🎮 Sudoku 🔧
- **Metryka:** czas rozwiązania (mniejszy = lepszy) — najlepiej `score = MAX_MS - elapsed_ms` albo przechowywać oddzielnie jako "best time"
- **Wariant:** tryb × trudność: `"4x4-easy"` / `"9x9-easy"` / `"9x9-medium"` / `"9x9-hard"`
- **Co wysłać:** `{ game:"sudoku", score:elapsed_seconds, variant:"9x9-hard" }`
  - ⚠️ Uwaga: dla czasów leaderboard powinien **sortować ASC** (mniejszy czas = lepszy) — albo wysyłamy `score = -elapsed` albo osobna logika sortowania
- **Co dodać:** POST /score po solve; variant z trybu+trudności

---

### 🎮 Minesweeper 🔧
- **Metryka:** czas rozwiązania (best time, 6 rozmiarów planszy)
- **Wariant:** rozmiar planszy: `"8x8"` / `"10x10"` / `"12x12"` / `"16x16"` / `"24x24"` / `"32x32"` (SIZES = [8,10,12,16,24,32])
- **Co wysłać:** `{ game:"minesweeper", score:elapsed_ms, variant:"16x16" }`
  - ⚠️ Ten sam problem sortowania — czas mniejszy = lepszy
- **Co dodać:** POST /score po wyczyszczeniu planszy; variant = `SIZES[difficulty]+"x"+SIZES[difficulty]`

---

### 🎮 Pong Pro 🔧
- **Metryka:** wynik gracza w wygranym meczu (np. max pkt osiągnięte) — lub "serie meczów"
- **Wariant:** trudność AI: `"easy"` / `"medium"` / `"hard"`
- **Co wysłać:** `{ game:"pongpro", score:player_score, variant:"hard" }`
- **Co dodać:** POST /score po końcu meczu (gdy jeden z graczy osiągnie limit)

---

### 🎮 Dice Royale 🔧
- **Metryka:** wynik końcowy karty punktacyjnej
- **Wariant:** tryb: `"classic"` / `"quick"` (DR_MODE_CLASSIC / DR_MODE_QUICK)
- **Co wysłać:** `{ game:"diceroyale", score:N, variant:"classic" }`
- **Co dodać:** POST /score po wypełnieniu karty

---

### 🎮 Parachute 🔧
- **Metryka:** dokładność lądowania + punkty za pierścienie
- **Wariant:** poziom (rośnie z każdą grą) — `variant:"level-5"` jeśli chcemy porównywalność
- **Co wysłać:** `{ game:"parachute", score:N }` (bez wariantu, globalny ranking)
- **Co dodać:** POST /score po lądowaniu

---

### 🎮 Blackjack 🔧
- **Metryka:** stan kasy (stack) po N rundach lub % wygranych rozdań
- **Wariant:** brak lub `"standard"`
- **Co dodać:** Zdefiniować jasną metrykę (np. stan po 20 rundach startując od 100 żetonów)

---

### 🎮 Poker 🔧
- **Metryka:** wartość stosu po N rękach
- **Wariant:** brak lub tryb
- **Co dodać:** Jak wyżej — potrzebna jasna "session end" metryka

---

## Tier 3 — Możliwe, ale wymagają przemyślenia metryki

### 🎮 Checkers 🏗️
- **Problem:** wynik wygrania/przegranej nie jest numerycznie sensowny
- **Metryka:** liczba wygranych partii z rzędu (seria), albo suma wziętych pionków
- **Wariant:** trudność: `"easy"` / `"medium"` / `"hard"` (3 poziomy w kodzie)
- **Co dodać:** licznik wygranych z rzędu (win streak) jako score; POST po każdej wygranej

---

### 🎮 Chess 🏗️
- **Problem:** wynik szachowy jest binarny (wygrana/przegrana)
- **Metryka:** liczba wygranych partii łącznie, albo ilość ruchów do matu (mniejsza = lepsza)
- **Wariant:** trudność: `"easy"` / `"medium"` / `"hard"`
- **Co dodać:** tracker wygranych per difficulty; ewentualnie ELO-like score

---

### 🎮 Othello Blitz 🏗️
- **Metryka:** liczba krążków na planszy po wygranej (większa = lepsza dominacja)
- **Wariant:** brak
- **Co wysłać:** `{ game:"othello_blitz", score:disc_count }`
- **Co dodać:** POST /score po zakończeniu partii

---

### 🎮 Tic-Tac Pro 🏗️
- **Metryka:** liczba wygranych partii z rzędu (win streak) per sesję
- **Wariant:** rozmiar planszy jeśli ma różne tryby
- **Co dodać:** win streak counter

---

### 🎮 Connect Four 🏗️
- **Metryka:** win streak (seria wygranych pod rząd)
- **Wariant:** brak
- **Co dodać:** counter per session

---

### 🎮 Battleship 🏗️
- **Metryka:** liczba ruchów do zatopienia całej floty wroga (mniejsza = lepsza) lub liczba trafień bez chybień z rzędu
- **Wariant:** trudność AI (3 poziomy)
- **Co dodać:** move counter; POST /score po wygranej

---

### 🎮 Solitaire (Klondike) 🏗️
- **Metryka:** czas ukończenia (mniejszy = lepszy)
- **Wariant:** brak
- **Co dodać:** POST /score po wygranej z czasem; pamiętać o sortowaniu ASC

---

### 🎮 Lights Out 🏗️
- **Metryka:** minimalna liczba kliknięć do rozwiązania (mniejsza = lepsza)
- **Wariant:** rozmiar planszy / trudność
- **Co dodać:** move counter; sortowanie ASC

---

### 🎮 Hangman 🏗️
- **Metryka:** seria odgadniętych słów bez błędu (win streak), lub liczba wygranych ogółem
- **Wariant:** kategoria + trudność: `"animals-hard"`, `"tech-easy"` itp.
- **Co dodać:** win streak counter; variant z category+difficulty

---

### 🎮 Manpac (dodatkowy wariant ghost difficulty) 🔧
- Jak opisano w Tier 1, ale warto też dodać `variant` z poziomem trudności ghostów

---

### 🎮 Minigolf 🏗️
- **Metryka:** łączna liczba uderzeń na 9/18 dołków (mniejsza = lepsza)
- **Wariant:** liczba dołków / kurs
- **Co dodać:** cumulative stroke counter; POST /score po ukończeniu kursu

---

### 🎮 Fish 🏗️
- **Metryka:** całkowita wartość/waga złowionych ryb per sesja
- **Wariant:** brak
- **Co dodać:** session score; POST /score po zakończeniu sesji

---

### 🎮 Parachute 🔧
- Jak w Tier 2

---

### 🎮 Bricks 🏗️
- **Metryka:** punkty za zbite cegły / poziom osiągnięty
- **Wariant:** brak lub poziom startowy
- **Co dodać:** score tracking; POST /score po stracie ostatniej piłki

---

### 🎮 Moon (Lander) 🏗️
- **Metryka:** dokładność lądowania + zużyte paliwo (composite score)
- **Wariant:** brak lub trudność
- **Co dodać:** scoring formula; POST /score po lądowaniu

---

### 🎮 Jazzball 🏗️
- **Metryka:** % odizolowanego pola po każdym poziomie (70% = zaliczony)
- **Wariant:** brak
- **Co dodać:** accumulated score po N poziomach

---

## Tier 4 — Narzędzia / Utility — ❌ nie nadają się

| Gra | Powód |
|-----|-------|
| **Breath Training System** | Narzędzie treningowe, brak rywalizacyjnej metryki |
| **Breath Training Tool** | j.w. |
| **Interval Beeper** | Timer — brak score |
| **Dive Boat Mode Planner** | Kalkulator nurkowy |
| **Dive Gas Blender** | Kalkulator nurkowy |
| **Dive Plan Toolkit** | Kalkulator nurkowy |
| **Dive Quick Calculator** | Kalkulator nurkowy |
| **Diver Communicator** | Narzędzie komunikacji |
| **Dive Risk Indicator** | Monitor ryzyka |
| **Dive Safety Toolkit** | Kalkulator bezpieczeństwa |
| **Fake Notification Escape** | Trick/joke app, brak rywalizacji |
| **Recovery Timer** | Timer regeneracji |
| **Timer (sparring timer)** | Timer bokserski |

---

## Tier 5 — Gry turowe / strategiczne — marginalny potencjał

Dla tych gier leaderboard ma sens tylko jeśli aplikacja zlicza coś przez dłuższy czas:

| Gra | Potencjalna metryka | Trudność |
|-----|---------------------|----------|
| **Gobblet Mini** | Win streak | 🏗️ |
| **Hex Mini** | Win streak | 🏗️ |
| **Morris Classic** | Win streak | 🏗️ |
| **Mini Go 9x9** | Score końcowy partii (pole territory) | 🏗️ |
| **Dots & Boxes** | Score (skrzynek) w wygranej sesji | 🔧 |
| **Territory Clash** | Score zajętego pola | 🔧 |
| **Kakuro** | Czas ukończenia puzzla | 🏗️ |
| **Nonogram** | Czas ukończenia | 🏗️ |
| **Makao** | Win streak / rundy wygranych | 🏗️ |
| **Checkers** | Jak Tier 3 | 🏗️ |
| **Billiards** | Win streak vs AI, `variant` = odmiana gry (9-ball / 8-ball / 3-ball / snooker) — tryb P vs P nie wysyła wyniku | ✅ wdrożone |

---

## Podsumowanie priorytetów wdrożenia

### Faza 1 — Natychmiastowy zysk (Tier 1, bez wariantów)
Wystarczy dodać jedno wywołanie `POST /score` w momencie game over:

1. **Flappy Pidgeon** — score = pillar count
2. **Stack Tower** — score = floors stacked
3. **Jump Tower** — score = peak height
4. **Gem Match** — score = points in 90s
5. **2048** — score = board score
6. **Dinosaur** — score = survival score
7. **Shadow Clone Runner** — score = distance/score
8. **Edge Survivor** — score = survival score
9. **Serpent** — score = snake score
10. **Monster Escape** — score = survival score

### Faza 2 — Warianty (Tier 2, wymaga `variant`)
11. **Pixel Invaders** — variant = difficulty (easy/normal/hard)
12. **Pinball Pro** — variant = table name (CLASSIC/NOVA/DERBY/STINGER/ECLIPSE)
13. **Ski Jump** — variant = jumper name (Stoch/Kraft/Lindvik/…)
14. **Pong Pro** — variant = AI difficulty (easy/medium/hard)
15. **Dice Royale** — variant = mode (classic/quick)
16. **Manpac** — score = points, variant = start level
17. **Catapult** — score = total points over 16 rounds
18. **Blobs** — score = enemies defeated

### Faza 3 — Czas odwrócony (metryka time-based, sortowanie ASC)
> Backend wymaga nowego endpointu lub flagi `asc=true` w GET /leaderboard
19. **Sudoku** — elapsed time per difficulty+mode
20. **Minesweeper** — elapsed time per board size
21. **Solitaire** — elapsed time
22. **Lights Out** — move count

### Faza 4 — Potrzebne nowe liczniki w grze
23. **Battleship**, **Chess**, **Checkers** — win streaks
24. **Othello Blitz**, **Connect Four**, **Tic-Tac Pro** — win streaks
25. **Parachute**, **Fish**, **Moon** — dedykowane score formulas

---

## Zmiany backendowe potrzebne

1. **Faza 3: sortowanie ASC** — dodać `?asc=true` do `GET /leaderboard`, zmienić `ORDER BY score DESC` na `ORDER BY score ASC` warunkowo
2. **Faza 3: deduplikacja per user** — opcjonalnie pokazywać tylko najlepszy wynik per user (DISTINCT ON user)

---

## Snippet do dodania w grach Monkey C (Faza 1 & 2)

```monkeyc
// Po game over:
function _submitScore(score as Number, variant as String) as Void {
    var url = "https://garmin-leaderboard.YOURSUBDOMAIN.workers.dev/score";
    var body = {
        "game"    => GAME_ID,      // np. "flappypidgeon"
        "score"   => score,
        "variant" => variant,      // "" jeśli brak
        "user"    => (_playerName != null) ? _playerName : "anon",
    };
    Communications.makeWebRequest(
        url,
        body,
        { :method => Communications.HTTP_REQUEST_METHOD_POST,
          :headers => { "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON } },
        method(:_onScoreResponse)
    );
}

function _onScoreResponse(code, data) as Void {
    // silent — nie blokuj gracza na wynik submit
}
```

> Wymaga `Communications` permission w `manifest.xml`:
> `<iq:permission id="Communications"/>`
