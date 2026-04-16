# Angry Pomodoro – ADHD Focus Timer

> A Pomodoro timer that actively interrupts you when you look at your watch during focus time.

---

## What is this?

**Angry Pomodoro** is a smartwatch focus timer built on behavioral interruption — a technique used in ADHD coaching to break the distraction loop before it becomes a spiral.

Most timers sit passively while you keep checking them. This one **reacts**. Every time you raise your wrist or open the app during a focus session, you get an angry cartoon tomato face, a red screen, and a vibration — forcing a moment of conscious awareness before you drift off task.

---

## Features

| Feature | Description |
|---------|-------------|
| **Wrist-raise interrupt** | Triggers instantly when you look at the watch during focus |
| **Anti-distraction overlay** | Full-screen "GO BACK TO TASK!" with angry face + shake |
| **Calm focus UI** | Breathing ring animation, large countdown, dark minimal design |
| **Rage end screen** | Comical animated rage when timer completes — with vibration loop |
| **3 presets** | 10 / 25 / 45 minute sessions |
| **No setup** | Tap once to start, choose time, go |

---

## App States

### 1. IDLE
- Dark background, calm neutral tomato face
- Tap to enter preset selection

### 2. FOCUS
- Near-black screen to minimize distraction
- Expanding/contracting breathing ring (inhale on expand, exhale on contract)
- Large centered countdown timer
- Progress bar at bottom
- Runs in background — timer keeps ticking when wrist is lowered

### 3. INTERRUPT (KEY FEATURE)
Triggered automatically on `onShow()` — i.e., every time the display activates during focus.

- Full-screen red flash
- "GO BACK TO TASK!" header
- Angry tomato face with steam puffs, V-brows, gritted teeth
- Screen shake effect (position jitter)
- Vibration pulse (70 intensity, 180ms)
- Countdown timer still visible — session is NOT paused
- Auto-dismisses after ~2 seconds, or tap to dismiss immediately

### 4. END
- Flashing red/orange background
- "TIME'S UP!" + "GREAT FOCUS!" message
- Animated rage face with rotating sparks and waggling tongue
- Repeating vibration every ~2 seconds
- Tap to reset

---

## Controls

| Action | Result |
|--------|--------|
| Tap / Select | Advance state / confirm |
| Up / Down | Navigate preset menu |
| Back / Long press | Cancel session, return to idle |
| Wrist raise (during focus) | Triggers interrupt overlay |

---

## ADHD Design Logic

### The Problem
ADHD makes it hard to resist checking the time, notifications, or the watch face during focus sessions. Each check breaks the flow state and makes re-entry harder.

### The Intervention
The **pattern interrupt** technique: instead of letting the check happen passively, the app introduces a brief but memorable friction event. The red screen + angry face + vibration creates:

1. **Awareness** — you notice you broke focus
2. **Accountability** — mild social-shame aesthetic (the tomato is judging you)
3. **Redirection** — the "dismiss" tap is a physical act of choosing to return to work

The session never pauses. The timer keeps running during the interrupt. This reinforces that distraction = time lost, not time paused.

### Why comical, not punishing?
Harsh feedback creates avoidance. Funny feedback creates self-awareness with a smile. The angry tomato is absurd on purpose — you're not failing, you're just being human.

---

## Formulas & Timing

- Timer resolution: 50ms tick (20fps for smooth animation)
- 1 second = 20 ticks (`_tick % 20 == 0` decrements counter)
- Interrupt duration: 44 ticks ≈ 2.2 seconds
- Rage vibration: every 40 ticks ≈ 2 seconds
- Breathing cycle: `sin(_breathPhase)` incremented 0.04 rad/tick ≈ 15.7s full cycle

---

## Building

```bash
# PRG (simulator / sideload)
monkeyc -o angrypomodoro.prg -f monkey.jungle -y developer_key.der -d fenix7

# IQ (Connect IQ Store)
monkeyc -o angrypomodoro.iq -f monkey.jungle -y developer_key.der -e
```

---

## Disclaimer

This is not a medical device or ADHD treatment tool. It is a watch app. Please consult a qualified professional for ADHD management strategies.
