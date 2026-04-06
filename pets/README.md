# Garmagochi

A pixel-art virtual pet (Tamagotchi-style) application for Garmin smartwatches, built with the Connect IQ SDK in Monkey C.

Raise, feed, play with, and care for your pixel creature — directly on your wrist. 22 unique pet types, extreme mood system, 5 mini-games, moral dilemmas, non-deterministic death, and an absurd sense of humor.

---

## Features

### 22 Unique Pet Types

Each creature has a distinct body shape (12x12 pixel art), 4-color palette, personality profile, stat modifiers, mood tendencies, and unique dialogue.

| Type | Element | Personality | Special Trait |
|------|---------|-------------|---------------|
| **Blobby** | Amorphous | Existential philosopher | Existential crisis specialist |
| **Flamey** | Fire | Short-tempered pyromaniac | Fast hunger, easy rage |
| **Aqua** | Water | Calm romantic | Slow hunger, likes hugs |
| **Rocky** | Earth | Stoic tank | Very slow hunger, hates hugs |
| **Ghosty** | Spirit | Paranoid haunter | Easy paranoid, phases through walls |
| **Sparky** | Electric | Hyperactive spark | Fast energy drain, sugar high |
| **Frosty** | Ice | Cold-hearted romantic | Slow happiness drain, ice rage |
| **Shroomy** | Fungus | Psychedelic philosopher | Volatile stats, random fluctuations |
| **Emilka** | Human | Sensitive, loving & jealous | hugStress -10 (loves hugs!), fastest happiness decay |
| **Vexor** | Demon | Pure evil | INVERTED mechanics — loves punish, hates hugs |
| **Chikko** | Chicken | Neurotic panicker | Paranoid at happiness<30, ultra fragile |
| **Dzikko** | Boar | Unhinged brute | Respects force (punish +4), charges walls |
| **Polacco** | Human | Polski Janusz | Speaks Polish (vulgar!), loves grill & beer |
| **Nosacz** | Monkey | Proud nose king | Dramatic, always judging, nose-based reactions |
| **Donut** | Food | Sweet & terrified | hugStress -5, TERRIFIED of being eaten |
| **Cactuso** | Plant | Stoic prickler | hugStress +50 (SPIKES!), ultra low maintenance |
| **Pixelbot** | Robot | Logic over feels | "ERROR: EMOTION NOT FOUND", speaks in data |
| **Octavio** | Octopus | 8 arms of chaos | Hyperactive, ink squirts, does 8 things at once |
| **Batsy** | Bat | Nocturnal weirdo | Paranoid in daylight, party at night |
| **Nugget** | Food | Existential snack | Permanent crisis, afraid of ketchup |
| **Foczka** | Seal | Adorable flopper | hugStress -3, *arf arf!*, loves belly rubs |
| **Rainbow** | Light | Pure sparkle joy | hugStress -8, glitter explosions, double rainbow |

### Personality System

1. **Species** — fixed behavioral profile per pet type (stat rates, mood thresholds, unique actions/thoughts)
2. **Traits** — 2 random traits from 10 possibilities (incompatible pairs excluded)
3. **Dynamic Mood** — 7 extreme emotional states triggered by stat combinations

### 10 Character Traits

| Trait | Effect |
|-------|--------|
| **Glutton** | Hungers faster (rate 400), eats more |
| **Picky** | Feeding less effective, but gets more joy from food |
| **Playful** | Happiness decays slower (rate 420) |
| **Lazy** | Energy drops slower (rate 320) |
| **Hardy** | Resists sickness (/3 chance), passive health regen |
| **Fragile** | Gets sick easily (+25%), worse punish outcomes |
| **Cheerful** | Happiness decays slower (rate 380), bonus joy |
| **Grumpy** | Happiness decays faster (rate 210), worse hugs |
| **Hyper** | Bonus from play, faster energy drain |
| **Sleepy** | Energy drops faster (rate 380) |

Incompatible pairs: Glutton↔Picky, Hardy↔Fragile, Hyper↔Sleepy, Playful↔Lazy, Cheerful↔Grumpy.

### 7 Extreme Mood States

| Mood | Trigger | Behavior |
|------|---------|----------|
| **Rage** | High hunger + low happiness | Violent shaking, red background, "I'LL EAT THE WATCH!" |
| **Love** | Very high happiness + low hunger + high health | Hearts everywhere, "MARRY ME!" |
| **Sugar High** | High happiness + high energy | Rainbow explosions, "THE PIXELS ARE ALIVE!" |
| **Existential** | Very low happiness + low energy | Sits still, "Are we just pixels?" |
| **Paranoid** | Low health + sick | Nervous jitter, "THEY'RE WATCHING!" |
| **Feral** | Extreme hunger + very low energy | Wild eyes, "HUNT. EAT. SLEEP." |
| **Party** | High happiness + high energy | Musical notes, "EVERYBODY DANCE!" |

Each pet type has unique mood thresholds and type-specific thoughts/actions per mood.

### Non-Deterministic Death System

Death is **never guaranteed at a fixed time**. The system uses probabilistic checks:

- **Immediate death**: health=0, or all stats bottomed out
- **Age-based chance**: grows after day 21 (adult), accelerates after day 30 (elder)
- **Treatment quality**: bad wellbeing increases chance significantly
- **Loneliness**: high neglect + low happiness can cause death from loneliness
- **Heartbreak**: excessive hug stress (90+) risks heart failure
- **Sickness**: untreated illness with low health
- **Protection**: high care streak and Hardy trait reduce death chance

Death causes are displayed: "died of loneliness", "heart broke", "passed peacefully", etc.

### Hug Stress System

Every hug adds stress. Each pet type has a different tolerance:
- **Cactuso**: +50 per hug (SPIKES! lethal fast)
- **Vexor**: +40 (demon doesn't like touch)
- **Emilka**: -10 (LOVES hugs, heals from them)
- **Rainbow**: -8 (pure love absorber)

At hugStress 95+: massive stat damage, sickness, possible death.

### Moral Dilemma System

During extreme moods, forced moral choices appear — **Hug or Punish?** No correct answer. Outcomes are probabilistic and depend on the situation. Normal actions blocked until you decide.

### 5 Mini-Games

| Game | Type | How to Play |
|------|------|-------------|
| **Catch!** | Timing | Press SELECT when bar is in green zone (3 rounds) |
| **Rush!** | Speed | Mash SELECT as fast as possible for 5 seconds |
| **React!** | Reaction | Press SELECT when "NOW!" appears (3 rounds) |
| **Dodge!** | Avoidance | Move left/right to dodge falling obstacles |
| **Memory!** | Pattern | Repeat shown sequence of directions (Simon Says) |

### Additional Features

- **On-screen clock** — always visible (12h/24h from device settings)
- **Step counter** — daily steps with pet commentary
- **Birthdays** — every 7 days, celebration and happiness boost
- **Night mode** — 23:00-7:00: slower stat decay, sleeping thoughts
- **Care streak** — daily interaction rewards (bonuses at 3, 7, 14, 30 days)
- **Aging stages** — Baby (<1d), Young (1-7d), Adult (7-30d), Elder (30d+)
- **Overfed mechanics** — feeding when not hungry causes vomiting and sickness
- **Autonomous actions** — pet acts on its own based on mood
- **Haptic feedback** — 4 vibration patterns for different events
- **Debug mode** — 300x time acceleration + "+3h Age" button for testing
- **Auto-save** — state persisted on exit and periodically

---

## Project Structure

```
garmin/
├── manifest.xml              # Connect IQ app metadata
├── monkey.jungle             # Build configuration
├── Mechanics.md              # Full game mechanics documentation (Polish)
├── developer_key.pem/.der    # Signing keys
├── resources/
│   ├── strings.xml           # App name
│   ├── drawables.xml         # Launcher icon reference
│   └── launcher_icon.png     # App icon
├── source/
│   ├── GarmagochiApp.mc      # App entry point, lifecycle
│   ├── Pet.mc                # Core game logic (~2800 lines)
│   ├── MainView.mc           # Main screen rendering
│   ├── MainDelegate.mc       # Main screen input
│   ├── SetupView.mc          # Pet creation flow
│   ├── SetupDelegate.mc      # Setup input
│   ├── MiniGameView/Delegate  # "Catch!" timing game
│   ├── RushGameView/Delegate  # "Rush!" speed game
│   ├── ReactGameView/Delegate # "React!" reaction game
│   ├── DodgeGameView/Delegate # "Dodge!" avoidance game
│   └── MemoryGameView/Delegate# "Memory!" pattern game
└── bin/                      # Build output
```

---

## Building

### Prerequisites

- [Garmin Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/) (tested with SDK 9.x)
- A signing key

### Generate Developer Key

```bash
openssl genrsa -out developer_key.pem 4096
openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem -out developer_key.der -nocrypt
```

### Compile

```bash
monkeyc -o bin/garmagochi.prg -f monkey.jungle -y developer_key.der -d fenix7x
```

### Run in Simulator

```bash
monkeydo bin/garmagochi.prg fenix7x
```

### Sideload to Watch

```bash
# Connect watch via USB, then:
cp bin/garmagochi.prg /Volumes/GARMIN/GARMIN/APPS/
diskutil unmount /Volumes/GARMIN
```

### Supported Devices

Currently configured for: fenix 7, fenix 7X, Descent Mk3 43mm, Descent Mk3i 51mm.
Add more devices in `manifest.xml` `<iq:products>` section.

---

## Controls

| Button | Main Screen | During Dilemma | Mini-Games |
|--------|-------------|----------------|------------|
| **UP** | Previous action | **Hug** | Game-specific |
| **DOWN** | Next action | **Punish** | Game-specific |
| **SELECT** | Execute action | **Hug** (default) | Tap/react |
| **BACK** | Save & exit | — | Quit game |

---

## Technical Details

- **Target**: Garmin fenix 7X / Descent Mk3i (round 280x280 display)
- **Language**: Monkey C (Connect IQ SDK 9.x)
- **Frame rate**: 4 FPS main screen (250ms timer), ~12 FPS mini-games (80ms timer)
- **Pixel art**: Programmatic rendering via `dc.fillRectangle()`, no bitmap assets
- **Sprites**: 12x12 grid, 4-color palettes per type, flat 144-element arrays
- **Persistence**: `Application.Storage` (key-value store, survives app restarts)
- **Haptics**: `Toybox.Attention.vibrate()` with custom `VibeProfile` patterns
- **Steps**: `Toybox.ActivityMonitor.getInfo().steps` (graceful degradation)
- **Clock**: `Toybox.System.getClockTime()` with 12h/24h from device settings

---

## Documentation

- **Mechanics.md** — pełna dokumentacja mechaniki gry po polsku (staty, śmierć, nastroje, stworki, mini-gry, itd.)

---

## License

All rights reserved. This application is intended for commercial distribution on the Garmin Connect IQ Store.
