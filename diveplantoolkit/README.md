# Dive Gas & Planning Toolkit

A fast, reliable, professional dive planning tool for recreational scuba divers.

> **This app is NOT a dive computer and NOT a decompression planner.**
> It is a quick decision-support tool used **before and between dives**.

---

## Features

| Calculator | What it tells you |
|---|---|
| **MOD / PO2** | Is your gas safe at this depth? What is your maximum operating depth? |
| **Best Mix** | What nitrox fraction should you fill to maximise NDL at your target depth? |
| **EAD** | What air depth has the same nitrogen loading as your nitrox at this depth? |
| **Gas Usage (SAC)** | What is your surface air consumption rate from a completed dive? |
| **NDL Limit** | How long can you stay at this depth without needing decompression? |

---

## Formulas

### 1. PO2 — Partial Pressure of Oxygen

```
PO2 = FO2 × (depth / 10 + 1)
```

- `FO2` = oxygen fraction (0.21 for air, 0.32 for Nitrox 32, etc.)
- `depth / 10 + 1` = absolute pressure in ATA (Atmospheres Absolute)
  - 1 ATA at surface + 1 ATA per 10 m sea water

**Safety limits:**
- ≤ 1.4 ATA — working limit (GREEN)
- 1.4 – 1.6 ATA — warning zone (ORANGE)
- > 1.6 ATA — absolute limit exceeded (RED)

---

### 2. MOD — Maximum Operating Depth

```
MOD = (po2_limit / FO2 − 1) × 10
```

Derived by solving the PO2 formula for depth, using `po2_limit = 1.4`.

---

### 3. Best Mix

```
FO2 = 1.4 / (depth / 10 + 1)
```

Returns the optimal oxygen fraction that gives exactly PO2 = 1.4 at the planned depth.
Result is clamped to the range [0.21, 1.0].

---

### 4. EAD — Equivalent Air Depth

```
EAD = ((depth + 10) × (1 − FO2) / 0.79) − 10
```

- `0.79` = fraction of nitrogen in air (FN2 = 1 − 0.21)
- EAD is the air depth that produces the same nitrogen partial pressure as your nitrox mix at `depth`.
- A lower EAD means a reduced nitrogen load → longer NDL.

---

### 5. SAC — Surface Air Consumption

```
gas_used  = (start_pressure − end_pressure) × tank_size_L
ambient_P = depth / 10 + 1
SAC       = gas_used / (dive_time_min × ambient_P)
```

Units: L/min at surface pressure.

---

### 6. NDL — No-Decompression Limit

Based on the **PADI RDP simplified table** with linear interpolation between entries.

| Depth | NDL (air) |
|---|---|
| 10 m | 219 min |
| 15 m | 80 min |
| 18 m | 56 min |
| 20 m | 45 min |
| 25 m | 29 min |
| 30 m | 20 min |
| 35 m | 14 min |
| 40 m | 9 min |

**For nitrox:** EAD is used as the effective depth before table lookup, automatically extending the NDL.

---

## Step-by-Step Examples

### MOD / PO2

**Scenario:** Nitrox 32 (FO2 = 0.32) at 30 m

```
P     = 30/10 + 1 = 4 ATA
PO2   = 0.32 × 4  = 1.28  → SAFE (< 1.4)
MOD   = (1.4/0.32 − 1) × 10 = (4.375 − 1) × 10 = 33.75 → 33 m
```

---

### Best Mix

**Scenario:** Planning a dive to 30 m

```
FO2 = 1.4 / (30/10 + 1) = 1.4 / 4 = 0.35  → Nitrox 35
```

At this fraction, PO2 will be exactly 1.4 at 30 m — the safest maximum mix.

---

### EAD

**Scenario:** Nitrox 32 at 30 m

```
EAD = ((30 + 10) × (1 − 0.32) / 0.79) − 10
    = (40 × 0.68 / 0.79) − 10
    = (27.2 / 0.79) − 10
    = 34.43 − 10
    = 24.4 m
```

Your nitrogen loading is equivalent to diving to 24 m on air.
NDL at 24.4 m (air) ≈ 36 min vs 20 min on air at 30 m — a significant extension.

---

### SAC

**Scenario:** 12 L tank, 200 → 50 bar, 30 min dive, 20 m average depth

```
gas_used  = (200 − 50) × 12 = 1800 L
ambient_P = 20/10 + 1 = 3 ATA
SAC       = 1800 / (30 × 3) = 1800 / 90 = 20.0 L/min
```

A typical recreational diver has a SAC of 12–20 L/min.

---

### NDL

**Scenario:** Nitrox 32 at 30 m

```
Step 1 — EAD:
  EAD = ((40 × 0.68) / 0.79) − 10 = 24.4 m

Step 2 — NDL table lookup at 24.4 m (air):
  Bracket: 20 m (45 min) ↔ 25 m (29 min)
  frac = (24.4 − 20) / (25 − 20) = 0.88
  NDL = 45 + (29 − 45) × 0.88 = 45 − 14.1 ≈ 31 min

Compare: air at 30 m → NDL = 20 min
Nitrox 32 extension: +11 min
```

---

## Assumptions

- **Pressure model:** sea water, 10 m per ATA (fresh water would be ~10.3 m/ATA)
- **Units:** meters, bar, liters, minutes
- **PO2 working limit:** 1.4 ATA
- **PO2 absolute limit:** 1.6 ATA
- **NDL table source:** PADI RDP simplified values (air, single-dive, no repetitive dive adjustment)
- **No repetitive dive correction**, no altitude adjustment, no tissue loading

---

## Navigation

```
MAIN MENU
  UP / DOWN ............. scroll items
  SELECT / TAP .......... open calculator

IN CALCULATOR
  UP / DOWN ............. cycle value of active field
  SELECT ................ advance to next field
  BACK .................. previous field / back to menu
  MENU (long press) ..... jump to main menu
  TAP upper half ........ decrement value
  TAP lower half ........ increment value
```

---

## Running in the Garmin Simulator

1. Install the Connect IQ SDK from [developer.garmin.com](https://developer.garmin.com/connect-iq/)
2. Open the Connect IQ simulator
3. Load the `.prg` from `_PROD/diveplantoolkit.prg`
   - File → Load App → select the prg
4. Or build from source:
   ```bash
   monkeyc -w -o diveplantoolkit.prg \
     -f diveplantoolkit/monkey.jungle \
     -y developer_key.der \
     -d descentmk351mm
   ```

---

## Validation Test Cases

### PO2

| Gas | Depth | Expected PO2 | Status |
|---|---|---|---|
| Air (0.21) | 30 m | 0.84 | SAFE |
| Nitrox 32 (0.32) | 30 m | 1.28 | SAFE |
| Nitrox 36 (0.36) | 30 m | 1.44 | WARNING |
| Nitrox 32 (0.32) | 40 m | 1.60 | DANGER |

### MOD

| Gas | Limit | Expected MOD |
|---|---|---|
| Air (0.21) | 1.4 | 56 m |
| Nitrox 32 (0.32) | 1.4 | 33 m |
| Nitrox 36 (0.36) | 1.4 | 28 m |

### EAD

| Gas | Depth | Expected EAD |
|---|---|---|
| Air (0.21) | 30 m | 30 m (same) |
| Nitrox 32 (0.32) | 30 m | 24.4 m |
| Nitrox 36 (0.36) | 30 m | 22.4 m |

### SAC

| Tank | Start | End | Time | Depth | Expected SAC |
|---|---|---|---|---|---|
| 12 L | 200 | 50 | 30 min | 20 m | 20.0 L/min |
| 10 L | 220 | 80 | 40 min | 15 m | 14.0 L/min |
| 15 L | 200 | 100 | 25 min | 30 m | 15.0 L/min |

### NDL

| Gas | Depth | Expected NDL |
|---|---|---|
| Air | 20 m | 45 min (exact) |
| Air | 40 m | 9 min (exact) |
| Air | 22.5 m | ~37 min (interpolated) |
| Nitrox 32 | 30 m | ~31 min (via EAD 24.4 m) |

---

## Architecture

```
diveplantoolkit/
├── source/
│   ├── BitochIDiveApp.mc   — app entry, lifecycle
│   ├── DiveMath.mc         — all formulas, NDL table, validation comments
│   ├── DiveView.mc         — state machine, all screen rendering
│   └── DiveDelegate.mc     — button + touch input mapping
├── resources/
│   ├── strings.xml
│   ├── drawables.xml
│   └── launcher_icon.png
├── manifest.xml
├── monkey.jungle
└── README.md
```

---

## Safety Limitations

- This app uses a **simplified pressure model** (sea water, standard atmosphere)
- The NDL table is based on a **single-dive, no-repetitive-dive scenario**
- No adjustment for **altitude, cold water, exertion, or age**
- **Nitrox NDL benefit** is calculated via EAD — this is the standard recreational diving method
- Real dive computers apply continuous tissue loading algorithms (Bühlmann, etc.)

---

## Disclaimer

**IMPORTANT — READ BEFORE USE**

This application is for informational and planning purposes only.

It is **NOT** a dive computer or decompression planning tool.

Always:
- Follow your certified dive training
- Use a properly calibrated dive computer underwater
- Dive within the limits of your training and certification
- Get your gas analysed and labelled before every dive

The developer assumes **no responsibility** for injury, death, or equipment damage
resulting from the use or misuse of this application. All calculations are
estimates based on simplified models.

**Do not use this app as your primary safety reference underwater.**
