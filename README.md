# Bitochi Games for Garmin

A collection of retro pixel-art games for Garmin watches, built with Connect IQ SDK.

## Games

| Game | Description | Directory |
|------|-------------|-----------|
| **BitochiPets** | Virtual pet (Tamagotchi) with 24 unique characters | `pets/` |
| **Bitochi8Ball** | Magic 8-Ball oracle with 100 answers | `8ball/` |
| **BitochiCatapult** | Physics catapult destruction game, 7 rounds | `catapult/` |
| **BitochiJump** | Ski jumping simulator with 5 characters | `jump/` |
| **BitochiRun** | Horror chase escape with accelerometer | `run/` |

## Build All

Requires [Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/) and a developer key.

```bash
# BitochiPets
cd pets && monkeyc -o bin/bitochipets.prg -f monkey.jungle -y ../developer_key.der -d fenix7x

# Bitochi8Ball
cd 8ball && monkeyc -o bin/8ball.prg -f monkey.jungle -y ../developer_key.der -d fenix7x

# BitochiCatapult
cd catapult && monkeyc -o bin/catapult.prg -f monkey.jungle -y ../developer_key.der -d fenix7x

# BitochiJump
cd jump && monkeyc -o bin/jump.prg -f monkey.jungle -y ../developer_key.der -d fenix7x

# BitochiRun
cd run && monkeyc -o bin/run.prg -f monkey.jungle -y ../developer_key.der -d fenix7x
```

## Run in Emulator

```bash
monkeydo <path-to-prg> fenix7x
```

## Shared Features

- Retro pixel-art visual style
- Designed for round Garmin watch displays
- Haptic feedback (vibration)
- Accelerometer support where applicable
- Supports 100+ Garmin device models
- Characters shared across games (Pets universe)

## Sideloading to Watch

1. Build the `.prg` file for your specific device model
2. Connect watch via USB
3. Copy `.prg` to `GARMIN/APPS/` folder on the watch
4. Disconnect and find the app in your watch menu
