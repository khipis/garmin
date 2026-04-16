// DiveMath.mc
// ─────────────────────────────────────────────────────────────────────────────
// Dive Gas & Planning Toolkit — calculation engine
//
// ALL formulas are cross-validated with manual recalculation and known
// reference values from PADI and diving physics.
//
// Pressure model:
//   1 ATA at surface + 1 ATA per 10m sea water (fresh water: 10.3m/ATA)
//   absolute pressure P = depth/10 + 1   (in ATA)
// ─────────────────────────────────────────────────────────────────────────────

using Toybox.Math;

// ── Preset constants shared across the app ───────────────────────────────────

const DIVE_FO2_VALS  = [0.21, 0.27, 0.28, 0.29, 0.30, 0.31, 0.32, 0.36];
const DIVE_FO2_LBLS  = ["Air 21%", "EAN 27", "EAN 28", "EAN 29", "EAN 30", "EAN 31", "Nitrox 32", "Nitrox 36"];

const DIVE_DEPTHS    = [10, 15, 18, 20, 25, 30, 35, 40];

const DIVE_TANKS     = [10, 12, 15];
const DIVE_STARTP    = [100, 120, 140, 160, 180, 200, 220, 240];
const DIVE_ENDP      = [30, 40, 50, 60, 70, 80, 100, 120];
const DIVE_TIMES     = [10, 15, 20, 25, 30, 40, 50, 60, 80];

const DIVE_PO2_WORK  = 1.4;   // working PO2 limit
const DIVE_PO2_ABS   = 1.6;   // absolute PO2 limit

// ── NDL reference table (PADI RDP simplified, AIR) ───────────────────────────
const DIVE_NDL_D     = [10, 15, 18, 20, 25, 30, 35, 40];
const DIVE_NDL_T     = [219, 80, 56, 45, 29, 20, 14, 9];


class DiveMath {

    function initialize() {}

    // ═════════════════════════════════════════════════════════════════════════
    // PO2  —  Partial Pressure of Oxygen
    //
    // Formula:  PO2 = FO2 × (depth/10 + 1)
    //   depth/10 + 1  = absolute pressure in ATA (Atmospheres Absolute)
    //
    // Validated test cases:
    //   Case 1 — Air (0.21) at 30m:
    //     P = 30/10 + 1 = 4 ATA
    //     PO2 = 0.21 × 4 = 0.84  ✓ SAFE (< 1.4)
    //   Case 2 — Nitrox 32 (0.32) at 30m:
    //     PO2 = 0.32 × 4 = 1.28  ✓ SAFE
    //   Case 3 — Nitrox 36 (0.36) at 30m:
    //     PO2 = 0.36 × 4 = 1.44  ✗ EXCEEDS 1.4 working limit
    //   Case 4 — Nitrox 32 (0.32) at 40m:
    //     PO2 = 0.32 × 5 = 1.60  ✗ AT absolute limit
    // ═════════════════════════════════════════════════════════════════════════
    function po2(fo2, depth) {
        if (fo2 <= 0.0 || depth < 0) { return 0.0; }
        return fo2 * (depth.toFloat() / 10.0 + 1.0);
    }

    // ═════════════════════════════════════════════════════════════════════════
    // MOD  —  Maximum Operating Depth
    //
    // Formula:  MOD = (po2Limit / FO2 − 1) × 10
    //   Derived from PO2 formula: depth = (PO2/FO2 − 1) × 10
    //
    // Validated test cases:
    //   Case 1 — Air (0.21), limit 1.4:
    //     MOD = (1.4/0.21 − 1) × 10 = (6.667 − 1) × 10 = 56.7 → 56m  ✓
    //   Case 2 — Nitrox 32 (0.32), limit 1.4:
    //     MOD = (1.4/0.32 − 1) × 10 = (4.375 − 1) × 10 = 33.75 → 33m  ✓
    //   Case 3 — Nitrox 36 (0.36), limit 1.4:
    //     MOD = (1.4/0.36 − 1) × 10 = (3.889 − 1) × 10 = 28.9 → 28m  ✓
    //   Case 4 — Nitrox 36 (0.36), limit 1.6 (absolute):
    //     MOD = (1.6/0.36 − 1) × 10 = (4.444 − 1) × 10 = 34.4 → 34m
    // ═════════════════════════════════════════════════════════════════════════
    function mod(fo2, po2Limit) {
        if (fo2 <= 0.0) { return 0.0; }
        return (po2Limit / fo2 - 1.0) * 10.0;
    }

    // ═════════════════════════════════════════════════════════════════════════
    // BEST MIX  —  Optimal FO2 for planned depth at PO2 = 1.4
    //
    // Formula:  FO2 = 1.4 / (depth/10 + 1)
    //   Result clamped to [0.21, 1.0] (air minimum, pure O2 maximum)
    //
    // Validated test cases:
    //   Case 1 — 30m: FO2 = 1.4/4 = 0.350  → Nitrox 35  ✓
    //   Case 2 — 40m: FO2 = 1.4/5 = 0.280  → Nitrox 28  ✓
    //   Case 3 — 20m: FO2 = 1.4/3 = 0.467  → capped, use Nitrox 36 max common
    //   Case 4 — 10m: FO2 = 1.4/2 = 0.700  → very shallow, high O2 theoretical
    // ═════════════════════════════════════════════════════════════════════════
    function bestMix(depth) {
        if (depth <= 0) { return 0.21; }
        var f = 1.4 / (depth.toFloat() / 10.0 + 1.0);
        if (f > 1.0) { f = 1.0; }
        if (f < 0.21) { f = 0.21; }
        return f;
    }

    // ═════════════════════════════════════════════════════════════════════════
    // EAD  —  Equivalent Air Depth
    //
    // Formula:  EAD = ((depth + 10) × (1 − FO2) / 0.79) − 10
    //   0.79 = fraction of nitrogen in air (FN2 = 1 − 0.21)
    //   Result = air depth with equivalent N2 partial pressure
    //
    // Derivation: equate N2 partial pressure
    //   (depth+10) × (1-FO2) / (EAD+10) × 0.79  → solve for EAD
    //
    // Validated test cases:
    //   Case 1 — Nitrox 32 (0.32) at 30m:
    //     EAD = (40 × 0.68 / 0.79) − 10 = (27.2/0.79) − 10 = 34.43 − 10 = 24.4m  ✓
    //   Case 2 — Nitrox 36 (0.36) at 30m:
    //     EAD = (40 × 0.64 / 0.79) − 10 = (25.6/0.79) − 10 = 32.4 − 10 = 22.4m  ✓
    //   Case 3 — Air (0.21) at 30m:
    //     EAD = (40 × 0.79 / 0.79) − 10 = 40 − 10 = 30m  ✓ (equals actual depth)
    //   Case 4 — Nitrox 32 at 18m:
    //     EAD = (28 × 0.68 / 0.79) − 10 = 24.1 − 10 = 14.1m  ✓ (significant benefit)
    // ═════════════════════════════════════════════════════════════════════════
    function ead(depth, fo2) {
        if (depth < 0) { depth = 0; }
        if (fo2 >= 1.0) { return 0.0; }
        var result = ((depth.toFloat() + 10.0) * (1.0 - fo2) / 0.79) - 10.0;
        if (result < 0.0) { result = 0.0; }
        return result;
    }

    // ═════════════════════════════════════════════════════════════════════════
    // SAC  —  Surface Air Consumption (L/min)
    //
    // Formula:  gas_used = (startP − endP) × tank_L
    //           ambient_P = depth/10 + 1
    //           SAC = gas_used / (time × ambient_P)
    //
    // Units: tank in liters, pressure in bar, time in minutes, depth in meters
    // Result: surface-equivalent consumption in liters per minute
    //
    // Validated test cases:
    //   Case 1 — 12L tank, 200→50 bar, 30 min, 20m:
    //     gas = (200-50) × 12 = 1800 L
    //     P = 20/10+1 = 3 ATA
    //     SAC = 1800 / (30 × 3) = 1800/90 = 20.0 L/min  ✓
    //   Case 2 — 10L tank, 220→80 bar, 40 min, 15m:
    //     gas = 140 × 10 = 1400 L,  P = 2.5 ATA
    //     SAC = 1400 / (40 × 2.5) = 14.0 L/min  ✓
    //   Case 3 — 15L tank, 200→100 bar, 25 min, 30m:
    //     gas = 100 × 15 = 1500 L,  P = 4.0 ATA
    //     SAC = 1500 / (25 × 4) = 15.0 L/min  ✓
    // ═════════════════════════════════════════════════════════════════════════
    function sac(tank, startP, endP, time, depth) {
        if (tank <= 0 || time <= 0 || depth < 0) { return 0.0; }
        if (startP <= endP) { return 0.0; }
        var gasUsed = (startP - endP).toFloat() * tank.toFloat();
        var ambient = depth.toFloat() / 10.0 + 1.0;
        var denom   = time.toFloat() * ambient;
        if (denom <= 0.0) { return 0.0; }
        return gasUsed / denom;
    }

    // ═════════════════════════════════════════════════════════════════════════
    // NDL  —  No-Decompression Limit (minutes)
    //
    // Method: PADI RDP simplified table + linear interpolation
    // For nitrox: EAD is used as effective depth → automatic NDL extension
    //
    // NDL table (DIVE_NDL_D / DIVE_NDL_T constants):
    //   10m→219  15m→80  18m→56  20m→45  25m→29  30m→20  35m→14  40m→9
    //
    // Validated test cases:
    //   Case 1 — Air, 20m: NDL = 45 min  ✓ (exact table match)
    //   Case 2 — Air, 22.5m: interpolate 20m(45) ↔ 25m(29)
    //     frac = (22.5-20)/(25-20) = 0.50
    //     NDL = 45 + (29-45)×0.50 = 45 − 8 = 37 min
    //   Case 3 — Nitrox 32, 30m:
    //     EAD = (40×0.68/0.79)−10 = 24.4m
    //     Interpolate 20m(45)↔25m(29), frac=(24.4-20)/5=0.88
    //     NDL = 45 + (29-45)×0.88 = 45 − 14.1 = 30.9 → 30 min
    //     (vs 20 min on air — 50% extension)  ✓
    //   Case 4 — Air, 40m: NDL = 9 min  ✓ (table minimum)
    // ═════════════════════════════════════════════════════════════════════════
    function ndl(depth, fo2) {
        // For nitrox, use EAD as effective depth (automatic NDL benefit)
        var effD = depth.toFloat();
        if (fo2 > 0.209) {
            var eadV = ead(depth, fo2);
            if (eadV >= 0.0) { effD = eadV; }
        }

        var n = DIVE_NDL_D.size();

        // Shallower than shallowest table entry — use maximum
        if (effD <= DIVE_NDL_D[0].toFloat()) { return DIVE_NDL_T[0].toFloat(); }
        // Deeper than deepest entry — use minimum
        if (effD >= DIVE_NDL_D[n - 1].toFloat()) { return DIVE_NDL_T[n - 1].toFloat(); }

        // Linear interpolation between bracketing table entries
        for (var i = 0; i < n - 1; i++) {
            var d0 = DIVE_NDL_D[i].toFloat();
            var d1 = DIVE_NDL_D[i + 1].toFloat();
            if (effD >= d0 && effD <= d1) {
                var t0   = DIVE_NDL_T[i].toFloat();
                var t1   = DIVE_NDL_T[i + 1].toFloat();
                var frac = (effD - d0) / (d1 - d0);
                return t0 + (t1 - t0) * frac;
            }
        }
        return DIVE_NDL_T[n - 1].toFloat();
    }
}
