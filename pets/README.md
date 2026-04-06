# BitochiPets

Virtual pet (Tamagotchi-style) game for Garmin watches with 24 unique characters, deep gameplay mechanics, mini-games, and pixel-art graphics. The flagship app of the Bitochi game family.

## Features

### 24 Unique Pet Types
Each with custom pixel art, personality, dialogues, and behaviors:

Emilka, Vexor, Polacco (Janusz), Nosacz, Chikko, Dzikko, Donut, Cactuso, Pixelbot, Octavio, Batsy, Nugget, Foczka, Rainbow, Doggo, Undead, Rocky, and more.

### Core Mechanics
- **Stats**: Hunger, Happiness, Energy, Health - each decaying in real-time
- **Actions**: Feed, Play, Sleep, Heal, Hug, Punish, Nap
- **Aging**: Pets age, evolve, and can die
- **Personality Traits**: Lazy, Hyper, Cheerful, Grumpy, Playful, Sleepy, Brave, Shy, Smart, Silly - each affecting stat rates and behavior
- **Moral Dilemmas**: Hug or punish decisions with character-dependent outcomes
- **Neglect System**: Visible sadness, loneliness effects, character-specific reactions
- **Sickness & Recovery**: Natural sickness, healing, and recovery mechanics
- **Non-deterministic Death**: Influenced by care quality, loneliness, and random factors

### Mini-Games (Play action)
- **Catch** - Timing game
- **Rush** - Speed reaction
- **React** - Quick response
- **Dodge** - Avoid obstacles
- **Memory** - Pattern memorization

### Special Features
- 14+ rare random events with special animations
- Autonomous idle animations
- Step counter with pet commentary
- Water drinking reminders
- Play requests from pet
- Night mode
- Vibration on/off toggle
- Care streak tracking
- Debug mode with accelerated time
- Full state persistence

### Notable Characters
- **Vexor** - The most vulgar pet in existence. Thrives on punishment, hates hugs
- **Polacco (Janusz)** - Speaks vulgar Polish, has a mustache
- **Emilka** - Sensitive, loving, jealous. Immune to hug overdose
- **Undead** - Cannot die, needs nothing
- **Doggo** - Crazy happy loyal dog

## Controls

| Button | Action |
|--------|--------|
| UP/DOWN | Cycle actions |
| Select | Perform action |
| Menu | Settings / Reset |
| Back | Exit |

## Build

```bash
cd pets
monkeyc -o bin/bitochipets.prg -f monkey.jungle -y ../developer_key.der -d fenix7x
monkeydo bin/bitochipets.prg fenix7x
```
