# Boat Mode Dive Planner

A fast, outdoor-optimised dive planning tool for on-deck use between dives.  
Designed for maximum legibility in bright sunlight: near-black background + full-brightness verdict boxes.

---

## What it does

Three independent planning modes accessible from a single tap-to-select screen.  
Every mode delivers a **single, large, coloured verdict box** — readable at arm's length in full sun.

### 1. Quick Plan
**Inputs:** gas mix, depth, planned time, tank fill, tank size  
**Checks:** PO2 safety, NDL limit, gas duration  
**Verdict:** `GO` (green) / `REVIEW` (amber) / `NO GO` (red)

### 2. Safety Check
**Inputs:** gas mix, depth  
**Output:** PO2 value in large coloured digits + `SAFE` / `WARNING` / `DANGER`  
Also shows: MOD (maximum operating depth) and NDL for that mix/depth

### 3. Gas Check
**Inputs:** fill pressure, tank size, depth, planned time  
**Output:** how many minutes your gas lasts + `ENOUGH` / `SHORT` verdict

---

## Calculations

| Formula | Notes |
|---------|-------|
| PO2 = FO2 × (depth/10 + 1) | Ambient pressure in ATA |
| MOD = (1.4 / FO2 − 1) × 10 | Maximum depth at PO2 ≤ 1.4 ATA |
| NDL | PADI RDP table estimate, EAD-adjusted for nitrox |
| EAD = ((depth+10) × (1−FO2)/0.79) − 10 | Equivalent Air Depth for NDL lookup |
| Gas time = (fill−reserve) × tank / (SAC × ambP) | Available minutes at depth |

**Fixed assumptions:**
- SAC rate: **18 L/min** (conservative average)
- Reserve pressure: **50 bar**
- PO2 thresholds: working ≤ 1.4 ATA, absolute ≤ 1.6 ATA

---

## Controls

| Action | Result |
|--------|--------|
| **TAP tile** | Enter mode |
| **SELECT** | Enter mode / advance to next field |
| **BACK** | Previous field / return to mode selector |
| **UP / DOWN** | Change value of active field |
| **TAP upper/lower half** | Decrement / increment active field |

---

## Gas presets

| Label | FO2 |
|-------|-----|
| Air 21% | 0.21 |
| Nitrox 32 | 0.32 |
| Nitrox 36 | 0.36 |

---

## Verdict colours

| Colour | Meaning |
|--------|---------|
| **Bright green** | GO / SAFE / ENOUGH |
| **Bright amber** | REVIEW / WARNING (borderline) |
| **Bright red** | NO GO / DANGER / SHORT |

---

## Disclaimer

This application is for **informational and planning purposes only**.  
It is **not a dive computer**. Always use a certified dive computer underwater.  
Always follow your training and applicable dive tables.  
The author accepts no liability for decisions made based on this tool.

---

## Technical

- Minimum SDK: 4.0.0
- No permissions required
- Storage: none (no data persisted)
- Supports: Fenix, Epix, Forerunner, Instinct, Venu, Vivoactive series
