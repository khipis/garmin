# Bitochi8Ball

Magic 8-Ball app for Garmin watches. Retro pixel-art style, part of the Bitochi game family.

## Gameplay

1. **Ask a question** in your mind
2. **Shake the watch** or press any button
3. Watch the dramatic reveal animation
4. Get your answer from **100 unique responses** across 4 categories:
   - **Positive** (green glow) - "Absolutely freakin' yes!", "The stars align!"
   - **Negative** (red glow) - "Bruh. No.", "Error 404: answer not found"
   - **Cryptic** (purple glow) - "The stars are drunk, ask later", "Reply hazy, try again"
   - **Sassy** (amber glow) - "Ask your mom", "My lawyer says no comment"

## Features

- Pixel-art 8-ball with detailed shading and reflections
- Animated starfield background
- Dramatic shake + zoom reveal animation with sparkle ring
- Color-coded glow around ball based on answer type
- "The Oracle says:" header with answer category tag
- Question streak counter (Q#1, Q#2, ...)
- Haptic feedback on shake and answer reveal
- Accelerometer shake detection

## Controls

| Button | Action |
|--------|--------|
| Any button | Shake / Ask again |
| Physical shake | Shake |
| Back | Exit |

## Build

```bash
cd 8ball
monkeyc -o bin/8ball.prg -f monkey.jungle -y ../developer_key.der -d fenix7x
monkeydo bin/8ball.prg fenix7x
```
