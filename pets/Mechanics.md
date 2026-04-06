# Garmagochi - Mechanika Gry

## Spis treści
1. [Staty](#staty)
2. [Cykl życia](#cykl-życia)
3. [Akcje gracza](#akcje-gracza)
4. [System nastrojów](#system-nastrojów)
5. [System śmierci](#system-śmierci)
6. [System chorób](#system-chorób)
7. [Hug Stress (stres przytulania)](#hug-stress)
8. [System kar i nagród](#system-kar-i-nagród)
9. [Dylematy moralne](#dylematy-moralne)
10. [Cechy charakteru](#cechy-charakteru)
11. [Stworki](#stworki)
12. [Mini-gry](#mini-gry)
13. [Tryb nocny](#tryb-nocny)
14. [Seria opieki (Care Streak)](#seria-opieki)
15. [Starzenie się](#starzenie-się)
16. [Tryb Debug](#tryb-debug)
17. [Zaniedbanie](#zaniedbanie)
18. [Kupki](#kupki)
19. [Przekarmienie](#przekarmienie)

---

## Staty

Stworek ma 4 główne staty (0-100):

| Stat | Opis | Efekt przy niskim | Efekt przy wysokim |
|------|------|-------------------|-------------------|
| **Hunger** | Głód (0=najedzony, 100=głodny) | Najedzony, ryzyko przekarmienia | Umiera z głodu |
| **Happiness** | Szczęście | Depresja, rage, śmierć z samotności | Miłość, impreza, sugar high |
| **Energy** | Energia | Nie może się bawić, feral mode | Hiperaktywność |
| **Health** | Zdrowie | Śmierć gdy = 0 | Pełnia zdrowia |

### Tempo spadku statów
Każdy stworek ma inne tempo zmian statów (rate). Im niższy rate = tym szybciej stat się zmienia.
- Bazowy hunger rate: **600** game-seconds na +1 głód
- Bazowy happiness rate: **300** na -1 szczęście
- Bazowy energy rate: **480** na -1 energię
- Modyfikowane przez: typ stworka, cechy, chorobę, zaniedbanie, tryb nocny, wiek

---

## Cykl życia

### Tworzenie
1. Gracz wybiera typ stworka
2. Gracz wybiera imię (domyślne = nazwa typu, np. "Flamey")
3. Losowane są 2 cechy charakteru (nie mogą być sprzeczne)
4. Staty startowe: hunger=20, happiness=80, energy=80, health=100

### Narodziny
- `_birthTime` = moment stworzenia
- Każde 7 dni = urodziny (+30 happiness, celebracja)

### Śmierć
Patrz sekcja [System śmierci](#system-śmierci)

---

## Akcje gracza

| Akcja | Efekt | Szczegóły |
|-------|-------|-----------|
| **Feed** | Zmniejsza głód | -30 hunger (glutton: -40, picky: -20), +5-15 happiness |
| **Play** | Losowa mini-gra | 5 mini-gier, wynik wpływa na happiness i energy |
| **Clean** | Usuwa kupki | -1 poop, +5 happiness, -5 energy |
| **Heal** | Leczy chorobę | Leczy jeśli chory, +20 health, -10 energy |
| **Nap** | Drzemka | +30 energy, -10 hunger, blokuje akcje na chwilę |
| **Hug** | Przytula stworka | Efekt zależy od typu, cech i hugStress |
| **Punish** | Karze stworka | Losowy wynik od "nauczka" po "trauma"/śmierć |
| **Reset** | Reset gry | Pytanie "Are you sure?", kasuje stworka |
| **Debug** | Tryb debug | Przyspiesza czas x300 |
| **+3h Age** | Dodaje 3h wieku | Przesuwa birthTime do testów starzenia |

---

## System nastrojów

7 ekstremalnych nastrojów + calm (domyślny):

| Nastrój | Trigger (ogólny) | Efekt wizualny |
|---------|-----------------|----------------|
| **:rage** | hunger>90, happiness<15 | Czerwone tło, wściekła twarz |
| **:feral** | hunger>95, energy<10 | Dziki wyraz, szybkie ruchy |
| **:love** | happiness>95, hunger<20, health>80 | Serduszka, różowe tło |
| **:sugar_high** | happiness>80, energy>90 | Pulsujące kolory, szybkie animacje |
| **:existential** | happiness<10, energy<20 | Ciemne tło, smutna twarz |
| **:paranoid** | health<30, isSick | Drżenie, rozglądanie się |
| **:party** | happiness>85, energy>70 | Kolorowe tło, taniec |

Każdy typ stworka ma INNE progi nastrojów. Np:
- **Chikko**: paranoid już przy happiness<30 (neurotyk)
- **Vexor**: rage przy happiness<40 (łatwo się wścieka)
- **Donut**: sugar_high przy happiness>60 (uwielbia cukier)
- **Cactuso**: prawie nigdy nic (stoik, tylko existential przy <10)

### Autonomiczne akcje nastrojowe
W każdym nastroju stworek może sam wykonać akcję (co ~900 game-sec, debug: ~120):
- Np. Polacco w rage: "*rzuca pilotem*" (+5 happiness, -5 energy)
- Np. Donut w sugar_high: "*sprinkle explosion!*" (+15 happiness, -10 energy)

---

## System śmierci

Śmierć jest **niedeterministyczna** — nie ma ustalonego momentu zgonu.

### Natychmiastowa śmierć (deterministic)
- `health <= 0` → śmierć
- `hunger >= 100 && happiness <= 0 && energy <= 0` → śmierć z głodu

### Probabilistyczna śmierć
Przy każdym `update()` obliczana jest szansa na śmierć (`deathChance / 1000`):

**Czynniki zwiększające szansę:**
- Wiek > 21 dni (dorosły): +(`days-21`)/3
- Wiek > 30 dni (staruszek): +5 + (`days-30`)*2
- Niskie wellbeing (<40 elder, <25 adult): +8 do +20
- Choroba: +10 (adult), +20 (elder)
- Zaniedbanie >=3 (elder): +10
- Samotność (happiness<=3, neglect>=4): +15
- Wysoki hugStress (>=90): +12
- Cecha FRAGILE: +5

**Czynniki zmniejszające szansę:**
- careStreak >= 7: -5
- careStreak >= 14: -8
- Cecha HARDY: -5

### Przyczyny śmierci
Na podstawie stanu w momencie śmierci:
- **Loneliness**: happiness<=5 i neglect>=3
- **Heartbreak**: hugStress>=80
- **Sickness**: chory i health<40
- **Neglect**: wellbeing<20
- **Old age**: domyślna przyczyna

---

## System chorób

### Zachorowanie
Sprawdzane co 1800 game-sec (debug: 300). Bazowa szansa: 10%.
- hunger>70: +15%
- happiness<30: +10%
- energy<20: +10%
- poopCount>3: +20%
- HARDY: szansa/3
- FRAGILE: +25%

### Efekt choroby
- Health spada o 1 co update
- Jeśli chory > 6h bez leczenia → health = 0 → śmierć

### Naturalne wyzdrowienie
Sprawdzane razem z chorobą. Warunki: chory < 2h, health >= 60.
- Bazowa szansa: 12%
- HARDY: 35%
- FRAGILE: 3%
- Baby: +10%
- Elder: -5%

---

## Hug Stress

Każdy hug dodaje stres. Poziom stresu determinuje reakcję:

| hugStress | Efekt |
|-----------|-------|
| < 55 | Normalna reakcja (roll-based) |
| 55-74 | Ostrzeżenie, +3 happiness |
| 75-94 | Poważne skutki: -20 happiness, -15 health, -15 energy |
| 95+ | LETALNE: -40 happiness, -35 health, -30 energy, choroba, możliwa śmierć |

### Tempo stresu per typ stworka
- **Cactuso**: +50 (najgorszy — kolce!)
- **Vexor**: +40
- **Dzikko**: +38
- **Rocky**: +35
- **Polacco**: +25
- **Batsy**: +22
- **Chikko**: +20
- **Pixelbot**: +20
- **Nosacz**: +18
- **Nugget**: +15
- **Foczka**: -3 (lubi przytulasy)
- **Donut**: -5 (miękki, uwielbia)
- **Rainbow**: -8 (czysty uścisk)
- **Emilka**: -10 (najbardziej kochliwa)

### Regeneracja hugStress
- Spada o 1 co 900 game-seconds
- Offline: spada o elapsed/1800

---

## System kar i nagród

### Punish (karanie)
Losowy roll (0-9) modyfikowany przez:
- Typ stworka (np. Vexor +5, Donut -4)
- Cechy (HARDY +1, FRAGILE -2)
- Zdrowie (<30: -1, <15: -2)
- Nastrój (love: -3, rage/feral: -1)

| Roll | Wynik | Efekt |
|------|-------|-------|
| >=8 | **Breakthrough** | +20 happiness, +10 health |
| >=5 | **OK** | -5 happiness, -3 health |
| >=2 | **Bad** | -15 happiness, -10 health, -5 energy |
| >=0 | **Trauma** | -25 happiness, -20 health, -15 energy, choroba |
| <0 | **Devastating** | -40 happiness, -30 health, -25 energy, choroba, możliwa śmierć |

### Hug (przytulanie)
Losowy roll (0-9) modyfikowany jak punish, ale inne wagi.

| Roll | Wynik | Efekt |
|------|-------|-------|
| >=9 | **Ecstasy** | +30 happiness, +15 energy, +5 health, celebracja |
| >=6 | **Love** | +20 happiness, +10 energy, celebracja |
| >=3 | **OK** | +10 happiness, +5 energy |
| >=0 | **Cold** | +3 happiness |
| <0 | **Reject** | -10 happiness, -5 energy |

---

## Dylematy moralne

Pojawiają się losowo gdy stworek jest w ekstremalnym nastroju.
Gracz musi wybrać: **Hug** czy **Punish**.

Konsekwencje zależą od nastroju:
- W **rage**: hug może uspokoić LUB zdenerwować bardziej
- W **love**: punish może złamać serce LUB "uziemić"
- Każdy nastrój ma 4 warianty scenariuszy z różnymi efektami

---

## Cechy charakteru

Każdy stworek ma 2 losowe cechy (nie mogą być sprzeczne):

| Cecha | Efekt |
|-------|-------|
| **GLUTTON** | Szybszy głód (rate 400 vs 600), jada więcej |
| **PICKY** | Wolniejszy głód, ale mniejsze porcje |
| **PLAYFUL** | Wolniejszy spadek happiness (420 vs 300), bonus z gry |
| **LAZY** | Wolniejszy spadek energii (320 vs 480) |
| **HARDY** | Odporniejszy na choroby (/3), regeneruje health |
| **FRAGILE** | Łatwiej choruje (+25%), gorsze wyniki punisha |
| **CHEERFUL** | Wolniejszy spadek happiness (380), bonus z karmienia |
| **GRUMPY** | Szybszy spadek happiness (210), gorszy w hugach |
| **HYPER** | Bonus z zabawy, ale szybszy spadek energii |
| **SLEEPY** | Szybszy spadek energii (380) |

### Sprzeczne cechy (nie mogą współistnieć):
- GLUTTON ↔ PICKY
- HARDY ↔ FRAGILE
- HYPER ↔ SLEEPY
- PLAYFUL ↔ LAZY
- CHEERFUL ↔ GRUMPY

---

## Stworki (22 typy)

| Typ | Opis | Unikalna cecha |
|-----|------|---------------|
| **Blobby** | Bezkształtna masa | Existential crisis, absorpcja |
| **Flamey** | Ognisty duszek | Szybki hunger, wolne happiness |
| **Aqua** | Wodna kropla | Wolny hunger, lubi hugi |
| **Rocky** | Kamienna głowa | Bardzo wolny hunger, nieczuły na hugi |
| **Ghosty** | Duszek | Wolny hunger, paranoid łatwo |
| **Sparky** | Iskra elektryczna | Szybki energy drain, sugar_high łatwo |
| **Frosty** | Lodowy kryształ | Slow happiness, rage gdy głodny |
| **Shroomy** | Grzybek | Losowe modyfikatory, quirky |
| **Emilka** | Blondynka z emocjami | ULTRA kochliwa, hugStress -10, zazdrosna |
| **Vexor** | Demon | Odwrócona mechanika — lubi karanie, nienawidzi hugów |
| **Chikko** | Neurotyczny kurczak | Paranoid przy happiness<30, łatwy do złamania |
| **Dzikko** | Dziki dzik | Respektuje siłę (punish +4), nienawidzi hugów |
| **Polacco** | Polski Janusz | Mówi po polsku, wulgarny, leniwy, impreza = grill |
| **Nosacz** | Małpa nosacz | Dumny z nosa, dramatyczny, judgmental |
| **Donut** | Pączek | Sugar-obsessed, hugStress -5, boi się być zjedzonym |
| **Cactuso** | Kaktus | hugStress +50 (!), stoik, ultra low maintenance |
| **Pixelbot** | Robot | Logiczny, "ERROR: EMOTION NOT FOUND" |
| **Octavio** | Ośmiornica | 8 ramion chaosu, szybki energy drain |
| **Batsy** | Nietoperz | Nocny marek, paranoid w dzień |
| **Nugget** | Nuggets | Egzystencjalny kryzys, boi się ketchupu |
| **Foczka** | Słodka foczka | Kocha przytulasy (hugStress -3), *arf arf!* |
| **Rainbow** | Tęczowy slodziaczek | Czysta radość, hugStress -8, sparkle |

---

## Mini-gry (5)

1. **CatchGame** — Łap spadające przedmioty przyciskami
2. **RushGame** — Wciśnij przycisk jak najszybciej po sygnale
3. **ReactGame** — Reaguj na zmieniające się kolory
4. **DodgeGame** — Unikaj spadających przeszkód (poruszanie lewo/prawo)
5. **MemoryGame** — Zapamiętaj sekwencję kierunków (Simon Says)

### Wyniki
| Wynik gry | playResult | Efekt |
|-----------|-----------|-------|
| Słaby | 0 | +10 happiness, -5 energy |
| OK | 1 | +20 happiness, -10 energy |
| Dobry | 2 | +30 happiness, -12 energy |
| Perfekcyjny | 3 | +40 happiness, -15 energy |

---

## Tryb nocny

Aktywny 23:00 — 7:00 (wg zegarka).

Efekty:
- Hunger rate × 3/2 (wolniejszy głód)
- Happiness rate × 3/2 (wolniejszy spadek)
- Energy rate × 3/2 (wolniejszy spadek)
- Specjalne "śpiące" myśli

---

## Seria opieki (Care Streak)

Zliczana gdy gracz wchodzi w interakcję codziennie (bez przerwy).

| Streak | Bonus |
|--------|-------|
| 3 dni | +10 happiness, celebracja mała |
| 7 dni | +15 happiness, +10 energy, celebracja duża |
| 14 dni | +20 happiness, +15 energy, +10 health |
| 30 dni | +30 happiness, +20 energy, +20 health, -20 hunger |

Jeśli dzień zostanie pominięty → streak resetuje się do 1.
Wysoki streak zmniejsza szansę na śmierć ze starości.

---

## Starzenie się

| Etap | Wiek | Efekt |
|------|------|-------|
| **Baby** | < 1 dzień | Hunger × 7/10, happiness × 3/2 |
| **Young** | 1-7 dni | Brak modyfikatorów |
| **Adult** | 7-30 dni | Brak modyfikatorów, po 21 dniach szansa na śmierć |
| **Elder** | > 30 dni | Energy × 4/5, rosnąca szansa na śmierć |

Etap wyświetlany jest w nazwie: "Baby Flamey", "Elder Emilka".

---

## Tryb Debug

Aktywowany przyciskiem "Debug" w action bar.

Efekty:
- Czas gry × 300 (5 minut realnych = 25h gry)
- Interwały zdarzeń: 300 vs 1800 game-sec
- Interwały myśli: 15 vs 90 game-sec
- Szybsze czyszczenie akcji/eventów: 2 vs 3-4 sec
- Szansa na dylemat: 1/10 vs 1/120

### +3h Age
Osobna akcja — przesuwa `_birthTime` o 3 godziny w przeszłość.
Pozwala szybko testować etapy starzenia bez czekania.

---

## Zaniedbanie

Mierzone czasem od ostatniej interakcji (`lastInteraction`):

| Czas | Poziom | Efekt |
|------|--------|-------|
| < 30 min | 0 | Brak |
| 30-60 min | 1 | Happiness rate × 4/5 |
| 1-2h | 2 | Hunger × 4/5, Happiness × 2/3 |
| 2-4h | 3 | Hunger × 3/5, Happiness × 1/2, Energy × 3/5 |
| > 4h | 4 | Hunger × 1/2, Happiness × 1/3, Energy × 1/2 |

Poziom zaniedbania 4 + happiness<=3 → +15% szansa na śmierć z samotności.

### Powrót gracza
Po powrocie po długiej nieobecności:
- > 4h: "YOU'RE BACK!!!" (+30 happiness)
- > 2h: "Missed you SO much!" (+20)
- > 1h: "Yay, you're here!" (+10)
- > 30min: "Hi again!" (+5)

---

## Kupki

- Generowane co 7200 game-seconds (2h gry)
- Max 5 kupek
- Gdy > 2 kupki: happiness spada szybciej (-1 per update)
- Gdy > 3 kupki: zwiększona szansa na chorobę (+20%)
- Akcja "Clean" usuwa 1 kupkę

---

## Przekarmienie

### Stuffed (lekko)
Jeśli hunger < 5 po karmieniu:
- -10 happiness, -10 energy
- +1 poop
- Ostrzeżenie wibracyjne

### Overfed (poważne)
Jeśli hunger < 10 PRZED karmieniem:
- Hunger reset do 15
- -25 happiness, -10 health, -15 energy
- +2 poop
- 33% szansa na chorobę
- Silna wibracja
- Unikalne teksty per typ (np. Polacco: "KURWA! za duzo!")

---

## Wibracje

| Poziom | Sytuacja |
|--------|----------|
| 1 | Karmienie, hug ok, clean |
| 2 | Celebracja, dobry hug, powrót |
| 3 | Punish, choroba, hug severe |
| 4 | Śmierć, hug lethal |

---

## Persistence (zapis)

Cały stan gry zapisywany przez `Application.Storage`:
- Wszystkie staty, typ, imię, cechy
- `_birthTime`, `lastInteraction`
- `hugStress`, `careStreak`, `_lastCareDay`
- `debugMode`, `paletteIdx`, `accessory`
- `dilemmaType`, `dilemmaText`

Zapis automatyczny:
- Co ~60 game-seconds w update()
- Przy wyjściu z aplikacji (`onStop`)
- Przy śmierci stworka
