# Escape Kit – Fake Alert Simulator

> Your secret emergency escape system on your wrist.

---

## What it does

Escape Kit displays ultra-realistic fake notification screens on your Garmin watch so you can gracefully exit uncomfortable situations, break focus loops, or reset your attention — without explanation.

**Credibility is the #1 priority.** Every fake screen is designed to look authentic at a glance.

---

## Modules (6 alert types)

| Module     | Appearance                                               | Vibe Pattern              |
|------------|----------------------------------------------------------|---------------------------|
| Phone Call | Pulsing green ripple rings, caller avatar, Accept/Decline circles | Ring × 3 (repeating)     |
| SMS        | iOS-style notification card, message bubble, action bar  | Double tap                |
| WhatsApp   | Green header, chat bubble, unread dot                    | Double tap                |
| Email      | Gmail-style header, priority badge, urgent subject       | Single medium pulse        |
| Telegram   | Blue header, message preview, Reply/Mark Read actions    | Double tap                |
| PagerDuty  | Flashing red border, SEVERITY 1 badge, ACKNOWLEDGE btn   | Rapid urgent pattern       |

---

## How to use

1. **Open the app** → you see a 2×3 module grid
2. **Scroll Up/Down** to highlight a module, or **tap directly** on one
3. **Press Select** to enter config
4. **Scroll Up/Down** to cycle sender name presets (Mom, Boss, Dr. Smith, etc.)
5. **Tap delay buttons** to set a delay: Now / 10s / 30s / 1min
6. **Tap TRIGGER** (or press Select) → fake alert appears on screen
7. **Press Back** at any time to dismiss

---

## Sender presets

Each module has 4 preset sender names. Cycle through them with Up/Down in the config screen:

- **Call**: Mom, Boss, Dr. Smith, Unknown
- **SMS**: Mom, Bank Alert, Amazon, Google
- **WhatsApp**: Work Group, John D., Family, Anna
- **Email**: IT Security, HR Dept, Finance, CEO
- **Telegram**: DevOps Bot, Support, Team Channel, Monitor Bot
- **PagerDuty**: PROD-001, SEV-1, P0-CRITICAL, ENG-OPS

---

## Controls

| Screen    | Up/Down     | Select           | Back             | Tap             |
|-----------|-------------|------------------|------------------|-----------------|
| Home      | Cycle module| Open config      | Exit app         | Tap module card |
| Config    | Cycle sender| Trigger now      | Back to home     | Tap delay / trigger |
| Countdown | —           | Cancel           | Cancel           | Cancel          |
| Fake      | —           | Dismiss          | Dismiss          | Dismiss         |

---

## Use cases

### ADHD focus reset
When you're stuck in a hyperfocus loop or need a socially acceptable reason to step away, trigger a fake urgent call or PagerDuty alert. The vibration interrupts the loop.

### Social escape
In a meeting that's running long? Set a 30-minute delayed fake call before it starts. Your watch vibrates with an incoming call screen — you have a natural, believable exit.

### Awkward situations
Trigger an instant fake SMS or email notification while in a conversation to create a pause point, or to justify needing to leave.

### Focus recovery
The phone call screen's pulsing green circles can act as a visual/haptic anchor to pull attention back from a spiral. Dismiss it and refocus.

---

## Technical notes

- **All local** — no internet, no backend, no real notifications sent
- **Auto-dismiss**: Call = 16s, PagerDuty = 13s, all others = 9s
- **Vibration**: Uses `Toybox.Attention.vibrate()` — pattern varies per module
- **Compatible** with all major Garmin watch models (Fenix, Forerunner, Venu, Instinct, etc.)

---

## Build

```bash
monkeyc -f fakenotificationescape/monkey.jungle \
        -o _PROD/fakenotificationescape.prg \
        -y developer_key.der -d fenix7
```

---

*Escape Kit is for entertainment and accessibility purposes. Use responsibly.*
