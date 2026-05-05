# Breath Training Tool (LITE)

**Deterministic timer-based freediving tool** dla zegarkow Garmin.

LITE to **czyste narzedzie** — bez coacha, bez adaptacji, bez rekomendacji, bez planow, bez interpretacji wynikow. Tylko 4 tryby, presety, licznik PB, statystyki jako czyste liczby, customizacja i factory reset.

Instant start w 1 kliknieciu. Kazda sesja to deterministyczny timer z formulami zapisanymi na sztywno.

---

## Stany ekranu (12)

| Stan | Staa | Opis |
|------|------|------|
| FT_HOME | 0 | Ekran glowny (QUICK START) |
| FT_BCFG | 1 | Konfiguracja Breathe |
| FT_TCFG | 2 | Konfiguracja CO2/O2 Table |
| FT_ACT | 3 | Aktywna sesja |
| FT_PAU | 4 | Pauza |
| FT_DONE | 5 | Podsumowanie sesji |
| FT_CUST | 6 | Personalizacja |
| FT_STAT | 7 | Statystyki |
| FT_NAME | 8 | Edytor imienia |
| FT_MORE | 9 | Pelne menu |
| FT_SAFE | 10 | Disclaimer bezpieczenstwa (pierwsze uruchomienie) |
| FT_RST | 11 | Potwierdzenie factory reset |

**Brak stanow:** `FT_PRO`, `FT_READY`, `FT_PLAN`, ani zadnych innych ekranow coachingu/systemu.

---

## Safety Layer — pierwsze uruchomienie

Przy pierwszym uruchomieniu pokazuje sie `FT_SAFE`:
- `SAFETY`
- `TRAINING TOOL ONLY`
- `Not for in-water use`
- `Never train alone`
- `SELECT = OK`

SELECT lub BACK akceptuja disclaimer (`usr_safe_ack = true`) i przechodza do HOME. Ekran nie pojawia sie ponownie (chyba ze factory reset).

To jedyna niedeterministyczna warstwa LITE — **wylacznie ostrzezenie prawne/bezpieczenstwa**, nie coaching.

---

## HOME — ekran startowy (QUICK START)

6 pozycji (modulo 6) — deterministyczne, **bez rekomendacji, bez state display, bez coacha**.

| hSel | Pozycja | SELECT |
|------|---------|--------|
| 0 | **LAST USED** (glowny START) | `_instantStart(_lastMode)` — ostatni tryb z zapisanymi parametrami |
| 1 | **BR** (quick preset) | `_quickBreathe()` — Recovery 2-4, 10 min, **bez nadpisywania** zapisanego presetu |
| 2 | **CO2** | `_instantStart(FM_CO)` z zapisanym presetem |
| 3 | **O2** | `_instantStart(FM_O2)` z zapisanym presetem |
| 4 | **AP** | `_instantStart(FM_AP)` |
| 5 | **More...** | → FT_MORE |

### Uklad wizualny HOME

| Y | Element | Font |
|---|---------|------|
| 6% | Imie nurka (kolor motywu) | XTINY |
| 16% | `QUICK START` (gdy hSel 0-4) | XTINY |
| 24% | Nazwa trybu | SMALL |
| 35% | Parametry (`Hold 1:06  8 rnd` itp.) | XTINY |
| 46% | Pulsujacy `START` | SMALL |
| 58% | Linia separatora | — |
| 64% | Rzad `BR  CO2  O2  AP` + kropka pod wybranym | XTINY |
| 78% | `More...` (highlight w kolorze motywu) | XTINY |

Dla `hSel == 1` (BR quick) preview pokazuje stale `Recovery 2-4  10m`, niezaleznie od zapisanego presetu `sv_br_*`.

### Tap na HOME

- `y < 58%` → doSelect
- `58-74%` → wybor BR/CO2/O2/AP wedlug kolumny X (4 sekcje) → start
- `y >= 74%` → More

### BACK na HOME

`return false` → popView (wyjscie z aplikacji).

---

## MORE — pelne menu (6 pozycji)

| mSel | Pozycja | Kolor |
|------|---------|-------|
| 0 | Breathe | bialy |
| 1 | CO2 Table | bialy |
| 2 | O2 Table | bialy |
| 3 | Stats | motyw |
| 4 | Customize | motyw |
| 5 | Reset | czerwony akcent |

BACK → HOME. Tap na pozycje → wybor + select.

**Brak pozycji PRO / Upgrade / Plan / Coach.**

---

## FT_RST — factory reset

Ekran potwierdzenia:
- `FACTORY RESET`
- `Erase all data?`
- `Stats, PB, name, theme will be cleared`
- `SELECT = YES` (pulsujacy czerwony)
- `BACK = cancel`

SELECT → `_resetAll()`:
1. `Application.Storage.clearValues()` — wyciera wszystko
2. Reset wszystkich zmiennych w pamieci do defaultow (presety, PB, log apnei, stats, imie "USER", motyw #0)
3. Double-vibe potwierdzenie
4. Przejscie do `FT_SAFE` (autentyczny factory start)

BACK → FT_MORE (mSel=5).

---

## FT_BCFG — konfiguracja Breathe

4 tryby:
- **Recovery 2-4** — inhale 2s / exhale 4s
- **Breathe-Up 3-6** — inhale 3s / exhale 6s
- **Box 4-4-4-4** — inhale 4s / hold 4s / exhale 4s / hold 4s
- **Custom** — INHALE (2-8s), HOLD (0-4s), EXHALE (3-10s), HOLD EX (0-4s)

Sesja: 5 / 10 / 15 / 20 / 30 min.

Presety maja 3 pola (MODE, SESSION, START). Custom ma 7 (MODE, INHALE, HOLD, EXHALE, HOLD EX, SESSION, START).

UP/DN zmienia wartosc, SELECT dalej, ostatnie pole startuje sesje.

---

## FT_TCFG — konfiguracja tabeli CO2/O2

3 pola:
- **MAX HOLD** — 1:00 / 1:30 / 2:00 / 2:30 / 3:00 / 3:30 / 4:00 / 5:00
- **ROUNDS** — 6 / 7 / 8 / 9 / 10
- **START**

Na dole preview wygenerowanej tabeli. **Brak profili trudnosci** (Easy/Standard/Hard — tylko w PRO).

---

## Tryby — logika (fixed formulas)

### Breathe

Cykl: INHALE → HOLD → EXHALE → HOLD EX → INHALE → ...
Fazy o czasie 0 pomijane. Timer 100ms = 10 Hz. Po uplywie `_brSS` sekund → FT_DONE.

### Static Apnea

Count-up od 0. Wibracje co 30s / 60s. Ostrzezenie przy 75% PB. Wynik zapisywany jesli >= 5s, PB aktualizowane automatycznie, log 3 ostatnich sesji (FIFO).

### CO2 Table — liniowa formula

- `HOLD = 55% * MAX HOLD` (staly, min 15s)
- `REST` od `2 * HOLD` (max 2:00) → liniowo do 0:30 w ostatniej rundzie

Cykl: PREP (3s, pierwsza runda) → BREATHE → HOLD → BREATHE → ... → COMPLETE.

### O2 Table — liniowa formula

- `REST = 2:00` stale
- `HOLD` rosnie liniowo od 50% do 85% MAX HOLD

**Zaden z algorytmow nie ma adaptacji, krzywych, ani profili trudnosci. Tylko jedna, deterministyczna formula per tryb.**

---

## FT_DONE — podsumowanie sesji (simple)

**Wylacznie 3 mozliwe komunikaty feedback'u** (bez interpretacji, bez wielolinii, bez rekomendacji):

| Warunek | Feedback |
|---------|----------|
| APNEA + nowy PB | `New PB` |
| BACK podczas CO2/O2 ACT/PAU | `Session ended` |
| Wszystko inne | `Session complete` |

### APNEA — wizualne
- Duzy timer w kolorze progu (zielony/zolty/czerwony)
- `NEW PB!` (migajacy zloty) gdy `_apNP == true`, lub `PB: M:SS (-Xs)` gdy ponizej PB

### BREATHE — wizualne
- Migajacy `DONE!`
- Czas sesji (`10 min`)
- Liczba oddechow

### CO2 / O2 — wizualne
- Migajacy `DONE!`
- Tag (`CO2 TABLE` / `O2 TABLE`)
- `N rounds`

**Brak:** "Near personal best", "Strong performance", "Rest advised", "Continue progression", "Rest before next dive", "Unlock structured training", milestones, przypominajek.

---

## FT_STAT — statystyki (pure counters)

- Imie nurka
- `TRAINING STATS`
- `Sessions: N` (lacznie)
- `Total: M min`
- `Breathe Nx  Mm`
- `Apnea Nx  PB M:SS`
- `CO2 Nx  O2 Nx`

Wylacznie licznki. **Brak trendow, streak'ow, progression indicators, hold totali.**

---

## FT_CUST / FT_NAME — personalizacja

### FT_CUST (3 pola)

- **THEME** — 5 motywow (UP/DN zmienia na zywo, 5 kropek = podglad palety)
- **NAME** — imie, SELECT otwiera FT_NAME
- **SAVE** — zapisuje i → HOME

### FT_NAME (8 pozycji)

Znaki: A-Z + 0-9 + spacja (`_`).
- Gora: cale imie z nawiasami wokol aktualnego znaku
- Srodek: wheel picker z aktualnym duzym + sasiednimi mniejszymi
- UP/DN zmienia znak, SELECT nastepna pozycja, BACK poprzednia

---

## Haptic feedback

| Zdarzenie | Intensywnosc | Czas | Wzor |
|-----------|-------------|------|------|
| Start Breathe/Table | 80% | 300ms | 1x |
| Start Apnea | 40% | 70ms | 1x |
| Fazowy INHALE | 70% | 150ms | 1x |
| Fazowy EXHALE | 70% | 120/80/120ms | 2x |
| Fazowy HOLD/HOLD EX | 90% | 200ms | 1x |
| Tbl BREATHE start | 60% | 140ms | 1x |
| Tbl HOLD start | 100% | 260ms | 1x |
| Tbl HOLD koniec | 80% | 120/80/120ms | 2x |
| Apnea co 30s | 50% | 110ms | 1x |
| Apnea co 60s | 80% | 280ms | 1x |
| Apnea 75% PB | 90% | 150/100/150ms | 2x |
| Stop apnea | 100% | 600ms | 1x |
| Koniec sesji | 100% | 600/150/200ms | 3x |
| Factory reset | 80% | 120/80/120ms | 2x |

---

## Storage — klucze (17)

### Safety
| Klucz | Opis |
|-------|------|
| `usr_safe_ack` | Boolean, disclaimer zaakceptowany |

### Presety
| Klucz | Opis | Domyslny |
|-------|------|----------|
| `lst_md` | Ostatni uzyty tryb (0=BR, 1=AP, 2=CO, 3=O2) | 2 (CO2) |
| `sv_co_mx` | Index MAX HOLD CO2 (0-7) | 2 |
| `sv_co_rn` | Index ROUNDS CO2 (0-4) | 2 |
| `sv_o2_mx` | Index MAX HOLD O2 | 2 |
| `sv_o2_rn` | Index ROUNDS O2 | 2 |
| `sv_br_m` | Tryb Breathe (0-3) | 0 |
| `sv_br_ii` | Index INHALE | 2 |
| `sv_br_hi` | Index HOLD | 0 |
| `sv_br_ei` | Index EXHALE | 2 |
| `sv_br_xi` | Index HOLD EX | 0 |
| `sv_br_si` | Index SESSION | 1 |

Quick BREATHE z HOME (`hSel == 1`) **NIE zapisuje** do `sv_br_*` — preset uzytkownika zostaje nienaruszony.

### Apnea PB
| Klucz | Opis |
|-------|------|
| `ap_pb` | Personal Best (sekundy) |
| `ap_lg0`, `ap_lg1`, `ap_lg2` | FIFO log ostatnich 3 apnei |

### Customize
| Klucz | Opis |
|-------|------|
| `usr_thm` | Index motywu (0-4) |
| `usr_nm` | Imie nurka (max 8 znakow) |

### Stats (pure counters)
| Klucz | Opis |
|-------|------|
| `st_brc` | Liczba sesji Breathe |
| `st_brt` | Laczny czas Breathe (s) |
| `st_apc` | Liczba sesji Apnea |
| `st_coc` | Liczba sesji CO2 |
| `st_o2c` | Liczba sesji O2 |
| `st_tot` | Laczny czas treningow (s) |

### **USUNIETE** z LITE (wczesniej istnialy)
- `ms_ap_1`, `ms_ap_2`, `ms_co_1`, `ms_o2_1`, `ms_5_sess` — milestones
- `rd_last` — readiness (tylko PRO)
- `st_suc_*`, `st_fail_*` — coach counters (tylko PRO)
- `pl_act`, `pl_day` — plan state (tylko PRO)

---

## Motywy kolorow

5 palet — Ocean / Sunset / Forest / Arctic / Neon. Zmiana w Customize → Theme.

Zasada projektowania: kazda paleta jest spojnie ciepla LUB zimna — **brak zoltych/zlotych tonow**, ktore wygladaja niespojnie na ciemnym ekranie zegarka.

| Motyw | INHALE | HOLD IN | EXHALE | HOLD EX | PREP/RST | TABLE HOLD |
|-------|--------|---------|--------|---------|----------|------------|
| Ocean | #00BBEE | #00DDAA | #8866EE | #3A88BB | #44AACC | #00CCAA |
| Sunset | #FF7744 | #FF9966 | #CC4466 | #BB4433 | #FF5533 | #FFBB66 |
| Forest | #33CC66 | #55CC66 | #55AA44 | #338844 | #44BB88 | #66CC44 |
| Arctic | #88DDFF | #AAEEFF | #6699FF | #88BBDD | #DDEEFF | #AADDFF |
| Neon | #FF00CC | #00FF88 | #CC00FF | #FF0088 | #FF66FF | #66FF66 |

Apnea uzywa `_cINH` (kolor INHALE motywu) dla stanu ponizej progu + zolty (75% PB) / czerwony (90% PB).

---

## Obsluga przyciskow

| Ekran | UP/DN | SELECT | BACK | TAP |
|-------|-------|--------|------|-----|
| HOME | Przewija 0-5 | Instant start / More | Wyjscie | Area (gora/srodek/dol) |
| MORE | Przewija 0-5 | Otwiera opcje | HOME | Tap na wiersz |
| BCFG | Zmienia pole | Next / Start | Prev / HOME | UP/DN |
| TCFG | Zmienia pole | Next / Start | Prev / HOME | UP/DN |
| ACT (BR/Tbl) | — | Pauza | HOME (mark early exit dla CO2/O2) | Pauza |
| ACT (AP) | — | Stop | HOME | Stop |
| PAU | — | Wznow | HOME | Wznow |
| DONE | — | HOME | HOME | HOME |
| STAT | — | HOME | HOME | — |
| CUST | Zmienia motyw | Next / Edytor / Save+HOME | Prev / HOME | UP/DN |
| NAME | Zmienia znak | Next pozycja | Prev / CUST | UP/DN |
| SAFE | — | Accept + HOME | Accept + HOME | — |
| RST | — | Reset → SAFE | MORE | — |

---

## Zero intelligence layer

LITE **nie zawiera**:
- coach logic, recommendations, `_recModeAndApply()`
- training state display (RECOVERY / BUILDING / STABLE / PEAK)
- fatigue / confidence heuristics
- adaptive difficulty / auto-progression
- readiness check (FT_READY, rd_last scoring)
- training plans / plan advancement
- milestones, achievements, unlocks
- soft engagement signals (`Unlock structured training`)
- interpretative feedback (`Near PB`, `Strong performance`, `Rest advised`, `Continue progression`)
- post-session safety reminders generowane dynamicznie
- streak / trend / hold total stats

**Wszystkie te funkcje znajduja sie wylacznie w siostrzanej aplikacji `breathtrainingsystem` (PRO).**

---

## Dane techniczne

- **Platforma:** Garmin Connect IQ, Monkey C
- **Typ:** watch-app
- **Nazwa w Store:** Breath Training
- **ID:** b4e2f8a1-6c3d-4907-d518-e1a047c63f92
- **Stany:** 12
- **Timer UI:** 100ms tick (10 Hz)
- **Storage:** 17 kluczy
- **Kompatybilnosc:** 80 zegarkow Garmin
- **Skalowanie:** 100% % wymiarow ekranu
- **Pliki zrodlowe:** FreedivingTrainingView.mc (~1270 linii), FreedivingTrainingDelegate.mc, FreedivingTrainingApp.mc
- **Build:** `_PROD/breathtrainingtool.prg` + `_STORE/breathtrainingtool.iq`

---

## Ostatnie zmiany (changelog)

### Upgrade to Pro

- Nowa pozycja **"Upgrade to Pro"** w menu More (slot 5, zoltym akcent), nad Reset.
- Dedykowany ekran `FT_PRO` z headerem `PRO`, sloganem "Train smarter. Dive deeper.", opisem produktu *Breath Training System* i 5-bullet listingiem feature'ow (coach, plany, rekomendacje, readiness, progression stats).
- CTA "Get it on Connect IQ Store" — pulsujacy zlocisty badge na dole.
- BACK / SELECT / TAP wraca do menu More (zero akcji handlujacej zakup w samej appce).

### UI / UX

- **Customize menu** — przebudowany do identycznego stylu co menu More: prosty list tekstu, wybrany wiersz swieci bialym, nieaktywny 0x555555; brak brzydkiej pionowej linii zaznaczenia. Zawiera: Theme (z 5 kropkami podgladu palety), Name, Vibration ON/OFF, SAVE.
- **Nawigacja Customize** — UP/DN przesuwa zaznaczenie (4 pola), SELECT lub TAP na wiersz wykonuje akcje (nie przesuwa). BACK wychodzi do HOME.
- **Vibration ON/OFF** — opcja w Customize, przelaczana przez SELECT na polu Vibration; zapisywana w Storage (klucz `usr_vib`).
- **SAVE** — neutralny bialy kolor (jak inne pozycje), nie zielony.
- **Przycisk Reset** — zawsze czerwony `#FF6644` w menu More.

### Animacje

- **Breathe — kolory**:
  - `_brPhColor()` zwraca `_lighten(_cEXH, -38)` dla faz HOLD-EXHALE i PREP; eliminuje cieplo-pomaranczowe/zolte tlo niezaleznie od motywu.
  - Palety motywow oczyszczone: Ocean `_cHE/PRP` → chlodne niebieskie, Sunset `_cHI` → peach-orange (nie zolty), Forest `_cHI/HE/PRP` → czyste zielone, Neon `_cEXH/HE` → elektryczny magenta/rozowy.
- **Breathe — sekundnik** — zastapiony cienkim phase-progress arc (setPenWidth 2) na stalym promieniu `rMax+22px` wokol pulsujacych halo; duza liczba `FONT_LARGE` z cieniem pod pika wyswietla pozostale sekundy fazy.
- **Breathe — naturalny odstep miedzy fazami** — `_brTrans = 1` (1 sekunda) po zakonczeniu kazdej fazy; pika zatrzymuje sie w pozycji koncowej, arc pelny, licznik wskazuje 0; nastepna faza startuje dopiero po odliczeniu.
- **Breathe — top info** — dwie kolumny: `#cycle` (lewa) + czas sesji (prawa) zamiast samego czasu posrodku.
- **Breathe — ambient glow** — ograniczony do `rMax + 36px` (nie full-screen); kolor fazy nie zabarwia juz calego tla.
- **Apnea** — podwodne tlo (12 poziomych paskow gradientu niebieskiego), grubszy ring (`setPenWidth 3`), obracajace sie pierscienie poswaty, timer `FONT_NUMBER_HOT` z cieniem.
- **CO2 / O2** — pill-box z numerem rundy (`fillRoundedRectangle`), podwojny ring (zewnetrzny dekoracyjny + wewnetrzny postepu `setPenWidth 4`), subtelny ambient glow w kolorze fazy, etykieta i countdown z cieniami.
