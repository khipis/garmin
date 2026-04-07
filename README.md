# Bitochi Games

A collection of retro pixel-art games for Garmin Connect IQ smartwatches, built with Monkey C.

## Games

| Game | Folder | Description |
|------|--------|-------------|
| **BitochiPets** | `pets/` | Virtual pet — feed, play, and care for pixel creatures with mini-games |
| **Bitochi8Ball** | `8ball/` | Magic 8-Ball — shake your watch to get answers |
| **BitochiRun** | `run/` | Monster escape — scan dungeons, find creatures, run for your life |
| **BitochiJump** | `jump/` | Ski jumping — accelerometer-controlled flight with realistic physics |
| **BitochiParachute** | `parachute/` | 3D parachute — freefall and land on the target from behind-view |
| **BitochiSniper** | `sniper/` | Sniper hunt — track and shoot pixel creatures in parallax terrain |
| **BitochiCatapult** | `catapult/` | Catapult siege — 16 fairy tale rounds of castle destruction |
| **BitochiSkywalker** | `skywalker/` | Space combat — laser battles against imperial fighters |
| **BitochiBomb** | `bomb/` | Bomb drop — steer a plane and chain-explode enemies on the ground |
| **BitochiAxe** | `axe/` | Viking axe throw — rotation physics, hit the log with the blade |
| **BitochiAxeArcade** | `arcade/` | Axe arcade — stick axes in a spinning log, avoid collisions |
| **BitochiFish** | `fish/` | Fishing — cast, fight fish with accelerometer tension control |
| **BitochiSwing** | `swing/` | Pendulum swing — release at the right moment, fly through enchanted forest |

## Requirements

- Garmin Connect IQ SDK 4.0+
- Monkey C compiler (`monkeyc`)
- Developer key (`.der`)

## Build

```bash
SDK_PATH="/path/to/connectiq-sdk/bin"
KEY="/path/to/developer_key.der"
DEVICE="fenix7"

cd <game_folder>
$SDK_PATH/monkeyc -d $DEVICE -f monkey.jungle -o bin/output.prg -y $KEY
```

## Supported Devices

Fenix 5/5S/5X, Fenix 6/6S/6X Pro, Fenix 7/7S/7X/Pro, Fenix 8, Forerunner 265/555/570/745/945/955/965/970, Venu/Venu 2/3/4, Vivoactive 4/5/6, Instinct 2/3, Epix 2, MARQ 2, Descent series, and more.

## License

Private project.
