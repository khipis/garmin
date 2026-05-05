# Breath Training System (PRO)

**Breath Coaching System** dla zegarkow Garmin — LITE-like launcher z nadbudowana warstwa inteligencji (rekomendacja, readiness, adaptacja). HOME zachowuje szybkosc i layout wersji LITE, a coach dziala w tle i podpowiada pasywnie.

Uzywa tych samych piec slotow quick-start co LITE (*Last Used* / BR / CO2 / O2 / AP), dodaje **przezroczysty overlay rekomendacji** ("REC CO2 HARD", "REST ADVISED", "PLAN D3/10") oraz dedykowana pozycje **Readiness check**. Coach nie blokuje zadnej sciezki startu — nadpisane sa jedynie presety (adaptive difficulty, `sv_co_df`, `sv_o2_df`) i feedback (performance + recommendation, 1+1).

W odroznieniu od **Breath Training Tool** (wersja LITE), System zachowuje *muscle memory* LITE: SELECT na HOME zawsze startuje sesje natychmiast, swipe/tap wybiera tryb, nic sie nie otwiera w dodatkowych menu. Roznica: dochodzi rekomendacja, readiness, plan i adaptacja.

---

## Co rozni System od Tool

| Funkcja | Tool (LITE) | System (PRO) |
|---------|:-----------:|:------------:|
| Breathe, Apnea, CO2, O2 | OK | OK |
| Customize (motyw + imie) | OK | OK |
| Basic Stats | OK | OK |
| Factory Reset | OK | OK |
| Profile trudnosci (Easy/Std/Hard) | — | OK |
| Krzywa nieliniowa w CO2/O2 | — | OK |
| **Plany treningowe (8 programow x 10 sesji)** | — | OK |
| **5 presetow oddechowych (incl. Wim Hof, Pranayama 4-7-8)** | — | OK |
| **Recommended session (coach logic)** | — | OK |
| **Training state (RECOVERY/BUILDING/STABLE/PEAK)** | — | OK |
| **Fatigue + confidence heuristics** | — | OK |
| **Adaptive difficulty (auto-progression)** | — | OK |
| **Adaptive plan (Repeat / Skip)** | — | OK |
| **Readiness Check (30s breathe + hold)** | — | OK |
| **2-line standardized feedback** | — | OK |
| **Progression stats (trend, streak, hold total)** | — | OK |
| **Histogram apnea (5 sesji, color-coded last bar)** | — | OK |
| **Debug: Gen Test User z ekranem potwierdzenia (FT_GTU)** | — | OK (DBG_ENABLED) |
| **CO2 tolerance model (PRO++)** | — | OK |
| **O2 adaptation model (PRO++)** | — | OK |
| **Recovery model (PRO++)** | — | OK |
| **Session quality score 0..100 (PRO++)** | — | OK |
| **PB prediction + confidence (PRO++)** | — | OK |
| **Pattern detection (plateau/decline/overtrain)** | — | OK |
| **Diver profile (CO2/O2/RECOVERY dominant)** | — | OK |
| **Stats Page 3: PHYSIOLOGY z mini-trendami CO2/O2/REC (PRO++)** | — | OK |
| **Stats Page 4: WEEKLY z 8-tyg. wykresem + 14-day activity strip (PRO++ v4)** | — | OK |
| **Stats Page 5: SENSOR TRENDS (bradycardia / calm index / readiness) (PRO++ v5.2)** | — | OK |
| **Stats Page 2: PROGRESSION z 4 mini-trendami (APNEA/CO2/O2/BR)** | — | OK |
| **7-day consistency (`X/7d active`)** | — | OK |
| **Plan ETA (`~X days left`)** | — | OK |
| **Theme-aware kolorystyka (Readiness/REC overlay/PLAN)** | — | OK |
| **Apnea micro-feedback (50%/75% PB)** | — | OK |
| **Context-aware FT_DONE feedback** | — | OK |
| **Sensor Hub: live HR / Body Battery / Stress / SpO2 / Resting HR (PRO++ v5)** | — | OK |
| **Bradycardia detection (mammalian dive reflex) podczas apnea** | — | OK |
| **HR-based "CALM" cue podczas breathe-up** | — | OK |
| **Sensor toggle (Customize → Sensors ON/OFF)** | — | OK |
| **Guide / Legenda (More → Guide, 65 wpisow, scrollowalny) (PRO++ v5.3)** | — | OK |

---

## Stany ekranu (14)

| Stan | Staa | Opis |
|------|------|------|
| FT_HOME | 0 | Ekran glowny |
| FT_BCFG | 1 | Konfiguracja Breathe |
| FT_TCFG | 2 | Konfiguracja CO2/O2 (4 pola) |
| FT_ACT | 3 | Aktywna sesja |
| FT_PAU | 4 | Pauza |
| FT_DONE | 5 | Podsumowanie (feedback 2-line) |
| FT_CUST | 6 | Personalizacja |
| FT_STAT | 7 | Statystyki (5 stron: TRAINING / PROGRESSION / **PHYSIOLOGY** / **WEEKLY** / **SENSOR TRENDS**) |
| FT_NAME | 8 | Edytor imienia |
| FT_MORE | 9 | Pelne menu |
| FT_PLAN | 10 | Training Plan (wybor / progres) |
| FT_READY | 11 | Readiness Check |
| FT_RST | 12 | Factory reset |
| FT_HELP | 13 | Guide / Legenda (scrollowalna, 65 wpisow) |
| FT_GTU  | 14 | Gen Test User — ekran potwierdzenia (ostrzezenie o nadpisaniu danych) |

---

## HOME — LITE-like launcher + intelligence overlay (7 pozycji)

Struktura i nawigacja IDENTYCZNA jak w LITE. Identyczne skroty quick-start, identyczne muscle memory. Dodane: overlay rekomendacji u gory oraz wpis Readiness check nad More.

| hSel | Pozycja | SELECT | Typ |
|------|---------|--------|-----|
| 0 | **LAST USED** (tytul + info preview) | `_instantStart(_lastMode)` | deterministyczny instant start |
| 1 | **BR** (quick preset) | `_quickBreathe()` — Recovery 2-4, 10 min, nie nadpisuje presetow | deterministyczny instant start |
| 2 | **CO2** | `_instantStart(FM_CO)` — saved preset (`_svCoMx/_svCoRn/_svCoDf`) | deterministyczny instant start |
| 3 | **O2** | `_instantStart(FM_O2)` — saved preset (`_svO2Mx/_svO2Rn/_svO2Df`) | deterministyczny instant start |
| 4 | **AP** | `_instantStart(FM_AP)` | deterministyczny instant start |
| 5 | **Readiness check** | `_rdStart()` → FT_READY (30s breathe + hold + score → HOME) | opt-in coach gate |
| 6 | **More...** | → FT_MORE | menu |

### Overlay rekomendacji (non-intrusive)

Maly, pasywny napis pod imieniem nurka — zawsze widoczny, nie jest selectable, nie zmienia nawigacji.

| Kontekst | Tekst overlay | Kolor |
|----------|---------------|-------|
| Plan aktywny | `PLAN  D{n}/{len}` | theme highlight (`_lighten(_cHLD,15)`) |
| `rd_last = RD_REST` | `REST ADVISED` | pomaranczowy `#FF8844` |
| `rd_last = RD_LIGHT` | `REC  {SHORT}  LIGHT` | theme dim (`_lighten(_cHLD,-10)`) |
| Bazowa rekomendacja CO2/O2/AP/BR | `REC  CO2 HARD` / `REC  O2 STD` / `REC  APNEA` / `REC  BREATHE` | theme dim (`_lighten(_cHLD,-10)`) |

`{SHORT}` = `CO2` / `O2` / `APNEA` / `BREATHE`. Dla tabel dolaczany jest profil trudnosci (`HARD`/`STD`/`EASY`) z `_previewRecommendation()`. Funkcja `_recOverlay()` jest *pure* — nie mutuje `_rdLast`, `_mode`, nie konsumuje readiness. Uzytkownik moze zignorowac podpowiedz i startowac co chce z LITE-slotow — coach nie blokuje.

### Uklad wizualny HOME

| Y | Element | Font |
|---|---------|------|
| 5% | Imie nurka | XTINY |
| 13% | **Overlay rekomendacji** (pure display) | XTINY |
| 22% | Tytul preview (`CO2 TABLE` / `O2 TABLE` / `STATIC APNEA` / `BREATHE`) | SMALL |
| 33% | Info preview (`Hold 1:06  8r STD` itp.) | XTINY |
| 44% | Pulsujacy `START` — tylko gdy `_hSel <= 4` (active) | SMALL |
| 54% | Linia separatora | — |
| 60% | Row pill `[BR] [CO2] [O2] [AP]` z kropka `_cINH` pod wybranym | XTINY |
| 72% | `Readiness check` — `_cHLD` (theme) gdy `_hSel == 5` | XTINY |
| 83% | `More...` — `_cINH` gdy `_hSel == 6` | XTINY |

Tytul i info pokazuja preview trybu z `_homePreviewMode()` — dla `_hSel == 0` tryb `_lastMode`, dla `_hSel = 1..4` odpowiednio BR/CO2/O2/AP (dokladnie jak LITE). Gdy `_hSel >= 5` (Readiness / More), preview pozostaje widoczny ale wygaszony (szary) — uzytkownik nadal wie co by sie stalo po SELECT na gornej polowie.

### Tap na HOME

Identyczne strefy jak LITE, powiekszone o strefe Readiness:

- `y < 51%` → `_hSel = 0` (Last Used)
- `51-64%` → pill row, kolumna wg `x`:
  - `x < 25%` → `_hSel = 1` (BR)
  - `25-50%` → `_hSel = 2` (CO2)
  - `50-75%` → `_hSel = 3` (O2)
  - `x >= 75%` → `_hSel = 4` (AP)
- `64-78%` → `_hSel = 5` (Readiness)
- `y >= 78%` → `_hSel = 6` (More)

Po wyborze z tapa natychmiast wywolywany `doSelect()` — zero dodatkowych krokow.

### Coach intelligence jest pasywna

- Rekomendacja jest **display-only**. `_recStart()`, `_recModeAndApply()` istnieja w kodzie, ale nie sa wywolywane z HOME. Nikt nie zmusza uzytkownika na coach pick.
- Readiness check jest **opt-in**. SELECT na `hSel = 5` uruchamia FT_READY; po zapisaniu wyniku `rd_last` SELECT w RP_RESULT wraca do HOME (nie uruchamia auto-sesji).
- Adaptive difficulty **dziala w tle**. `_progressCheck()` po sesji zmienia `_svCoMx`, `_svO2Mx` — nastepny instant start po prostu uzyje nowego presetu. Uzytkownik nic nie zauwaza poza delikatna zmiana info na HOME.
- Plan **nie przejmuje HOME**. Jesli plan jest aktywny, overlay pokazuje `PLAN D3/10`, ale slot `hSel = 0` nadal to *Last Used* instant start (nie plan). Start planowej sesji wymaga `More → Training Plan → START NEXT` (explicit).

---

## MORE — pelne menu (8 pozycji)

| mSel | Pozycja | Funkcja | Kolor |
|------|---------|---------|-------|
| 0 | Breathe | Konfiguracja Breathe + manualny start (hidden fallback) | bialy |
| 1 | CO2 Table | Konfiguracja CO2 + manualny start (hidden fallback) | bialy |
| 2 | O2 Table | Konfiguracja O2 + manualny start (hidden fallback) | bialy |
| 3 | **Training Plan** | Wybor / zarzadzanie planem | zloty (#FFDD44) |
| 4 | Stats | Statystyki (5 stron) | motyw |
| 5 | Customize | Theme + imie + vibration + **sensors** | motyw |
| 6 | **Guide** | Scrollowalna legenda / samouczek (65 wpisow, 10 sekcji) | zielony akcent |
| 7 | Reset | Factory reset | czerwony akcent |

BACK → HOME. Tap → wybor + select.

Wejscie w `Breathe`/`CO2`/`O2` ustawia `_plFromPlan = false` — to oddziela rcznie startowana sesje od sesji planu (progresja planu nie zostaje zaklocona).

---

## FT_HELP — Guide / Legenda (scrollowalna)

Dostepna przez `More → Guide` (mSel = 6). Zawiera **65 wpisow** pogrupowanych w **10 sekcji** — kompletna legenda wszystkich akronimow, symboli i pojec uzywanych w aplikacji.

**Nawigacja**: UP/DN scrolluje po wpisach; BACK wraca do More. Naglowki sekcji wyrozniaja sie kolorem i pozycja centralnie. Wskaznik przewijania (kropki) u dolu jak w Training Paths.

**Sekcje**:
1. NAVIGATION — skroty i gesty
2. TRAINING MODES — opis kazdego trybu treningu
3. BREATHE CONFIG — wszystkie pola konfiguracji
4. TRAINING FEEDBACK — interpretacja wiadomosci po sesji
5. STATS PAGES — co wyswietla kazda ze 5 stron statystyk
6. SENSOR HUB — live HR chip, brady, calm, readiness BB
7. READINESS CHECK — fazy i interpretacja wyniku
8. TRAINING PLANS — jak dzialaja plany, Skip/Repeat, ETA
9. PRO++ MODELS — CO2/O2/Recovery score, pattern detection
10. SYMBOLS — tabela wszystkich symboli (`^`, `v`, `~`, `!`, `*`, `>`)



## Recommended Session — logika coacha

Funkcja `_recModeAndApply()`:

**1. Priorytet PLANU** — jesli plan aktywny, laduje sesje `_planCurSes()` i ustawia `_plFromPlan = true`.

**2. Priorytet ostatniego trybu** — reguly bazowe:
- Po CO2 z `_stSucCo >= 3` → proponuje O2 z tym samym presetem
- Po CO2 z `_stFailCo >= 2` → Recovery Breathe
- Po O2 z `_stSucO2 >= 3` → Static Apnea
- Po Apnea → CO2 Standard
- Fallback: ostatni tryb

**3. Coach modifiers** (`_applyCoachModifiers()`) — warstwa nakladana na rekomendacje:
- **Fatigue high** → jesli APNEA → zamien na Breathe; jesli HARD → obnizenie do STD/EASY
- **Low confidence** → obniz trudnosc o 1 poziom, zmniejsz max hold CO2
- **`rd_last == RD_REST`** → wymusz Breathe Recovery 5 min
- **`rd_last == RD_LIGHT`** → APNEA → Breathe-up; CO2/O2 → DP_EASY
- Po zuzyciu `_rdLast` jest resetowany do `-1` w Storage

---

## Training State (RECOVERY / BUILDING / STABLE / PEAK)

Stan wyliczany przez `_trState()`:

| Warunek | State |
|---------|:-----:|
| `_coachFatigueHigh()` lub `_rdLast == RD_REST` | RECOVERY |
| `_stStreak >= 4` | PEAK |
| `_stSucCo >= 2` lub `_stSucO2 >= 2` lub `_stStreak >= 2` | BUILDING |
| W innym razie | STABLE |

`_coachFatigueHigh()` → true gdy:
- `_stStreak >= 3` (duzo kolejnych dni z treningiem), **lub**
- Ostatnie 3 apneie w `_apHist` maleja (trend spadkowy)

`_coachConfidenceLow()` → true gdy `fails >= 2 && fails >= successes`.

State pokazywany w naglowku slotu 0 HOME (`RECOMMENDED  BUILDING` itp.).

---

## Readiness Check (FT_READY)

Dedykowana pozycja na HOME (`hSel == 1`). Core entry gate dla ciezkich sesji — wynik `rd_last` moduluje kolejna rekomendacje coacha.

### Przebieg 3-fazowy

**Faza 1 — `RP_BREATHE` (30s guided breathe):**
- Naglowek `READINESS CHECK` (turkus)
- Komunikat `Breathe calmly`
- Etykieta fazy `INHALE` / `EXHALE` (naprzemiennie, kolor z motywu)
- Duza cyfra odliczajaca (30 → 0)
- `SELECT = skip` przechodzi do fazy 2; `BACK = cancel` → HOME

**Faza 2 — `RP_APNEA` (manualny hold):**
- `Hold breath`
- Duzy timer count-up, kolor skalujacy: zielony → zolty (>= 45s) → czerwony (>= 75s)
- `SELECT = stop` konczy i wylicza score

**Faza 3 — wynik:**
Score na bazie czasu vs PB:
- `RD_READY` — hold >= 30s i (`PB == 0` lub `hold / PB >= 50%`)
- `RD_LIGHT` — hold >= 15s
- `RD_REST` — ponizej

Wyswietla:
- Migajacy wynik (`READY` / `LIGHT SESSION` / `REST`)
- `Hold M:SS`
- Hint: `Recommended: normal / light / recovery`
- `SELECT = start` → `_recStart()` (z downgrade'm na bazie `_rdLast`)
- `BACK = home`

Wynik zapisywany w `rd_last` w Storage. Uzywany **jednorazowo** przez `_applyCoachModifiers()` i czyszczony po zuzyciu.

---

## Adaptive Plan Progression

Po ukonczeniu kazdej sesji z planu (`_plFromPlan == true`) → `_planAdvanceWith(outcome)`:

| Outcome | Warunek | Efekt |
|---------|---------|-------|
| `PO_NORMAL` | Ukonczono normalnie | Dzien +1 |
| `PO_REPEAT` | CO2/O2 early exit (BACK w ACT/PAU) lub Apnea < 15s | **Dzien bez zmian** (powtorz) |
| `PO_SKIP` | Apnea bardzo latwa (`_apLS * 10 >= _apPB * 11`) lub Breathe/Tbl ukonczone bez pauz i krotko | **Dzien +2** (pomin) |

Po osiagnieciu konca planu → `_plAct = PL_NONE`, stan zresetowany.

---

## Training Plans (FT_PLAN)

**8 predefiniowanych planow** po 10 sesji. Progress zapisywany (`pl_act`, `pl_day`).

| ID | Nazwa | Opis | Charakterystyka |
|----|-------|------|-----------------|
| 0 | Beginner | 4 weeks intro | mix wszystkich trybow, niska intensywnosc |
| 1 | CO2 Tolerance | Build CO2 tolerance | dominacja CO2 tables, narastajaca trudnosc |
| 2 | Apnea Progression | Grow your hold | apnea + O2 booster + breathe-up |
| 3 | O2 Adaptation | Hypoxia adapt | dominacja O2 tables, narastajaca dlugosc holdow |
| 4 | Breathwork Mastery | Wim Hof + Pranayama | wszystkie 5 presetow oddechowych w cyklu |
| 5 | Endurance Mix | Full spectrum | rownomierne BR/CO2/O2/AP, dla zaawansowanych |
| 6 | **Static PB** | Push static PB | minimal CO2 chatter, heavy max-effort static + recovery |
| 7 | **Active Recovery** | Light week reset | gentle breathwork + sub-max O2 + short holds |

### UI FT_PLAN

**Gdy brak aktywnego planu:**
- Compact lista 4 widocznych pozycji + Cancel z highlightem aktywnego wiersza
- Pionowy scroll-indicator (kropki) po prawej stronie pokazuje pozycje w liscie 8 planow + Cancel
- Kazdy plan = `nazwa` + `krotki opis` w 2 linijkach

**Gdy plan aktywny:**
- Tytul `TRAINING PATH`
- Nazwa planu
- `Session {n} / {len}`
- Pasek progresu (zloty)
- `Adjusted schedule` (jesli ostatnia sesja zakonczona z repeat/skip)
- `Next session: {nazwa}`
- Akcje:
  - `START NEXT` (zielony)
  - `Skip session`
  - `End path` (czerwony)

---

## Difficulty Profiles (Easy / Standard / Hard)

4. pole w FT_TCFG (MAX HOLD → ROUNDS → **PROFILE** → START).

### CO2 Table

| Profile | Hold % max | Rest start | Rest end | Krzywa |
|---------|:----------:|:----------:|:--------:|--------|
| Easy | 45% | 2:30 | 0:45 | ease-out |
| Standard | 55% | 2:00 | 0:30 | liniowa |
| Hard | 65% | 1:40 | 0:20 | ease-in |

### O2 Table

| Profile | Hold % start | Hold % end | Rest | Krzywa |
|---------|:------------:|:----------:|:----:|--------|
| Easy | 40% | 70% | 2:30 | ease-in |
| Standard | 50% | 85% | 2:00 | liniowa |
| Hard | 55% | 95% | 1:40 | ease-out |

Krzywa kontroluje tempo zmian: Easy zaczyna agresywnie a zwalnia, Hard zaczyna lagodnie a przyspiesza.

---

## Adaptive Difficulty (auto-progression)

Funkcja `_progressCheck()` po kazdej tabeli:

- `_stSucCo >= 3` i `_svCoMx < 6` → **`_svCoMx++`** (wyzszy poziom) + reset licznika
- `_stFailCo >= 2` i `_svCoMx > 0` → **`_svCoMx--`** (nizszy poziom)
- Analogicznie O2

Counter success/fail:
- CO2/O2 success — ukonczona tabela
- CO2/O2 fail — BACK w ACT/PAU (early exit)
- Apnea success — hold >= 30s
- Apnea fail — hold < 15s

Licznikom odpowiadaja klucze `st_suc_*` i `st_fail_*`.

---

## Post-session Feedback (2-line standard, obowiazkowy)

FT_DONE zawsze pokazuje **linie 1 — performance** + **linie 2 — recommendation**. Brak raw-only feedbacku. PRO nigdy nie wyswietla samego "Session complete".

### APNEA
| Warunek | Line 1 | Line 2 |
|---------|--------|--------|
| New PB | `Peak performance` | `Recovery recommended` |
| >= 90% PB | `Strong session` | `Recovery recommended` |
| < 20s lub < 60% PB | `Light session` | `Build gradually` |
| Inne | `Stable session` | `Continue progression` |

### CO2 / O2
| Warunek | Line 1 | Line 2 |
|---------|--------|--------|
| `_pauseCnt >= 2` | `High load session` | `Rest advised` |
| Sesja z planu | `Strong progression` / `Stable session` | `Path continues` |
| `_stSucCo/O2 >= 2` | `Strong progression` | `Continue progression` |
| Inne | `Stable session` | `Continue progression` |

### BREATHE
| Warunek | Line 1 | Line 2 |
|---------|--------|--------|
| Sesja z planu | `Recovery session` | `Path continues` |
| Standard | `Recovery session` | `Continue progression` |

Nie ma innych linii/komentarzy — tylko format `1 + 1`, recommendation mandatory.

---

## FT_STAT — statystyki (5 stron)

Przelaczanie miedzy stronami: **UP / DOWN** lub **TAP** w dowolnym miejscu ekranu (cyklicznie 0 → 1 → 2 → 3 → 0). Pod tytulem zawsze 4 male kropki — wypelniona kropka = aktualna strona.

Wszystkie 5 stron sa **read-only** (nie da sie nic zmienic / skasowac). **BACK** wraca do HOME.

### Strona 1 — TRAINING STATS

Cel strony: szybki "kim jestem jako diver, ile w sumie zrobilem".

| Element (gora → dol) | Wyglad | Co dokladnie pokazuje |
|----------------------|--------|----------------------|
| **Hero number** | duza biala liczba (`12`) | Laczna liczba **wszystkich ukonczonych sesji** = `BR + AP + CO2 + O2`. Zliczamy tylko sesje ktore doszly do FT_DONE; przerwane (BACK z aktywnej sesji) **nie licza sie**. |
| **"sessions"** | szare male | Etykieta hero. |
| **`Yh Zm total`** | theme color, dim | Calkowity **czas spedzony w aplikacji na treningu** w godz/min. Liczone jako suma `dur` z kazdej sesji — dla Breathe to czas oddychania, dla Apnea to czas pojedynczego holdu, dla CO2/O2 to **caly czas table** (holds + rests). |
| **`BR X    AP Y`** | jasnoszary | Liczba ukonczonych sesji **Breathe** i **Apnea** osobno. |
| **`CO2 X   O2 Y`** | jasnoszary | Liczba ukonczonych sesji **CO2 Table** i **O2 Table** osobno. Suma `BR+AP+CO2+O2` musi sie zgadzac z hero number. |
| **`PB M:SS`** | theme highlight (`_cHLD`) | **Personal Best** statycznej apnei w formacie `mm:ss`. Aktualizuje sie wylacznie na zakonczeniu sesji APNEA, gdy `s > _apPB`. `0:00` = brak jeszcze zadnej apnei. |
| **`Wk X ses  Y/7d`** | dim theme color | Mini-snapshot z biezacego tygodnia: `X` = liczba sesji w **tym** tygodniu (`_wkSes[0]`), `Y/7d` = w ilu z **ostatnich 7 dni** byla co najmniej jedna sesja (consistency). Wartosci sa auto-rolled na render — czyli jak masz 3 dni przerwy, przy wejsciu na Stats `Y/7d` od razu pokazuje aktualna prawde. |

### Strona 2 — PROGRESSION (4 mini-trendy w jednym ekranie)

Cel strony: "czy sie poprawiam vs ostatnie 5 sesji" — 4 metryki, jeden rzut oka.

Layout: 4 wiersze, kazdy ma identyczna budowe `[LABEL]   [5-bar histogram]   [trend  value]`. Najnowszy slupek jest po **prawej**, najstarszy po **lewej** (czytamy lewa-do-prawej jak czas).

#### Wiersze (od gory):

**1. `APNEA` — PB-scaled apnea history**
- 5 slupkow = ostatnie 5 ukonczonych sesji APNEA (ring buffer `_apHist[]`).
- Wysokosc slupka = `holdSec / PB` (procent twojego PB). Pelna wysokosc = 100% PB.
- **Najnowszy slupek** (skrajny prawy) ma kolor wg progu wzgledem PB:
  - `≥80% PB` → theme highlight (`_cHLD`) — **strong**
  - `60–79% PB` → pomaranczowy (`#FFA060`) — **OK**
  - `<60% PB` → czerwony (`#FF5533`) — **weak / off day**
- Starsze slupki: dim theme color (kontekst, nie krzycza).
- Strzalka po prawej: `^` zielona = ostatnie 2 sesje srednio lepsze niz poprzednie 3 (o ≥2s); `v` czerwona = gorsze; `-` szara = stable.
- Wartosc po prawej: czas **najnowszej** sesji w `M:SS`.

**2. `CO2` — tolerance score history**
- 5 slupkow = `_coVHist[5]`, push'owane na koncu kazdej sesji CO2 Table.
- Skala 0..100 (full bar = score 100). Score liczony przez `_updateCo2Model()` z `(rounds * difficulty) - pauses*6`.
- Najnowszy slupek koloruje sie progowo (niezalezne od progow apnei):
  - `≥65` → theme (`_cHLD`) — strong tolerance
  - `40–64` → pomaranczowy — building
  - `<40` → czerwony — weak / fatigued
- Trend: srednia ostatnich 2 vs poprzednich 3 z `_coVHist`, prog ±2 punktow.
- Wartosc po prawej: aktualny `_coTolScore` (0..100).

**3. `O2` — adaptation score history**
- Identyczna mechanika jak CO2, dane z `_o2VHist[5]` push'owanych po sesjach O2 Table.
- Score = `_o2AdaptScore` z `_updateO2Model()` (peak ratio + progression - early collapse).

**4. `BR` — recovery score history**
- Identyczna mechanika, dane z `_brVHist[5]` po sesjach Breathe.
- Score = `_brRecScore`. Wysoki = breathe-work skutecznie cie regeneruje (mierzone czy nastepna sesja byla lepsza/gorsza).

**Footer (na dole strony):** `Xd  Y/7  Zm`
- `Xd` = **streak** = liczba **kolejnych dni z ≥1 sesja** (resetuje sie przy 1 dniu pauzy).
- `Y/7` = **7-day consistency** — w ilu z ostatnich 7 dni cos zrobiles (z `_dayBits`).
- `Zm` = **lifetime hold total** w minutach (`_stHoldT / 60`) — laczny czas wszystkich bezdechow w historii (apnea + table holds, **bez** breathe i bez rest periods).

> **Uwaga o "------"**: jezeli najnowszy slot histogramu jest 0 ale aktualna wartosc score > 0, renderer fallbackuje do score'a, zeby strona nie wygladala na pusta po pierwszej sesji.

### Strona 3 — PHYSIOLOGY (PRO++ user dashboard)

Cel strony: "jaki mam aktualnie stan ciala / co system o mnie wie".

Identyczny styl wierszy jak PROGRESSION (5-bar histogram + trend + score), ale **tylko 3 metryki fizjologiczne** (bez apnei) plus **profilowanie i predykcje**.

| Element | Wyglad | Co znaczy |
|---------|--------|-----------|
| `CO2  ███▒░ ^ 72` | mini-trend row | CO2 tolerance: jak komfortowo radzisz sobie z narastajacym CO2 podczas tables. Score 0..100, kolor najnowszego slupka jak na PROGRESSION (≥65 zielony, 40–64 pomaranczowy, <40 czerwony). |
| `O2   ███░░ ^ 62` | mini-trend row | O2 adaptation: jak dobrze ciezar sesji jest tolerowany w trybach hipoksji. |
| `REC  █░░░░ v 45` | mini-trend row | Recovery: skutecznosc twoich sesji breathe jako narzedzia regeneracji. Niskie = breathe ci nie pomaga (zle technika lub przetrenowanie). |
| **Diver class** | jasny napis pod wierszami | Klasyfikacja na podstawie 3 powyzszych: `BALANCED`, `CO2 DOMINANT` (CO2 > O2 + 15), `O2 LIMITED` (O2 > CO2 + 15), `RECOVERY LIMITED` (REC < 40). |
| **Pattern flag / PB prediction** (footer) | jeden napis, kolor wg powagi | Priorytet (od najwyzszego): `OVERTRAIN` (red, streak ≥4 + decline) → `DECLINE` (orange, ostatnie 3 sesje strictly maleja) → `PLATEAU` (grey, ostatnie 5 sesji w ±5%) → `PB M:SS +Xs` (kolor wg confidence: zielony ≥60, pomaranczowy ≥35, szary <35). Pojawia sie tylko gdy jest sygnal — pusto przy normalnym progress. |

Wartosci scoreow zmieniaja sie **stopniowo** (±3..4 punkty na sesje), nie skacza — to celowe, zeby jeden zly dzien cie nie zdolowal a jeden swietny cie nie zaslepil.

### Strona 4 — WEEKLY (PRO++ v4) — week-by-week + activity strip

Cel strony: "jaki jest moj weekly volume i czy regularnie trenuje".

#### 4.1. 8-tygodniowy bar chart (gora ekranu)

- 8 slupkow obok siebie, **najstarszy lewy → "now" prawy** (czytamy jak czas).
- **Wysokosc slupka** = liczba sesji w danym tygodniu. **Skala** = `max(_wkSes[])` z floor'em 3 (minimum 3-sesyjna skala) — zeby pojedynczy slupek przy starcie nie wypelnial calego wykresu i zeby tygodnie z 1 vs 2 sesjami byly wizualnie odrozne.
- **Kolor slupka biezacego tygodnia** (skrajny prawy) wg trendu vs poprzedni tydzien:
  - `> _wkSes[1]` → **zielony** (`_cHLD`) — wiecej niz w zeszlym tygodniu
  - `< _wkSes[1]` → **pomaranczowy** (`#FFA060`) — mniej
  - `=` → **theme dim** — flat
- **Starsze slupki** (idx 0..6 od lewej): theme color **progresywnie ciemniejszy** im starszy (`-45 - i*3` lighten). Daje "depth cue" — oko od razu widzi "to historia, tam jest teraz".
- **Pusty tydzien** (zero sesji): cienka kreseczka 2px na osi (zeby bylo widac ze tydzien istnial, nie ze go nie ma).
- **Os X**: po lewej napis `8w`, po prawej `now`. Brak osi Y / liczb — czytamy kolor + relatywne wysokosci.

#### 4.2. This-week summary line (srodek ekranu)

- Bialy napis: **`X ses  Ym hold`**
  - `X` = `_wkSes[0]` — liczba **sesji** w tym tygodniu.
  - `Y` = `_wkHold[0] / 60` — laczne **minuty bezdechu** w tym tygodniu (apnea + table holds, **bez** breathe i **bez** rest periods miedzy holdami).

#### 4.3. Δ vs last week (pod summary)

Krotki opis zmiany vs poprzedni tydzien, kolor wg kierunku:
- **`+25% vs last wk`** zielona — wiecej sesji niz tydzien temu
- **`-12% vs last wk`** pomaranczowa — mniej sesji
- **`= last wk`** szara — taka sama liczba
- **`first week`** szara — to twoj pierwszy tydzien (`_wkSes[1] == 0`), brak punktu odniesienia
- (puste) — gdy w ogole nie ma jeszcze danych

#### 4.4. 14-day activity dot strip (pasek pod summary)

- **14 malych kropek** w jednym rzedzie, **najstarsza lewa → today prawa**.
- **Wypelniona** = ten dzien mial ≥1 ukonczona sesje
- **Pusta (kontur)** = brak treningu tego dnia
- **"Today"** (skrajna prawa kropka): minimalnie wieksza + **delikatnie pulsuje** w rytm theme color (12-tick cycle) — zeby od razu wiadomo ktora to dzis.
- Dane z `_dayBits` (14-bit bitmap, bit 0 = dzisiaj). Auto-rolled na render — jak masz 5 dni przerwy, kropki sie przesuwaja zanim to zobaczysz.

#### 4.5. Footer (dol ekranu)

- **`Best X/wk`** (jasny szary): rekord tygodniowy **ever** = max wartosc jaka kiedykolwiek osiagnal `_wkSes[0]` (`_wkBestSes`). Aktualizuje sie tylko w gore — to "high score" twojego volume'u tygodniowego.
- **`X/7 days active`** (kolor wg progu): dokladnie te same `X/7` co na pierwszej stronie i w footerze PROGRESSION:
  - `≥5/7` → **zielony** (`_cHLD`) — solid consistency
  - `3–4/7` → **theme dim** — OK
  - `<3/7` → **pomaranczowy** — ostrzegawczo, malo regularnie

#### 4.6. Cold start

Jezeli `_wkBaseDay == 0` (nigdy nie zapisana zadna sesja), zamiast wykresu pokazuje sie:
```
No sessions yet
Train to build
your weekly chart
```

#### 4.7. Dane / storage (pod maska)

| Pole | Opis |
|------|------|
| `_wkSes[8]` | sessions per week, **idx 0 = aktualny tydzien**, idx 7 = najstarszy. Storage `wk_s0..7`. |
| `_wkHold[8]` | actual hold seconds per week (apnea hold + sum of table holds, **bez** rests, **bez** breathe). Storage `wk_h0..7`. |
| `_wkBaseDay` | epoch day index gdy zaczal sie tydzien `[0]` — rolluje co 7 dni. Storage `wk_base`. |
| `_wkBestSes` | high-score peak weekly volume. Storage `wk_best`. |
| `_dayBits` | 14-bit bitmap, **bit 0 = dzisiaj**, bit 13 = 13 dni temu. Storage `dy_bits`. |
| `_dayBitsRef` | epoch day kiedy bit 0 byl ostatnio ustawiony (potrzebne do shift'u). Storage `dy_ref`. |

Buckets sa **render-safe**: przy kazdym renderze strony WEEKLY (i mini-summary na pierwszej stronie / footera PROGRESSION), `_advanceWeeks(today)` i `_advanceDayBits(today)` przesuwaja zawartosc tak, ze `[0]` zawsze znaczy "ten tydzien" i bit 0 zawsze znaczy "dzisiaj" — nawet po dlugiej przerwie. Storage flush'uje sie tylko gdy faktycznie cos sie przesunelo (no flash thrash).

### Cold-start (fresh install / po Factory Reset)

Po **swiezej instalacji** apki LUB po **Factory Reset** wszystkie statystyki i progresja startuja od **prawdziwego zera** — apka nie zaklada zadnej wstepnej wiedzy o uzytkowniku:

| Strona | Co widac przy zerowej historii |
|--------|------------------------------|
| **TRAINING STATS** | `0` sessions, `0m total`, `BR/AP/CO2/O2 = 0`, `PB 0:00`, `Wk 0 ses  0/7d` |
| **PROGRESSION** | Placeholder: **"No sessions yet — Train to build your trends"** (zamiast pustych wierszy z mylacym 0/100) |
| **PHYSIOLOGY** | Placeholder: **"No sessions yet — Physiology data appears here"** (zamiast pomaranczowych slupkow z domyslnym `BALANCED diver` przy zero treningu) |
| **WEEKLY** | Placeholder: **"No sessions yet — Train to build your weekly chart"** |
| **SENSOR TRENDS** | Placeholder: **"No sensor data yet — Train with Sensors ON to build your trends"** |

Pierwsza ukonczona sesja od razu odblokowuje wszystkie strony — placeholder znika i zaczynaja sie rysowac realne wykresy/wartosci.

> **Pod maska**: `_resetAll()` wywoluje `Application.Storage.clearValues()` (czysci dysk) **oraz** zeruje wszystkie zmienne PRO++ w pamieci (`_coTolScore`, `_o2AdaptScore`, `_brRecScore`, `_coVHist`, `_o2VHist`, `_brVHist`, `_coLoadHist`, `_o2LoadHist`, `_pbPredicted`, `_pbConfidence`, pattern flags, diver profile, session score) — bez tego po Reset strony PROGRESSION/PHYSIOLOGY pokazywalyby pre-reset slupki az do restartu apki. Defaults w `_loadPhysio()` rowniez sa `0` (wczesniej `50/50/60`), wiec swiezy install zachowuje sie identycznie jak Reset.

### Strona 5 — SENSOR TRENDS (PRO++ v5.2) — co mozna z tego odczytac

Piata strona statystyk (UP/DN/TAP). Pokazuje dane zebrane przez **Sensor Hub** przez caly czas treningow. Strona jest **czysto informacyjna** — nie wymaga zadnych dodatkowych uprawnien poza tymi juz dodanymi dla Sensor Hub. Dane buduja sie automatycznie po kazdej sesji z wlaczonymi sensorami.

Strona podzielona na 3 sekcje. Kazda sekcja ma **naglowek centralnie** (bez nakladania na dane), a potem dane na liniach ponizej — eliminuje to wczesniejsze problemy z nakladaniem etykiet na slupki/kropki.

#### Sekcja A — DIVE REFLEX (header y=26%)

Pokazuje jak silna jest **odpowiedz mammalian dive reflex** podczas zanurzen/apnea.

**Co to jest Dive Reflex?** To ewolucyjny mechanizm ssakow (foki, wieloryby, delfiny — i czlowiek). Gdy twarz trafia w zimna wode LUB gdy wstrzymasz oddech wystarczajaco dlugo, uklad nerwowy automatycznie zwalnia HR aby oszczedzic tlen dla mozgu i serca. U wytrenowanych freediverów drop moze wynosic 30-50+ BPM. U poczatkujacych moze byc 5-10 BPM.

**Wizualizacja** (y=31% slupki, prawa strona y=27% i y=33%):
- **5-slupkowy sparkline** (od lewej = starsze, od prawej = nowsze) — ostatnie 5 sesji apnea. Kolory: ≥15 BPM = `_cHLD` (epicki), ≥8 BPM = dim, <8 = ciemny.
- **"PB -X bpm"** — all-time best bradycardia delta (`_snBradBest`).
- **"Last -X"** — ostatnia sesja (`_snBradLast`).

**Interpretacja**: Jesli slupki sa coraz wyzsze, Twoj uklad nerwowy uczy sie glebiej aktywowac dive reflex. Jesli niskie i stabilne — dalej trenuj, reflex sie buduje powoli.

#### Sekcja B — CALM INDEX (header y=45%)

Mierzy jak dobrze **Breathe-Up (breathwork) obniza HR** przed zanureniem. Nizsza HR przed holdem = wiecej miejsca na dive reflex = dluzszy hold.

**Jak sie liczy Calm Score (0..100)**:
- Podczas sesji BREATHE, `_snSessionEndBr()` sprawdza HR baseline (z poczatku sesji) vs HR min (najnizszy zaobserwowany punkt).
- `calmScore = min(100, hrDrop × 8)` — wiec 12+ BPM drop = 100/100, 6 BPM drop = 48, itd.
- EMA (α=0.30) aktualizuje `_snCalmAvg` — gladzac szum pojedynczych sesji.

**Wizualizacja** (paski y=53% i y=58%, etykieta y=63%):
- **AVG bar** (row 1) — EMA srednia ze wszystkich sesji. Pelna szerokosc = 100/100.
- **LAST bar** (row 2) — ostatnia sesja. Zielony jesli > avg, pomaranczowy jesli < avg-10.
- **Etykieta**: `Excellent calm` (≥70) / `Good progress` (≥45) / `Building` (≥20) / `Keep practicing` (<20).
- **"X/100"** — aktualny avg EMA, wyrownany do prawej.

**Interpretacja**: Calm Index rosnie gdy regularnie cwiczysz breathwork I gdy HR faktycznie sie obniza — apka mierzy skutecznosc, nie samo cwiczenie. Dobry freediver przed holdem ma HR 45-55 bpm (vs spoczynkowych 65). Jesli Calm Index nie rosnie mimo sesji, sprawdz technik: wydech powinien byc dluzszy niz wdech.

#### Sekcja C — READINESS (header y=70%)

Pokazuje **Body Battery w chwili rozpoczecia ostatnich 5 sesji** — sprawdz czy trenujesz kiedy jestes wypoczety.

**Wizualizacja** (kropki y=78%, header i RHR/O2 na y=70%):
- **5 centralnie wyrownanych kropek** (oldest left, newest right):
  - Zielona — BB ≥ 60: wypoczety.
  - Zloto-pomaranczowa — BB 30-59: OK, blisko granicy.
  - Pomaranczowa — BB < 30: zmeczony.
  - Szara obwodka — brak danych BB.
- **"RHR X  O2 XX%"** — aktualny Resting HR i SpO2, wyrownane do prawej na tej samej linii co naglowek (nie nachodzace na kropki).

**Interpretacja**: Wszystkie pomaranczowe kropki = trenujesz permanentnie zmeczony → ryzyko plateau i plateau kontuzji. Idealny wzorzec: zielony/zloty naprzemiennie. SpO2 ≥ 96% = dobra kondycja bazalna.

**Nowe klucze storage**:

| Klucz | Typ | Znaczenie |
|-------|-----|-----------|
| `sn_brad_hist` | Array[5] Int | Ostatnie 5 brad-deltas (BPM) |
| `sn_calm_last` | Int 0..100 | Calm score z ostatniej BREATHE sesji |
| `sn_calm_avg`  | Int 0..100 | EMA calm score (α=0.30) |
| `sn_bb_start`  | Array[5] Int | BB w chwili startu ostatnich 5 sesji (-1=brak) |
| `sn_hr_drop_avg` | Int BPM | EMA HR drop podczas breathe-up (α=0.35) |

### Sensor Hub (PRO++ v5.2) — co sensory dodaja gdzie

Garmin Sensor integration jest **opt-in** (Customize → Sensors ON/OFF; default ON), defensywne (try/catch + capability detection) i **gracefully degraduje** na watchach bez danego sensora — gdy sensor jest niedostepny, chip po prostu sie nie rysuje, layout sie zwija.

**Co jest czytane**:

| Sensor | API | Wymaga permission | Uzywane gdzie |
|--------|-----|:-----------------:|---------------|
| Live HR (BPM) | `Activity.getActivityInfo().currentHeartRate` → `Sensor.getInfo().heartRate` → `SensorHistory.getHeartRateHistory` | `Sensor` | BREATHE/APNEA/TABLE active chip, FT_READY chip, FT_DONE bradycardia |
| Body Battery (0..100) | `SensorHistory.getBodyBatteryHistory({:period=>1})` | `SensorHistory` | PHYSIOLOGY strip, FT_READY result snapshot |
| Stress (0..100) | `SensorHistory.getStressHistory({:period=>1})` | `SensorHistory` | (rezerwowy) |
| SpO2 (%) | `SensorHistory.getOxygenSaturationHistory({:period=>1})` | `SensorHistory` | PHYSIOLOGY strip |
| Resting HR | `SensorHistory.getHeartRateHistory({:period=>1})` | `SensorHistory` | PHYSIOLOGY strip |

> **Nota**: Sensor column na ekranie HOME została usunięta (v5.2) — sensory widoczne są **wyłącznie podczas aktywnych sesji treningowych** i readiness check. HOME zachowuje oryginalny czysty layout.

#### Anatomia live HR chip (`_snDrLive(dc, y, calmMode)`) — uzywany w trakcie sesji

Pojedynczy chip na prawej krawedzi w strefie **`y=18%`** (top-right safe strip, zawsze poza centralnym ringiem/balem). Layout: `maly dot (3px) + BPM ± delta`. Pulsuje gdy zaobserwowany positive delta przekroczy progu calm/bradycardia.

- `calmMode = false` (APNEA, TABLE-HOLD): prog `≥10 BPM` drop dla zielonego pulsu (mammalian dive reflex)
- `calmMode = true` (BREATHE, TABLE-BREATHE): prog `≥5 BPM` drop (parasympathetic engagement)
- **Delta wyswietlane tylko gdy ≥5 BPM** — mniejsze fluktuacje to szum, nie sygnał. Format: `"72-8"` (HR spada), `"80+6"` (HR rosnie).
- Delta `≤ -5 BPM` (HR strzelajacy do gory) → orange `0xFFA060`
- Pozostale → pink-red baseline `0xFF6688`

> **Dlaczego y=18%?** Poprzedni y=42% lądował w środku kuli oddechowej (BREATHE) lub przy obramowaniu ringu (APNEA). Przeniesienie do 18% gwarantuje brak kolizji na każdym urządzeniu i każdej fazie treningu.

#### FT_READY — sensory podczas Readiness Check

**v5.2**: Live HR chip (`_snDrLive`) dodany do wszystkich faz readiness check:

| Faza | Co widać | Cel |
|------|----------|-----|
| `RP_BREATHE` (30s breathe) | HR chip top-right, `calmMode=true` | Potwierdź że HR faktycznie spada podczas breathe-up |
| `RP_APNEA` (hold) | HR chip top-right, `calmMode=false` | Obserwuj dive reflex w czasie rzeczywistym |
| Wynik (READY/LIGHT/REST) | `"HR XX  BB XX%"` centered w y=68% | Dane obiektywne potwierdzają lub kwestionują wynik |

#### APNEA — zmniejszony hold ring

Promien centralnego ringu HOLD spadl z `36% _w` → **`31% _w`** zeby:
1. Zachowac wizualnie spojne proporcje z BREATHE / TABLE ringami (oba rendruja w `~28%`).
2. Zapobiec wizualnemu zachodzenieu sensor chipa (y=18%) z outer-glow rings.
3. Lepiej trzymac sie round-watch safe zone — przy 36% outer-glow rings dotykaly bezelu.

#### FT_DONE (apnea) — bradycardia readout
- Po sesji apnea, jesli HR drop ≥ 0:
  - **"HR -X bpm"** linia w pozycji `y=62%` (centered, safe-zone).
  - Color tier: ≥15 BPM = `_cHLD` (epicki dive reflex), ≥8 = `_cINH` dim (porzadny), <8 = ledwie widoczny (slabszy reflex).
- Sufix **"PB"** kiedy ten session pobil dotychczasowy `_snBradBest` — bradycardia tez ma swoj personal best.

#### PHYSIOLOGY page (FT_STAT page 3) — sensor strip footer
Ostatnia linia (`y=89%`), kompaktowe ASCII chipy oddzielone spacja:

| Chip | Znaczenie | Pochodzenie |
|------|-----------|-------------|
| `RX` | Resting HR | SensorHistory.getHeartRateHistory (latest sample, baseline) |
| `BBX` | Body Battery 0..100 | SensorHistory.getBodyBatteryHistory |
| `OX` | SpO2 % | SensorHistory.getOxygenSaturationHistory |
| `vX` | Best bradycardia delta (BPM dropped) | obliczone z apnea sessions |

Strona PHYSIOLOGY swiadomie uzywa stripu (a nie kolumny) — bo srodek ekranu okupuja juz 3 metric rows + diver class + flag, wiec prawa krawedz nie jest tam wolna. Strip auto-skipuje chipy ktorych sensor jest off, layout collapse'uje sie.

#### Customize — Sensors ON/OFF
Nowy 4-ty wiersz Customize (przed `Gen Test User` / `SAVE`):
- **Sensors  ON** — default (gdy zaden sensor jeszcze nie odpalil, label staje sie **"Sensors  N/A"** zeby user widzial ze toggle dziala ale watch nie ma supportu / permissionu).
- **Sensors  OFF** — wszystkie badge'y znikaja, `Sensor.setEnabledSensors([])` oszczedza baterie.
- Toggle persistowany jako `usr_sn` (Boolean).

**Battery footprint**: HR sampling jest rate-limited do **1Hz** (~1 read/s podczas treningu, ~0.2 read/s na HOME). SensorHistory reads sa cached i czyta sie je tylko podczas idle na HOME (co ~5s). Whole hub adds < 1% extra battery drain w trakcie typowej 15-min sesji breathwork.

### Co sie liczy do statystyk a co nie

| Akcja | Liczy sie do `total sessions` / `_stXxC` | Liczy sie do `_wkSes` (weekly bucket) | Liczy sie do `_wkHold` (weekly hold sec) | Liczy sie do `_stHoldT` (lifetime hold) |
|-------|:---:|:---:|:---:|:---:|
| Sesja BREATHE doszla do FT_DONE | ✓ (`_stBrC`) | ✓ | ✗ (0s — to nie hold) | ✗ |
| Sesja APNEA doszla do FT_DONE | ✓ (`_stApC`) | ✓ | ✓ (caly hold) | ✓ |
| Sesja CO2 TABLE doszla do FT_DONE | ✓ (`_stCoC`) | ✓ | ✓ (suma holdow, **bez** rests) | ✓ |
| Sesja O2 TABLE doszla do FT_DONE | ✓ (`_stO2C`) | ✓ | ✓ (suma holdow) | ✓ |
| BACK z aktywnej sesji (przerwanie) | ✗ | ✗ | ✗ | ✗ |
| Demo tour | ✗ (sesje sa sztucznie nie-konczone) | ✗ | ✗ | ✗ |

---

## FT_CUST / FT_NAME / FT_BCFG

- **Customize (PRO++ v5)** — 5 wierszy: `Theme` / `Name` / `Vibration ON-OFF` / `Sensors ON-OFF-N/A` / `SAVE` (+ `Gen Test User` gdy `DBG_ENABLED = true`). 10 motywow (5 LITE-compat + 5 PRO).
- **Gen Test User** — dostepny jako ostatni wiersz Customize gdy `DBG_ENABLED`. SELECT otwiera ekran potwierdzenia `FT_GTU` (nie uruchamia bezposrednio). Umozliwia uzytkownikowi bezpieczne zapoznanie sie z apka bez ryzyka przypadkowego nadpisania danych.
- **Name editor** — 8-znakowy edytor z wheel pickerem
- **Breathe config** — **6 trybow**:
  - `Recovery 2-4` — slow recovery
  - `Breathe-Up 3-6` — pre-dive prep
  - `Box 4-4-4-4` — calm focus
  - `Wim Hof Power 2-1` — power breathing (oxygenation, hyperventilation control)
  - `Pranayama 4-7-8` — yogic relaxation (sleep / down-regulation)
  - `Custom` — pelna konfiguracja IN/HOLD/EX/HOLD-EX
  Sesja 5/10/15/20/30 min

---

## FT_GTU — Gen Test User (potwierdzenie)

Ekran potwierdzenia przed zaladowaniem danych demonstracyjnych. Dostepny przez `Customize → Gen Test User` (tylko gdy `DBG_ENABLED = true`).

Ekran pokazuje:
- `GEN TEST USER` (pomaranczowy naglowek)
- `Load demo data?`
- `Fills stats, PB, physio, sensor trends + demo tour.`
- Ostrzezenie: `Your real training data will be overwritten!`
- Migajacy `SELECT = YES` / `BACK = cancel`

SELECT → `_genTestUser()`:
- Seeduje pseudo-losowe dane treningowe (PB, historia apnea, PRO++ physio scores, weekly stats, sensor trends)
- Ustawia `_snAvail = 0x1F` — pelen sensor suite widoczny w simulatorze
- Uruchamia automatyczny demo tour (marketing showcase)
- Przechodzi do FT_HOME

BACK → powrot do `FT_CUST`.

---

## FT_RST — factory reset

Ekran potwierdzenia:
- `FACTORY RESET`
- `Erase all data?`
- `Stats, PB, plan, name, theme cleared`
- `SELECT = YES` / `BACK = cancel`

SELECT → `_resetAll()`:
1. `Application.Storage.clearValues()`
2. Reset wszystkich zmiennych w pamieci: presety, PB, log, `_apHist`, streaks, success/fail countery, plan (PL_NONE, day 0), `_rdLast = -1`, imie "USER", motyw #0, stats
3. Double-vibe potwierdzenie
4. Przejscie do FT_HOME (brak safety screen w PRO)

---

## Tryby aktywnej sesji (FT_ACT)

### Breathe

Animowane kolo z glow rings, kolory faz z motywu. Timer fazy, etykieta, arc progresu sesji, numer oddechu.

### Static Apnea

Duzy timer count-up, kolor skalujacy (motyw INHALE → zolty 75% PB → czerwony 90% PB). Arc do PB, `PB M:SS` w kolorze motywu. Wibracje co 30/60s, ostrzezenie przy 75% PB.

### CO2 / O2 Table

Arc fazy, timer sekund, etykieta PREP/BREATHE/HOLD, info o rundzie. Cykl: PREP (3s) → BREATHE → HOLD → BREATHE → ... → COMPLETE.

---

## Haptic feedback

Identyczne wzorce jak w LITE + dodatkowe:
- Start Readiness Check — 70% / 150ms
- Start Readiness apnea — 80% / 200ms
- Factory reset — 80% / 120/80/120ms 2x

---

## Storage — klucze (~61)

### Presety
`lst_md`, `sv_co_mx`, `sv_co_rn`, `sv_co_df`, `sv_o2_mx`, `sv_o2_rn`, `sv_o2_df`, `sv_br_m`, `sv_br_ii`, `sv_br_hi`, `sv_br_ei`, `sv_br_xi`, `sv_br_si`

Presety aktualizowane automatycznie przez `_savePreset()` przy kazdej sesji (obojetnie czy rekomendowana, z planu, czy z manualnej konfiguracji).

### Customize
`usr_thm`, `usr_nm`, `usr_vib`, `usr_sn`

### Apnea
`ap_pb`, `ap_lg0`, `ap_lg1`, `ap_lg2`, `ap_h0`, `ap_h1`, `ap_h2`, `ap_h3`, `ap_h4`

### Plan
`pl_act`, `pl_day`

### Coach / Readiness
`rd_last` (RD_READY=2 / RD_LIGHT=1 / RD_REST=0 / -1 gdy zuzyto)

### Stats podstawowe
`st_brc`, `st_brt`, `st_apc`, `st_coc`, `st_o2c`, `st_tot`

### Stats zaawansowane
`st_suc_co`, `st_fail_co`, `st_suc_o2`, `st_fail_o2`, `st_suc_ap`, `st_fail_ap`, `st_streak`, `st_lastday`, `st_holdt`

### Weekly stats (PRO++ v4)
`wk_s0..7` (sessions per week), `wk_h0..7` (hold seconds per week), `wk_base` (epoch day of bucket 0), `wk_best` (peak weekly sessions ever), `dy_bits` (14-day activity bitmap), `dy_ref` (anchor day of bitmap)

### Sensor Hub (PRO++ v5)
`sn_brad_last` (BPM dropped during last apnea — bradycardia delta), `sn_brad_best` (all-time max bradycardia drop)

Live sensory (HR / Body Battery / Stress / SpO2 / Resting HR) **nie sa persistowane w storage** — czytane na biezaco z `Sensor.getInfo()` / `Activity.getActivityInfo()` / `SensorHistory.*` przy kazdym renderze (rate-limited do ~1Hz).

---

## Motywy kolorow

**10 palet** — 5 identycznych jak LITE + 5 wylacznie PRO. Zmiana w Customize → Theme.

Zasada projektowania: kazda paleta spojnie ciepla LUB zimna — **brak zoltych/zlotych tonow**.

| # | Motyw | INHALE | HOLD IN | EXHALE | HOLD EX | PREP |
|---|-------|--------|---------|--------|---------|------|
| 0 | Ocean | #00BBEE | #00DDAA | #8866EE | #3A88BB | #44AACC |
| 1 | Sunset | #FF7744 | #FF9966 | #CC4466 | #BB4433 | #FF5533 |
| 2 | Forest | #33CC66 | #55CC66 | #55AA44 | #338844 | #44BB88 |
| 3 | Arctic | #88DDFF | #AAEEFF | #6699FF | #88BBDD | #DDEEFF |
| 4 | Neon | #FF00CC | #00FF88 | #CC00FF | #FF0088 | #FF66FF |
| 5 | Midnight | #6677FF | #99AAFF | #3344CC | #4455DD | #BBCCFF |
| 6 | Magma | #FF4422 | #FF6633 | #DD2200 | #CC3311 | #FF8844 |
| 7 | Reef | #00CCAA | #FF8866 | #00AA88 | #00AA88 | #44DDCC |
| 8 | Aurora | #44EE99 | #CC66FF | #22CC77 | #AA44DD | #DDAAFF |
| 9 | Mono | #DDDDDD | #FFFFFF | #888888 | #AAAAAA | #EEEEEE |

Apnea i "More..." uzywaja `_cINH` (kolor INHALE motywu).

---

## Obsluga przyciskow

| Ekran | UP/DN | SELECT | BACK | TAP |
|-------|-------|--------|------|-----|
| HOME | Przewija 0-6 | Instant start / BR quick / CO2 / O2 / AP / Readiness / More | Wyjscie | Area-based (Last / pill row / Readiness / More) |
| MORE | Przewija 0-6 | Otwiera opcje | HOME | Tap na wiersz |
| PLAN | Przewija opcje | Start / Advance / Abandon | MORE | UP/DN |
| READY | — (phases progress automatycznie) | Skip/next phase | HOME | — |
| BCFG | Zmienia pole | Next / Start | Prev / HOME | UP/DN |
| TCFG | Zmienia pole (4 pola) | Next / Start | Prev / HOME | UP/DN |
| ACT (BR/Tbl) | — | Pauza (pauseCnt++) | HOME + track FAIL (+ repeat plan) | Pauza |
| ACT (AP) | — | Stop | HOME | Stop |
| PAU | — | Wznow | HOME + track FAIL | Wznow |
| DONE | — | HOME | HOME | HOME |
| STAT | Zmienia strone | HOME | HOME | Zmienia strone |
| CUST | Zmienia pole (4 lub 5 gdy DBG) | Cycle/Edit/Toggle/**→GTU**/Save | Prev / HOME | Row-based tap |
| NAME | Zmienia znak | Next pozycja | Prev / CUST | UP/DN |
| RST | — | Reset → HOME | MORE | — |
| GTU | — | _genTestUser() → HOME | CUST | — |

---

## Dane techniczne

- **Platforma:** Garmin Connect IQ, Monkey C
- **Typ:** watch-app
- **Nazwa w Store:** Breath Training System
- **ID:** 44886d01-5977-4c0d-9871-2f2e8e80f7ae
- **Stany:** 15
- **Timer UI:** 100ms tick (10 Hz)
- **Storage:** ~66 kluczy (w tym 5 x `ap_h0..4`, 8 x `wk_s/wk_h` weekly, `dy_bits`/`dy_ref` activity bitmap, 8 x sensor: `usr_sn`/`sn_brad_last`/`sn_brad_best`/`sn_brad_hist`/`sn_calm_last`/`sn_calm_avg`/`sn_bb_start`/`sn_hr_drop_avg`)
- **Kompatybilnosc:** 80 zegarkow Garmin
- **Build:** `_PROD/breathtrainingsystem.prg` + `_STORE/breathtrainingsystem.iq`

---

## Ostatnie zmiany (changelog)

### Najnowsze (PRO++ v5.3) — Gen Test User confirmation + Guide / Legenda

**Gen Test User — ekran potwierdzenia (FT_GTU)**: SELECT na "Gen Test User" w Customize nie wywoluje juz `_genTestUser()` bezposrednio. Najpierw pokazuje sie dedykowany ekran ostrzezenia (`FT_GTU`) z komunikatem `"Your real training data will be overwritten!"` — uzytkownik musi jeszcze raz potwierdzic SELECT lub anulowac BACK. Zabezpieczenie przed przypadkowym uruchomieniem na prawdziwym zegarku z wlasna historia treningow.

### Najnowsze (PRO++ v5.3) — Guide / Legenda

**Nowa opcja w More → Guide (FT_HELP)** — scrollowalna legenda wyjasnajaca wszystkie akronimy, symbole i pojecia uzywane w aplikacji. Dziala identycznie jak Training Paths: UP/DN scrolluje, BACK wraca do More.

**65 wpisow w 10 sekcjach**:
- **NAVIGATION** — skroty klawiszowe i gesty (SELECT, BACK, UP/DN, TAP)
- **TRAINING MODES** — BR / CO2 / O2 / AP / READY z krotkim opisem
- **BREATHE CONFIG** — pola konfiguracji (Prep, Breathe, Hold, Rounds, Preset)
- **TRAINING FEEDBACK** — interpretacja feedback po sesji (Good/Build/Rest)
- **STATS PAGES** — co pokazuja poszczegolne strony (TRAINING/PROGRESSION/PHYSIOLOGY/WEEKLY/SENSOR TRENDS)
- **SENSOR HUB** — co oznacza chip HR/delta, jak czytac brady, calm, readiness
- **READINESS CHECK** — fazy RP_BREATHE / RP_APNEA i jak interpretowac wynik
- **TRAINING PLANS** — jak dzialaja plany, co oznacza ETA, Skip/Repeat
- **PRO++ MODELS** — CO2 tolerance / O2 adaptation / Recovery score, pattern flags (PLATEAU/DECLINE/OVERTRAIN)
- **SYMBOLS** — tabela wszystkich symboli uzywanych na ekranach (`^`, `v`, `~`, `!`, `*`, `>`)

**Naglowki sekcji** uzywaja prefixu ASCII `# ` (zamiast Unicode em-dash), co gwarantuje poprawne renderowanie na FONT_XTINY wszystkich zegarków Garmin. Prefix jest stripowany przed wyswietleniem.

**`_drHelp(dc)`** — nowa funkcja renderujaca, wzorowana na `_drPlan`. Scroll indicator (dots) + highlight bar zaznaczaja biezaca pozycje. Naglowki renderowane w innym kolorze niz wpisy.

### Najnowsze (PRO++ v5.2) — UX polish sensors

**Live HR chip przeniesiony do y=18%** — poprzednia pozycja y=42% kolidowala z kulą oddechową (BREATHE) i rингiem (APNEA). Nowa pozycja to top-right safe strip, zawsze wolna na każdym ekranie.

**Format chipu**: uproszczony dot (3px) zamiast 5-primitywowego serca — mniejszy visual footprint. Delta BPM pokazywana **tylko gdy ≥5 BPM** (szum filtrowany). Format: `"72-8"` (HR spada) / `"80+6"` (HR rosnie).

**Sensory w Readiness Check**: `_snDrLive` dodany do `RP_BREATHE` i `RP_APNEA` faz — widac na żywo czy HR faktycznie spada. W fazie wyniku (READY/LIGHT/REST) pojawiaja sie `HR XX  BB XX%` dla obiektywnego potwierdzenia oceny.

**SENSOR TRENDS redesign**: nowy layout eliminuje nakladanie etykiet na dane — kazda sekcja zaczyna sie od centralnie wyrownaneego naglowka na osobnej linii, dane ponizej. Sekcja C (READINESS) ma naglowek i RHR/O2 na tej samej linii y=70%, a 5 kropek centorwane na y=78% — zadne elementy na siebie nie nachodza.

**`_drTrendRow` fix**: strzalka trendu (`^`/`v`) i wartosc (`1:23`, `64`) lazone w jeden right-justified string — poprzednia implementacja z dwoma osobnymi wywolaniami `drawText` przy offsetcie -22px nakladala sie na krotkie wartosci tekstowe.

**PHYSIOLOGY strip**: przeniesiony z y=88% → y=89%, przyciemniony (-40 zamiast -25) aby nie konkurowac wizualnie z linia predykcji PB powyzej.

### Najnowsze (PRO++ v5.1) — Sensor Trends page + right-column UX

**Nowa strona statystyk: SENSOR TRENDS (page 5 / index 4)**

Piata strona FT_STAT (UP/DN/TAP cyklicznie po 5 stronach). Zbiera i wizualizuje dane fizjologiczne zbierane przez Sensor Hub podczas treningow:

- **DIVE REFLEX panel** — 5-slupkowy sparkline ostatnich 5 delta-bradycardii (BPM drop apnea hold) + best/last + trend arrow. Kolor kodem: pelny `_cHLD` = ≥15 BPM (epicki), dim = ≥8 BPM, ciemny = <8.
- **CALM INDEX panel** — dual bar (AVG EMA + LAST) z calm score 0..100 (mierzy jak skutecznie breathwork obniza HR). Etykieta tekstowa: `Excellent calm / Good progress / Building / Keep practicing`. Bar zolty/pomaranczowy gdy ostatnia sesja pogorszona.
- **READINESS panel** — 5 kolorowych kropek BB-at-session-start (green/gold/orange/hollow) + aktualny RHR i SpO2 jako compact chips.

**Nowe storage (5 kluczy)**: `sn_brad_hist` (Array[5]), `sn_calm_last`, `sn_calm_avg`, `sn_bb_start` (Array[5]), `sn_hr_drop_avg`.

**Nowe funkcje**:
- `_snSessionEndBr()` — wywolywana przy koncu sesji BREATHE, liczy calm score (EMA α=0.30) i pushuje BB-at-start.
- `_snPushBbAtStart()` — wspoldzielony helper, wywolywany rowniez z CO2/O2 table endings.
- `_drStatSensor(dc)` — renderuje strone 5 z 3 panelami.

**Naprawiony layout sensorow na HOME**: ekran glowny powrocil do czystego, bez kolumny — sensory widoczne TYLKO w trakcie aktywnych sesji treningowych.

**Naprawiony UI dla round-watchy** (v5.1): zunifikowany right-side chip `_snDrLive(dc, y, calmMode)` na wszystkich aktywnych ekranach (APNEA/BREATHE/TABLE). `calmMode=true` dla fazy oddechowej (prog 5 BPM), `calmMode=false` dla holdu (prog 10 BPM). Kolko APNEA zmniejszone z 36% → 31% promienia dla lepszych proporcji.

**Demo tour**: z 8 → 9 slajdow; nowy slajd 7 = `STATS SENSOR TRENDS` (3.0s).

**Gen Test User**: seeduje teraz `_snBradHist[]`, `_snCalmLast`, `_snCalmAvg`, `_snHrDropAvg`, `_snBbAtStart[]`, `_snHrStart` tak zeby strona SENSOR TRENDS i chipsy live HR renderowaly sie od razu w simulatorze.

### Najnowsze (PRO++ v5) — Sensor Hub

Pelna integracja sensorów Garmina tam, gdzie ma to fizjologiczny sens. Wszystkie wywołania API sa **defensive** (try/catch + capability detection) — na watchach bez danego sensora albo gdy user wylaczy permission, app zachowuje sie identycznie jak v4 (zero badge'ow, zero degradacji UX).

**Nowy plik permissions** — `manifest.xml`: `Sensor` + `SensorHistory`.

**Nowy modul "SensorHub"** w `BreathTrainingSystemView.mc` (~210 linii, sekcja oznaczona `── SENSOR HUB ──`):

- `_snInit()` — czytane z `Application.Storage.usr_sn` (default `true`), wlacza `Sensor.setEnabledSensors([SENSOR_HEARTRATE])`, probuje wszystkich 5 zrodel sensorow i zapisuje wynik w bitmapie `_snAvail` (HR / BodyBattery / Stress / SpO2 / RestingHR).
- `_snReadHrRaw()` — wpierw `Activity.getActivityInfo().currentHeartRate`, fallback do `Sensor.getInfo().heartRate`. Zwraca BPM albo 0.
- `_snReadBodyBatt() / _snReadStress() / _snReadSpo2() / _snReadRestingHr()` — wszystkie przez `SensorHistory.*History()` z `:period => 1`, defensywnie (`has :method` + try/catch).
- `_snTick()` — wywolywane co tick podczas FT_ACT, rate-limited do **~1Hz** zeby nie palilo baterii. Tracking `_snHrCur / _snHrMin / _snHrPeak`.
- `_snSessionStart()` / `_snSessionEndAp()` — snapshot HR baseline na starcie + obliczenie **bradycardia delta** (start − min) na koncu apnea.

**Live HR badges na ekranach treningu**:

- **APNEA active** — `top-left "BPM  -X"` (live HR + delta vs baseline). Gdy delta ≥10 BPM badge zmienia sie na pulsujace **"DIVE  -X"** w kolorze tematu — pozytywne potwierdzenie ze **mammalian dive reflex** zaskoczyl.
- **BREATHE active** — `top-left` z dodatkowym cue **"CALM"** w `_cHLD` gdy HR spadl ≥5 BPM ponizej baseline (potwierdzenie ze breathwork dziala).
- **TABLE active (CO2/O2)** — kompaktowy badge z theme-tinted color (zielony przy bradycardii, salmon przy spike).
- Color logic w `_snBadgeColor()`: bradycardia ≥10 → `_cHLD`; HR climbing ≥15 → `0xFFA060`; default theme dim.

**HOME readiness badge** (top-right, dyskretny):

- BPM number (FONT_XTINY, `_lighten(_cINH,-20)`) + maly Body Battery dot.
- Dot color-coded: ≥60 = `_cHLD` (zielony tematyczny), 30..59 = `_cINH` dim, <30 = pomaranczowy.
- Badge renderowany tylko gdy `_snAnyAvail()` (czyli jakiekolwiek zrodlo sensora dziala).

**FT_DONE — bradycardia readout (apnea)**:

- Po apnea, jesli `_snBradLast > 0`: linia **"HR -X bpm"** ponizej PB info.
- Color tier: ≥15 BPM = `_cHLD` (silna dive response), ≥8 = theme dim, <8 = ledwie zauwazalny dim.
- Sufix **"PB"** gdy ten session pobil dotychczasowy `_snBradBest` (wlasciwie *bradycardia* PB).

**PHYSIOLOGY page (FT_STAT page 3) — sensor strip**:

Nowy footer line `y=92%` z kompaktowymi chipami:
- `RX` — Resting HR (baseline z 24h)
- `BBX` — Body Battery 0..100
- `OX` — SpO2 %
- `▼X` — Best bradycardia delta (BPM dropped)

Strip auto-skipuje chipy dla niedostepnych sensorow → na watchach bez Body Battery (Edge'y, starsze modele) wynik to po prostu `R54  ▼12` zamiast pelnego setu.

**Customize → "Sensors  ON / OFF / N/A"** (nowy 4-ty wiersz):

- Toggle persistowany jako `usr_sn` (default `true`).
- Po przelaczeniu **na ON**: ponowne `Sensor.setEnabledSensors([HR])` + `_snDetectAvailability()`.
- Po przelaczeniu **na OFF**: `Sensor.setEnabledSensors([])` (oszczedza baterie), wszystkie badge'y znikaja.
- Label **"Sensors N/A"** gdy toggle jest ON ale `_snAvail == 0` (zaden sensor nie dziala — np. permission denied, user na vivoactive 2 itd).
- `_custRows()`: 5 → 6 (z DBG `6 → 7`).
- Tap-handler dla rows updated z m34 → m45 boundary.

**Persistent storage (3 nowe klucze)**:
- `usr_sn` — toggle (Boolean)
- `sn_brad_last` — ostatnia bradycardia delta (BPM)
- `sn_brad_best` — all-time best bradycardia delta (BPM)

**Factory Reset**: `_resetAll()` zerouje wszystko sensorowe (oprocz toggle, ktory zostaje ON), re-detect availability po wipe.

**Gen Test User (DBG)**: seeduje pseudolosowe `_snBradLast`, `_snBradBest`, `_snHrCur`, `_snRestHr`, `_snBodyBatt`, `_snStress`, `_snSpo2` + `_snAvail = 0x1F` (pelen suite), zeby PHYSIOLOGY i DONE renderowaly badges nawet w simulatorze.

### PRO++ v4

- **True cold-start na PROGRESSION i PHYSIOLOGY** — fix bug'a gdzie po Factory Reset (lub przy fresh install) strony PROGRESSION/PHYSIOLOGY rysowaly stare/domyslne slupki dopoki nie zrestartowales apki:
  - `_resetAll()` zerouje teraz **takze w pamieci** wszystkie PRO++ scores, V-historie, load-historie, PB prediction, pattern flags, diver profile (wczesniej tylko `clearValues()` na storage, ale RAM trzymal wartosci az do restartu).
  - Defaults w `_loadPhysio()` zmienione z `50/50/60` (CO2/O2/REC) na **`0/0/0`** — fresh install nie pokazuje juz misleadingowego "BALANCED 50-diver" zanim cokolwiek zrobisz.
  - Strony PROGRESSION i PHYSIOLOGY maja teraz **cold-start placeholder** (`"No sessions yet — Train to build your trends"` / `"Physiology data appears here"`) gdy `total sessions == 0`, jak juz to robila WEEKLY.
- **Stats Page 4: WEEKLY** — nowy 4-ty ekran statystyk (UP/DN/TAP cyklicznie po 4 stronach):
  - **8-tygodniowy bar chart** — sessions per week, oldest left → now right; aktualny tydzien color-coded wg trendu (`>=110%` zielony / `<=90%` pomaranczowy / flat theme), starsze tygodnie progresywnie ciemniejsze (depth cue), min skala = 3 sesji/tydz aby pojedynczy slupek nie wygladal absurdalnie.
  - **This-week summary** — `X ses  Ym hold` + delta vs last week (`+25%` / `-12%` / `= last wk` / `first week`).
  - **14-day activity dot strip** — 14 kropek (filled = trening, hollow = brak), "today" lekko pulsuje i jest minimalnie wiekszy.
  - **Footer:** `Best X/wk` + `X/7 days active` (consistency, color-coded).
  - **Render-safe rolling buckets** — `_advanceWeeks()` i `_advanceDayBits()` sa wywolywane przy kazdym renderze, wiec nawet po dlugiej przerwie `[0]` zawsze znaczy "ten tydzien" / "dzisiaj".
- **Persistent storage (6 nowych kluczy):** `wk_s0..7`, `wk_h0..7`, `wk_base`, `wk_best`, `dy_bits`, `dy_ref`. Zerowane przez factory reset, seedowane przez Gen Test User.
- **`_saveSt(mode, dur, holdSec)`** — refaktor sygnatury, zeby weekly tracking dostawal **actual hold seconds** (apnea = full hold, table = sum of hold rounds, breathe = 0), nie inflated total session time.
- **Bumper hooks** w trzech sciezkach (Breathe end, Apnea end, Table end) — `_bumpWeekly(holdSec)` aktualizuje `_wkSes[0]` / `_wkHold[0]` / `_wkBestSes` / bit dla dzisiaj w `_dayBits`.
- **TRAINING STATS footer (page 1)** — dodane `Wk X ses  Y/7d` (current week sessions + 7-day consistency), zeby pierwsza strona miala juz "weekly pulse" bez przelaczania.
- **PROGRESSION footer (page 2)** — rozszerzone z `Xd Ym hold` na `Xd  Y/7  Zm` (streak + 7-day consistency + lifetime hold minutes).
- **Plan ETA** — na ekranie aktywnego planu treningowego (`_drPlan`) pojawia sie szacowany czas do ukonczenia planu (`~X days left`) liczony na podstawie 7-day training rate. Brak jesli za malo danych.
- **Page indicator dots** — z 3 → 4 kropek (`cx - 12 / -4 / +4 / +12`), zmniejszone aby zmiescic.
- **Marketing demo tour** — z 7 → 8 slajdow; nowy slajd 6 = `STATS WEEKLY` (3.5s), pelen flow nadal ~30s.
- **Gen Test User** — dodatkowo seeduje pseudo-losowe `_wkSes[]`, `_wkHold[]`, `_wkBestSes`, `_dayBits` (mixed pattern), zeby strona WEEKLY byla od razu wypelniona realistycznymi danymi.

### Wczesniej (PRO++ v3)

- **8 Training Paths** (bylo 6): dodane **Static PB** (heavy max-effort holds, minimal CO2 chatter) i **Active Recovery** (light week reset, gentle breathwork + sub-max holds, no high CO2). `PL_COUNT = 8`.
- **PROGRESSION (FT_STAT page 2) — pelna przebudowa**: zamiast samego apnea histogramu, **4 mini-trend rzedy** w jednym ekranie:
  - `APNEA` — 5-bar PB-scaled histogram, value w `M:SS`, color tier (≥80%/60–79%/<60% PB).
  - `CO2`   — 5-bar 0..100 score histogram + trend ^/v/-, kolor wg `_physioColor()`.
  - `O2`    — j/w dla `_o2VHist`.
  - `BR`    — j/w dla `_brVHist` (recovery).
  - Stopka: `Xd  Ym hold` (streak + total hold, jak wczesniej).
- **PHYSIOLOGY — fix "------"**: `_drTrendRow()` ma teraz fallback — jesli newest hist slot jest pusty ale `val > 0`, renderuje `val` jako ostatni bar. `_genTestUser()` dodatkowo **seeduje** `_coVHist/_o2VHist/_brVHist`, wiec po Gen Test User wszystkie histogramy maja realistyczne dane (rosnacy trend → najnowszy wynik).
- **Theme-aware kolorystyka** — wyrugowano paskudne mustardy/sraczki:
  - Readiness "READY" wynik: `0x22DD55` (jaskrawa zielen) → **`_cHLD`** (kolor tematu).
  - Readiness "Recommended:" hint: `_lighten(_cINH,-30)` (mustard) → **`_lighten(resC,-25)`** (zalezne od wyniku).
  - REC overlay default: `0xCC9922` (mustard) → **`_lighten(_cHLD,-10)`** (theme).
  - PLAN overlay: `0xFFDD44` (zolty) → **`_lighten(_cHLD,15)`** (theme highlight).
  - Wszystkie `0xFFAA22` (mustard amber) → **`0xFFA060`** (cieplejszy salmon-amber, czytelny na kazdym tle).
  - Niezaznaczony Reset / Cancel: `0x553322` (sraczkowaty bury) → **`0x442222`** (ciemny maroon, parujacy z aktywnym `0xFF6644`).
- **Wskazniki stron (kropki) na FT_STAT** — pomniejszone (r=2 selected, r=1 inactive), przesuniete tightly pod tytul (`y = 21%`), uzywaja `_lighten(_cINH,-75)` zamiast solidnego `0x333333` — nie nakladaja sie juz na content.
- **TRAINING STATS layout** — przeprojektowany na trzy strefy: hero number ("X" + "sessions" + "Yh Zm total" w trzech liniach), per-mode counts (BR/AP, CO2/O2), PB highlight. Brak juz zlepionego "X sessions  Ym".
- **5-elementowa historia trendow** dla CO2/O2/Breathe (`_coVHist`, `_o2VHist`, `_brVHist`) — push przy konczeniu sesji, persystentnie zapisywane (`co_vh0..4`, `o2_vh0..4`, `br_vh0..4`). Trend liczony przez `_hist5Trend()` (newest 0..1 vs older 2..4).

### Wczesniej (PRO++ v2)

- **6 Training Paths** (bylo 3): dodane **O2 Adaptation**, **Breathwork Mastery** (5 presetow), **Endurance Mix**.
- **5 presetow oddechowych** (bylo 3): dodane **Wim Hof Power 2-1** i **Pranayama 4-7-8**. `BR_PRESETS = 5`, custom = index 5.
- **Strona PHYSIOLOGY** (FT_STAT page 3) — przemianowana z "SYSTEM STATUS"; layout z **mini-trend histogramami 5 barow** dla CO2 / O2 / REC obok wartosci i strzalki trendu.
- **Marketing demo tour** — z 5 → 7 slajdow, z **prawdziwymi animacjami treningow** (Breathe live, Apnea live, CO2 Table live), bez labelki "DEMO" na ekranie (tylko dyskretne kropki progresu na dole).
- **Lepsze skalowanie ekranow STATS** — przeprojektowane wszystkie 3 strony, brak nakladajacego sie tekstu, usuniete obowiazkowe hinty `UP/DN switch BACK exit` (i analogiczne z BR_CFG / TBL_CFG / NAME_ED).
- **Lista planow w FT_PLAN** — przeprojektowana na compact list z highlight bar, scroll-indicator po prawej, mieszczaca 6+ pozycji.

### Histogram apnea (nowy)

- **Ekran PROGRESSION (stats str. 2)** — text "recents" zastapiony wizualnym histogramem 5 slupkow.
- **Kolorowanie ostatniego slupka** — najnowszy wynik (skrajny prawy) kolorem tematycznym: `_cHLD` (≥80% PB) / pomaranczowy (60–79%) / czerwony (<60%). Poprzednie slupki: przyciemniony kolor motywu.
- **Ghost PB line** — subtelna pozioma linia na wysokosci 100% PB jako punkt odniesienia.
- **Animacja** — pulsujacy outline ostatniego slupka (co ~0.7s), bez dynamicznych alokacji.
- **Zasada NO-TEXT** — zadnych liczb, etykiet, osi; czyty sygnal wzrokowy.
- **Wydajnosc** — 5 iteracji max, fixed-point integer only, reuse `_apHist[]`.

### Debug: Generate Test User + Marketing Demo Tour

- **Customize → "Gen Test User"** (widoczny tylko gdy `DBG_ENABLED = true` na gorze pliku).
- Generuje 5 wpisow historii apnea, PB, statystyki sesji, streak — wszystko pseudo-losowe (`_tick` jako seed).
- **Dodatkowo seed-uje wszystkie metryki PRO++ physio**: `co_tol_score`, `o2_adapt_score`, `br_rec_score`, trends, `pb_predicted`, `pb_confidence`, diver profile, pattern flags — tak by wszystkie nowe ekrany byly od razu wypelnione realistycznymi danymi.
- **Marketing demo tour (~25s, 7 slajdow z LIVE training)** — po kliknieciu opcja automatycznie odpala auto-tour pokazujacy najwazniejsze ekrany **wlacznie z prawdziwymi animowanymi treningami**:
  1. `HOME` — overlay rekomendacji + intelligence layer (3.0s)
  2. `BREATHE active` — **live** Box 4-4-4-4, pulsujaca kula, phase progress arc (4.5s)
  3. `APNEA active` — **live** static apnea, hold counter, micro-feedback "Stay calm" (3.5s)
  4. `CO2 TABLE active` — **live** mid-session, ring postepu, round indicator (4.0s)
  5. `STATS PROGRESSION` — kolorowany histogram 5 sesji + PB reference line (3.0s)
  6. `STATS PHYSIOLOGY` — pelen physio dashboard z mini-trendami CO2/O2/REC (4.0s)
  7. `HOME` — outro (2.0s)
- **Brak labelki "DEMO"** — same ekrany sa marketingiem, jedyny indykator to dyskretne 7 kropek progresu na dole (highlightuja aktualny slajd theme color, ukonczone slajdy ciemnym kolorem motywu).
- **Live animation podczas slajdow treningowych** — onTick fall-through pozwala normalnym animacjom (oddech, hold counter, ring postepu) faktycznie zyc; sesje sa setupowane z duzymi `_brRem` / `_tTR` zeby nie zakonczyly sie ani nie zapisaly do storage.
- **Anulowanie**: dowolny przycisk (UP/DN/SELECT/BACK) lub TAP natychmiast zatrzymuje demo i wraca na HOME, czyszczac stan.
- Pozwala szybko nagrac/zrobic screenshoty marketingowe bez przechodzenia recznie po ekranach.
- **Ukrycie**: zmien `const DBG_ENABLED = true;` → `false;` (1 linia). Opcja calkowicie znika z UI razem z auto-demo.

### Spójnosc kolorystyczna

- Wszystkie naglowki ekranow (`READINESS CHECK`, `BREATHING`, `CO2 TABLE`, `TRAINING PATH`, `TRAINING STATS`, `COMPLETE`, `DONE!`) uzywaja `_cINH` zamiast hardkodowanego turkusu/zlota.
- Przyciski CTA (`START`, `START NEXT`, Cancel, `SELECT = start`, `SELECT = menu`) uzywaja `_cHLD`.
- Paski postepu planu, trend "up", blink select hints — wszystko theme-driven.
- Pozostaja semantyczne: czerwony = stop/rest/end, pomaranczowy = ostrzezenie/light session.

### UI / UX

- **Customize menu** — przebudowany do identycznego stylu co menu More: prosty list tekstu bez pionowej linii zaznaczenia. Pola: Theme (z 5 kropkami podgladu palety), Name, Vibration ON/OFF, [Gen Test User], SAVE.
- **Nawigacja Customize** — UP/DN przesuwa zaznaczenie, SELECT lub TAP na wiersz wykonuje akcje. BACK → HOME.
- **Vibration ON/OFF** — nowa opcja w Customize, zapisywana jako `usr_vib`.
- **10 motywow kolorow** — LITE ma 5, PRO ma 10 (dodane: Midnight, Magma, Reef, Aurora, Mono).
- **Kolorystyka ujednolicona** — usunieto wszelkie zolte/zlote tony ze wszystkich palet; kazda paleta jest teraz spojnie ciepla lub zimna.
- **Breathe — layout** — kula przesunieta do 57% wysokosci, info-bar i etykieta fazy na 10-20% (strefa bezpieczna na okraglym ekranie), countdown pod kula. Eliminuje nakladanie sie tekstu z animacja.

### Animacje

- **Breathe — kolory faz** — `_brPhColor()` zwraca przyciemniony kolor wydechu dla HOLD-EXHALE i PREP; eliminuje warm-tinting niezaleznie od motywu.
- **Breathe — naturalny odstep miedzy fazami** — `_brTrans = 1` (1 sekunda) po zakonczeniu kazdej fazy; pika zatrzymuje sie w pozycji koncowej, nastepna faza startuje z krótka pauza.
- **Breathe — sekundnik** — cienki phase-progress arc wokol kuli + duza liczba countdown pod piika (`FONT_LARGE` z cieniem).
- **Breathe — ambient glow** — ograniczony do bezposredniego otoczenia piki (nie full-screen), halo max +11px ponad kule.
- **Apnea** — podwodne tlo (12 paskow gradientu), grubszy ring `setPenWidth 3`, timer `FONT_NUMBER_HOT` z cieniem.
- **CO2 / O2** — pill-box z numerem rundy, podwojny ring (dekoracyjny + postep `setPenWidth 4`), etykieta i countdown z cieniami.

---

## Identyfikacja produktu

**LITE (Tool)** → *Instant freediving training tool*. Neutralna terminologia, zero coachingu, deterministic timer.

**PRO (System)** → *Breath Coaching System*. Pelnoprawny system z:
- sciezkami treningowymi (**8 planow x 10 sesji** — Beginner / CO2 / Apnea / O2 / Breathwork / Mix / Static PB / Active Recovery; adaptacyjny advance),
- rekomendacjami sesji (fatigue + confidence + readiness),
- readiness gating (FT_READY),
- training states (RECOVERY/BUILDING/STABLE/PEAK),
- adaptive difficulty (auto-progression max hold),
- 2-line standardized feedback (performance + recommendation, mandatory).

### Reguly architekturalne PRO

- **HOME to launcher LITE + intelligence overlay**. Siedem pozycji identyczne jak LITE (Last / BR / CO2 / O2 / AP / More) plus Readiness check jako dodatkowy slot. Overlay rekomendacji jest pasywny i nigdy nie blokuje.
- **Quick-start zachowany** — `_instantStart()` i `_quickBreathe()` sa w pelni funkcjonalne z HOME, uzywaja saved preset (`_svCoMx/_svCoRn/_svCoDf`, `_svO2Mx/_svO2Rn/_svO2Df`, `_svBr*`) i nie przechodza przez coach pick.
- **Coach intelligence passive-only na HOME**: `_recStart()`, `_recModeAndApply()`, `_planStartCurrent()` pozostaja w kodzie i sa dostepne (plan przez MORE → Training Plan → START NEXT), ale HOME nigdy ich nie wywoluje. `_previewRecommendation()` + `_recOverlay()` dostarczaja wylacznie tekst do wyswietlenia.
- **Readiness opt-in** — SELECT na `hSel = 5` wchodzi w FT_READY; wynik `rd_last` zapisany; po RP_RESULT SELECT wraca do HOME. Readiness moduluje overlay i auto-prezeset difficulty, nigdy nie startuje sesji bez wiedzy uzytkownika.
- **Adaptive difficulty pracuje w tle** — `_progressCheck()` po sesji zmienia preset max hold; nastepny instant-start uzyje nowego. Uzytkownik nie widzi dodatkowych krokow.
- **Mandatory coaching storage**: `rd_last`, `st_suc_*`, `st_fail_*`, `pl_act`/`pl_day`, `st_streak`, `st_lastday`, `ap_h0..4`, `sv_co_df`, `sv_o2_df`.
- **Feedback zawsze 1+1** — performance line + recommendation line (FT_DONE).

Kazdy napis UI w PRO zachowuje spojnosc z identyfikacja *coaching system*: `REC`, `REST ADVISED`, `PLAN D{n}/{len}`, `RECOMMENDED`, `Training State`, `Recommended session`, `TRAINING PATH`, `Adjusted schedule`, `Next session`, `START NEXT`, `End path`, `Recovery recommended`, `Continue progression`, `Rest advised`, `Path continues`, `Build gradually`.

---

# PRO++ — Physiology + AI Layer

System zostal rozszerzony o pelnoprawna **warstwe fizjologiczna** ktora modeluje tolerancje CO2, adaptacje O2, jakosc regeneracji oraz wykrywa wzorce postepow. Wszystko dziala **w tle**, jest **persystentne** i **nieinwazyjne** — nie zmienia istniejacej architektury, nie blokuje uzytkownika, dziala wylacznie jako rekomendacja i sygnal wizualny.

## 1. Modele fizjologiczne

### CO2 Tolerance Model — `_updateCo2Model()`
- **Wejscie:** ilosc ukonczonych rund, liczba pauz, profil trudnosci.
- **Obliczenie:** `load = (rounds * difficultyFactor) - pauses * 6`, normalizowane 0–100.
- **Aktualizacja `co_tol_score`:**
  - `+4` jezeli sesja ukonczona bez pauz
  - `+1` jezeli z 1 pauza
  - `-4` jezeli ≥2 pauzy
  - `+2` jezeli load ≥70% (high-load bonus)
  - clamp 0–100
- **Trend (`co_trend`):** porownanie ostatnich 3 loadow → 1 / 0 / -1.

### O2 Adaptation Model — `_updateO2Model()`
- **Wejscie:** firstHold, lastHold, PB.
- **Obliczenie:** `peak_ratio = (lastHold / PB) * 100`, `progression = lastHold - firstHold`.
- **Aktualizacja `o2_adapt_score`:**
  - `+3` jezeli progression > 0
  - `+4` jezeli peak_ratio > 80
  - `-4` jezeli early collapse (`lastHold * 10 < firstHold * 9`)
  - clamp 0–100
- **Trend (`o2_trend`):** rolling 3-entry on `peak_ratio`.

### Recovery Model — `_updateRecoveryModel()`
- **Wejscie:** dlugosc sesji breathe + delta wynikow nastepnej sesji vs srednia.
- **Logika:**
  - `+4` jezeli nastepna sesja byla lepsza
  - `-4` jezeli gorsza
  - `+2` bonus za sesje >10 min
- **Wyjscie:** `br_recovery_score`, `br_effect_last` (-1/0/1).

## 2. Session Quality Score (0–100)

Kazda sesja konczy wywolaniem `_calcSessionScore(mode, ...)`:
- **Apnea:** `score = hold / PB`, +5 za pacing (smooth growth), -30 jezeli <15s.
- **CO2/O2:** `(roundsDone / totalRounds) - pauses*8`.
- **Breathe:** baseline 40 + `dur/60 * 4` + bonus za `br_effect_last > 0`.
- Zapisywane: `st_score_last` (ostatnia) i `st_score_avg` (EMA: 30% nowa / 70% stara).

## 3. PB Prediction — `_updatePbPrediction()`

Generuje predykcje przyszlego PB:
- jezeli `_apTrend()` ↑ → `pb_predicted = PB * 1.08`
- jezeli plateau → `PB * 1.02`
- jezeli ↓ → `PB * 0.96`
- **Confidence:** `pop_count(_apHist) * 18 + score_avg/5`, clamp 0–100.
- Wyswietlane na **PHYSIOLOGY** (page 3) jezeli confidence ≥35.

## 4. Pattern Detection — `_detectPatterns()`

- **Plateau:** wszystkie 5 wpisow `_apHist` w ±5% sredniej.
- **Decline:** ostatnie 3 sesje strictly decreasing.
- **Overtraining:** streak ≥4 dni AND decline.
- Flagi: `pt_plateau_flag`, `pt_decline_flag`, `pt_overtrain_flag`.
- Surfacowane w `_recOverlay()` (HOME) i `_fbLine1/2()` (FT_DONE).

## 5. Diver Profile — `_updateDiverProfile()`

- `diver_co2 = co_tol_score`
- `diver_o2 = o2_adapt_score`
- `diver_recovery = br_recovery_score`
- Klasyfikacja (`_diverClass()`):
  - `RECOVERY LIMITED` jezeli recovery <40
  - `CO2 DOMINANT` jezeli `co2 > o2 + 15`
  - `O2 LIMITED` jezeli `o2 > co2 + 15`
  - inaczej `BALANCED`
- Wyswietlane na page 3.

## 6. Coach Override (`_applyPhysioOverride()`)

Dodatkowa warstwa decyzji w `_recModeAndApply()` i `_previewRecommendation()`:
- `br_recovery_score < 40` → **FORCE BREATHE** (recovery)
- `co_tol_score < 50` → **PRIORITIZE CO2**
- `o2_adapt_score < 50` → **PRIORITIZE O2**

Override modyfikuje wylacznie **sugestie**, nigdy nie blokuje quick-startu uzytkownika z HOME.

## 7. HOME overlay (`_recOverlay()`) — physio-aware

Nowe komunikaty (priority order):
- `OVERTRAINING RISK`
- `PLATEAU DETECTED`
- `REC BREATHE RECOVERY`
- `REST ADVISED`
- `REC CO2 LOW TOL`
- `REC O2 ADAPT LOW`
- standard `REC ...` jako fallback

## 8. FT_DONE feedback — context-aware

`_fbLine1()` i `_fbLine2()` rozszerzone o kontekst fizjologiczny:

| Mode | Linie |
|------|-------|
| **Apnea** | "Peak performance" / "Plateau detected" / "Potential unlocked" / "Strong session" / "Light session" / "Stable session" + Pred PB jezeli confidence ≥50 |
| **Breathe** | "Recovery effective" / "Recovery insufficient" / "Recovery session" + "Rest advised" jezeli rec_score <40 |
| **CO2** | "Tolerance improving" (trend↑) / "High CO2 load" (load≥70) / "High load session" / "Strong progression" / "Stable session" |
| **O2** | "Adaptation building" (trend↑) / "Hypoxia stress high" (peak≥90) / "High load session" / "Strong progression" / "Stable session" |

Linia 2 zawsze sugeruje akcje: `Recovery recommended`, `Reduce intensity`, `Build gradually`, `Rest advised`, `Continue progression`.

## 9. PHYSIOLOGY (FT_STAT page 3)

Trzecia strona statystyk (UP/DN/TAP cykluje 3 strony, kropki indykator).
Wczesniej "SYSTEM STATUS" — nazwa zmieniona, bo to **uzytkownika** dashboard
fizjologiczny, nie status systemu.

Layout (3 zwarte wiersze + footer):
- `CO2  ███▒░ ^ 72`
- `O2   ███░░ ^ 62`
- `REC  █░░░░ v 45`

Kazdy wiersz:
- **Label** (lewo) — `CO2` / `O2` / `REC`
- **Mini-histogram 5 barow** (srodek) — historia ostatnich 5 sesji danej metryki:
  - oldest po lewej, newest po prawej
  - tylko **najnowszy bar** koloruje sie wg progow (czerwony <40, zolty <65, zielony ≥65)
  - starsze bary sa neutralne dim (theme grey) — eye instantly trafia w aktualny stan
- **Trend arrow + value** (prawo) — `^/v/-` w kolorze, liczbowy score 0–100

Footer:
- Klasa divera (`BALANCED` / `CO2 DOMINANT` / `O2 LIMITED` / `RECOVERY LIMITED`)
- Wzajemnie wykluczajaca sie flaga (priorytet od najwyzszego):
  `OVERTRAIN` (red) / `DECLINE` (yellow) / `PLATEAU` (grey) / `PB <pred> <delta>` jezeli confidence ≥35

Bar wartosci dla mini-histogramu pochodza z osobnych 5-elementowych buforow:
- `_coVHist[5]` — push przy konczeniu sesji CO2 (`_updateCo2Model()`)
- `_o2VHist[5]` — push przy konczeniu sesji O2 (`_updateO2Model()`)
- `_brVHist[5]` — push przy konczeniu sesji Breathe (`_updateRecoveryModel()`)
Persystentnie zapisywane do storage (`co_vh0..4`, `o2_vh0..4`, `br_vh0..4`).

## 10. Micro-feedback w Apnea (FT_ACT)

Krotkie podpowiedzi pod glowna tarcza, **bez spamu** — kazdy komunikat tylko w waskim oknie czasowym:
- `50–58% PB` → `Relax`
- `75–82% PB` → `Stay calm`
- `>prevAvg && 35–50% PB` → `Too fast`

Dodatkowo **wibracje haptyczne** (`_mfFlags` bitmask) raz na sesje przy przekroczeniu 50% i 75% PB — jednorazowe latche.

## 11. Storage — nowe klucze (PRO++)

| Klucz | Typ | Opis |
|-------|-----|------|
| `co_tol_score` | 0–100 | CO2 tolerance |
| `co_last_load` | 0–100 | Load ostatniej sesji CO2 |
| `co_trend` | -1/0/1 | Trend CO2 |
| `co_lh0..2` | int | Historia loadow CO2 (3) |
| `o2_adapt_score` | 0–100 | O2 adaptation |
| `o2_peak_ratio` | 0–100 | Peak ratio ostatniej sesji O2 |
| `o2_trend` | -1/0/1 | Trend O2 |
| `o2_lh0..2` | int | Historia peak ratio O2 (3) |
| `br_rec_score` | 0–100 | Recovery |
| `br_effect_last` | -1/0/1 | Efekt ostatniej breathe |
| `st_score_last` | 0–100 | Session score |
| `st_score_avg` | 0–100 | EMA score |
| `pb_predicted` | sec | Przewidywane PB |
| `pb_confidence` | 0–100 | Pewnosc predykcji |
| `diver_co2` | 0–100 | Profil CO2 |
| `diver_o2` | 0–100 | Profil O2 |
| `diver_rec` | 0–100 | Profil Recovery |
| `pt_plateau` | bool | Flaga plateau |
| `pt_decline` | bool | Flaga decline |
| `pt_overtrain` | bool | Flaga overtraining |

Razem ~62 klucze persystentne (dotychczasowe ~42 + 20 nowych).

## 12. Performance + architektura

**Rygorystyczne wymagania zachowane:**
- brak dynamicznych alokacji w hot-pathie (statyczne `_coLoadHist[3]`, `_o2LoadHist[3]`)
- petle ≤5 iteracji
- liczby calkowite preferowane (zaden `Float` w obliczeniach, tylko skalowane integery)
- Storage write tylko **na koniec sesji** (nigdy w `onTick()`)
- brak zmian nawigacji HOME / quick-start
- brak nowego stanu UI (page 3 to wariant istniejacego `FT_STAT`)
- rezerwacja nowego API: `_loadPhysio()`, `_clamp()`, `_trend3()`, `_pushLoad()`, `_calcSessionScore()`, `_updatePbPrediction()`, `_detectPatterns()`, `_updateDiverProfile()`, `_diverClass()`, `_physioSessionEnd()`, `_endBrPhysio()`, `_applyPhysioOverride()`, `_drSysRow()`, `_apMicroFeedback()`

## 13. Cel projektowy PRO++

System ma **czuc sie inaczej niz timer**:
- *czyta* fizjologie uzytkownika
- *przewiduje* przyszle PB
- *adaptuje* sie cicho — bez okienek, bez przyciskow, bez konfiguracji
- *kieruje* przez sygnaly wizualne i lekkie sugestie

To nie kolejny coach — to **samouczacy sie system treningowy** wbudowany w zegarek.
