# Garmin Connect IQ Store Description

---

## Dive Risk Indicator – Score Your Dive Plan

Enter four inputs. Get one number. Know the risk.

Not a dive computer. Not a decompression planner. A fast, clear risk assessment tool — designed for the surface, between dives, before entering the water.

---

### How It Works

Adjust four parameters and the risk score updates instantly:

| Input | Options |
|---|---|
| **Depth** | 5–40m (13 steps) |
| **Bottom time** | 5–80 minutes |
| **Gas** | Air 21% / Nitrox 32 / Nitrox 36 |
| **Previous dive** | First dive / Repetitive |

---

### Output

**Risk Score (0–100)** — large in the centre of the screen

| Score | Level | Background |
|---|---|---|
| 0–35 | **LOW** | Dark green |
| 36–65 | **MEDIUM** | Dark amber |
| 66–100 | **HIGH** | Dark red (pulsing) |

Plus a one-line explanation:

- "Safe recreational dive"
- "Close to no-deco limit"
- "NDL exceeded — deco required"
- "Residual nitrogen elevated"
- "High risk profile"

---

### Scoring Model

The score combines four independent factors:

| Factor | Weight |
|---|---|
| Depth (0–40m) | up to 25 pts |
| NDL saturation (how close to limit) | up to 40 pts — key driver |
| Gas type (Air vs Nitrox) | 1–8 pts |
| Repetitive dive | 0 or 15 pts |

NDL uses the PADI RDP table with EAD correction for nitrox dives.

If bottom time exceeds NDL, the NDL factor scales beyond 40 pts — ensuring HIGH risk is triggered regardless of other inputs.

---

### Example Scores

| Dive | Score | Level |
|---|---|---|
| 10m / 30min / Air / first | 20 | LOW |
| 25m / 25min / Air / first | 57 | MEDIUM |
| 30m / 20min / Air / first | 68 | HIGH |
| 30m / 15min / Nitrox 32 / first | 42 | MEDIUM |
| 40m / 9min / Air / repetitive | 78 | HIGH |
| 18m / 30min / Nitrox 36 / first | 28 | LOW |

---

### Controls

| Button | Action |
|---|---|
| UP / DOWN | Change value of active field |
| SELECT | Advance to next field |
| BACK | Return to previous field |
| TAP upper | Decrement value |
| TAP lower | Increment value |

---

### Safety

This app uses a simplified risk model. It is **not** a dive computer, decompression planner, or medical advice tool. Always dive within your certification limits and use a certified dive computer underwater.

---

*Clarity over precision. One score. One decision.*
