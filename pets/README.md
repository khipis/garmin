# BitochiPets

A pixel-art virtual pet (Tamagotchi-style) application for Garmin smartwatches, built with the Connect IQ SDK in Monkey C.

Raise, feed, play with, and care for your pixel creature — directly on your wrist. **24 unique pet types**, extreme mood system, 5 mini-games, moral dilemmas, non-deterministic death, and an absurd sense of humor.

---

## Features

### 24 Unique Pet Types

Each creature has a distinct body shape (12×12 pixel art), 4-color palette, personality profile, stat modifiers, mood tendencies, and unique dialogue.

| Type | Element | Personality | Special Trait |
|------|---------|-------------|---------------|
| **Blobby** | Amorphous | Existential philosopher | Shape-shifting identity crisis |
| **Flamey** | Fire | Short-tempered pyromaniac | Fast hunger, easy rage |
| **Aqua** | Water | Calm romantic | Slow hunger, likes hugs |
| **Rocky** | Earth | Stoic tank | Very slow hunger, immune to punish |
| **Ghosty** | Spirit | Paranoid haunter | Phases through problems, easy paranoia |
| **Sparky** | Electric | Hyperactive spark | Fast energy drain, sugar high prone |
| **Frosty** | Ice | Cold-hearted romantic | Slow happiness drain, ice rage |
| **Shroomy** | Fungus | Psychedelic philosopher | Volatile stats, random reality shifts |
| **Emilka** | Human | Sensitive, loving & jealous | hugStress −10 (LOVES hugs), fastest happiness decay |
| **Vexor** | Demon | Pure evil | INVERTED mechanics — loves punish, hates hugs, ultra vulgar |
| **Chikko** | Chicken | Neurotic panicker | Paranoid at happiness<30, ultra fragile |
| **Dzikko** | Boar | Unhinged brute | Respects force (punish +4), charges walls |
| **Polacco** | Human | Polski Janusz | Speaks vulgar Polish, loves grill & beer |
| **Nosacz** | Monkey | Proud nose king | Communicates mostly in "E", nose-based world view |
| **Donut** | Food | Sweet & terrified | hugStress −5, TERRIFIED of being eaten |
| **Cactuso** | Plant | Stoic prickler | hugStress +50 (SPIKES!), ultra low maintenance |
| **Pixelbot** | Robot | Logic over feels | Speaks in data and error codes |
| **Octavio** | Octopus | 8 arms of chaos | Hyperactive multitasker, ink squirts |
| **Batsy** | Bat | Nocturnal weirdo | Hangs upside down, paranoid in daylight |
| **Nugget** | Food | Existential snack | Permanent crisis, afraid of ketchup |
| **Foczka** | Seal | Adorable flopper | hugStress −3, *arf arf!*, loves belly rubs |
| **Rainbow** | Light | Pure sparkle joy | hugStress −8, glitter explosions, double rainbow |
| **Doggo** | Dog | Crazy, loyal, happy | Loves everything and everyone at all times |
| **Undead** | Undead | Unkillable shambler | Cannot die, cannot get sick, needs nothing |

### Personality System

1. **Species** — fixed behavioral profile per pet type (stat rates, mood thresholds, unique actions/thoughts)
2. **Traits** — 2 random traits from 10 possibilities (incompatible pairs excluded)
3. **Dynamic Mood** — 7 extreme emotional states triggered by stat combinations

### 10 Character Traits

| Trait | Effect |
|-------|--------|
| **Glutton** | Hungers faster, always asking for food |
| **Picky** | Feeding less effective, but gets more joy from "good" food |
| **Playful** | Happiness decays slower |
| **Lazy** | Energy drops slower, nap restores more |
| **Hardy** | Resists sickness, passive health regen |
| **Fragile** | Gets sick easily, worse punish outcomes |
| **Cheerful** | Happiness decays slower, bonus joy from everything |
| **Grumpy** | Happiness decays faster, skeptical of affection |
| **Hyper** | Bonus from play, faster energy drain |
| **Sleepy** | Energy drops faster, nap restores most |

Incompatible pairs: Glutton↔Picky, Hardy↔Fragile, Hyper↔Sleepy, Playful↔Lazy, Cheerful↔Grumpy.

### 7 Extreme Mood States

| Mood | Trigger | Behavior |
|------|---------|----------|
| **Rage** | High hunger + low happiness | Violent shaking, red background |
| **Love** | Very high happiness + low hunger + high health | Hearts everywhere, "MARRY ME!" |
| **Sugar High** | High happiness + high energy | Rainbow explosions |
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
- **Undead exception**: immune to all death checks entirely

Death causes are displayed: "died of loneliness", "heart broke", "passed peacefully", etc.

### Hug Stress System

Every hug adds stress. Each pet type has a different tolerance:
- **Cactuso**: +50 per hug (SPIKES! lethal fast)
- **Vexor**: +40 (demon doesn't like touch)
- **Emilka**: −10 (LOVES hugs, heals from them)
- **Rainbow**: −8 (pure love absorber)
- **Doggo**: −5 (always happy to be hugged)

At hugStress 95+: massive stat damage, sickness, possible death.

### Moral Dilemma System

During extreme moods, forced moral choices appear — **Hug or Punish?** No correct answer. Outcomes are probabilistic and character-dependent.

- Normal actions are blocked until you decide — or wait ~15 seconds
- **Auto-resolve**: if ignored, the dilemma resolves on its own with character-specific consequences (Emilka cries, Vexor rages, Doggo forgives, Cactuso doesn't care)

### Smart Action Suggestions

When the pet needs urgent attention, the action bar **automatically switches** to the relevant option:
- Sick → **Heal** selected
- Very hungry → **Feed** selected
- Too much poop → **Clean** selected
- Low energy → **Nap** selected
- Wants to play → **Play** selected

### Neglect & Loneliness System

Each pet type reacts to neglect differently:
- **Sensitive pets** (Emilka, Doggo, Foczka, Rainbow): start showing sadness at neglect level 1
- **Tough pets** (Vexor, Sparky, Batsy): start showing sadness at level 3–4
- **Immune pets** (Cactuso, Undead): never care about neglect

### Pet Thoughts & Reminders

The pet speaks up every ~40 seconds with context-aware thoughts:
- **Play requests**: "Pogramy? *puppy eyes*" — sets suggested action to Play
- **Water reminders**: character-specific hydration tips
- **Step commentary**: reacts to your daily step count
- **Mood thoughts**: unique per type and trait combination

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
- **Night mode** — 23:00–7:00: slower stat decay, sleeping thoughts
- **Care streak** — daily interaction rewards (bonuses at 3, 7, 14, 30 days)
- **Aging stages** — Baby (<1d), Young (1–7d), Adult (7–30d), Elder (30d+)
- **Overfed mechanics** — feeding when not hungry causes vomiting and poop
- **Nap duration** — 60-second nap animation (5s in debug)
- **Autonomous actions** — pet acts on its own based on mood
- **Haptic feedback** — 4 vibration patterns for different events
- **Vibration toggle** — enable/disable vibrations in settings
- **Debug mode** — 300× time acceleration + "+3h Age" button for testing
- **Auto-save** — state persisted on exit and periodically

---

## Project Structure

```
garmin/
└── pets/
    ├── manifest.xml              # Connect IQ app metadata (105+ supported devices)
    ├── monkey.jungle             # Build configuration
    ├── README.md                 # This file
    ├── Mechanics.md              # Full game mechanics documentation (Polish)
    ├── resources/
    │   ├── strings.xml           # App name
    │   ├── drawables.xml         # Launcher icon reference
    │   └── launcher_icon.png     # App icon
    └── source/
        ├── BitochiPetsApp.mc     # App entry point, lifecycle
        ├── Pet.mc                # Core game logic (~3600 lines)
        ├── MainView.mc           # Main screen rendering
        ├── MainDelegate.mc       # Main screen input
        ├── SetupView.mc          # Pet creation flow
        ├── SetupDelegate.mc      # Setup input
        ├── MiniGameView.mc       # "Catch!" timing game
        ├── RushGameView.mc       # "Rush!" speed game
        ├── ReactGameView.mc      # "React!" reaction game
        ├── DodgeGameView.mc      # "Dodge!" avoidance game
        └── MemoryGameView.mc     # "Memory!" pattern game
```

---

## Building

### Prerequisites

- [Garmin Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/) (SDK 9.x recommended)
- A signing key (see below)

### Generate Developer Key

```bash
openssl genrsa -out developer_key.pem 4096
openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem -out developer_key.der -nocrypt
```

### Compile

```bash
# From the pets/ directory:
monkeyc -o bin/bitochipets.prg -f monkey.jungle -y developer_key.der -d fenix7x
```

Replace `fenix7x` with your target device (e.g. `descentmk3_43mm`, `fr965`, `venu3`).

### Run in Simulator

```bash
monkeydo bin/bitochipets.prg fenix7x
```

### Sideload to Watch

```bash
# Connect watch via USB, then:
cp bin/bitochipets.prg /Volumes/GARMIN/GARMIN/APPS/
diskutil unmount /Volumes/GARMIN
```

### Supported Devices

Over **105 Garmin devices** are configured in `manifest.xml`, including:
- Fenix 3–8 series (all variants)
- Forerunner 45–970 series
- Instinct 2/3/Crossover/E series
- Venu / Venu 2–4 series
- Vivoactive 3–6 series
- MARQ / MARQ2 series
- Epix / Epix 2 Pro series
- Descent Mk1/Mk2/Mk3/G1 series
- GPSMAP, Oregon, Montana, Rino handhelds
- Legacy/Swim models

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

- **Target**: Any Garmin round-display watch (280×280 or larger recommended)
- **Language**: Monkey C (Connect IQ SDK 9.x)
- **Frame rate**: 4 FPS main screen (250ms timer), ~12 FPS mini-games (80ms timer)
- **Pixel art**: Programmatic rendering via `dc.fillRectangle()`, no bitmap assets
- **Sprites**: 12×12 grid, 4-color palettes per type, flat 144-element arrays
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
