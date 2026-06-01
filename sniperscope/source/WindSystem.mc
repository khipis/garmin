// ═══════════════════════════════════════════════════════════════
// WindSystem.mc — Per-round horizontal wind.
//
// The wind value is sampled at the start of each round and held
// constant for the duration of that round (real long-range wind
// does change, but a stable value teaches the mechanic better and
// is much more readable on a tiny watch HUD).
//
// `strength` is in arbitrary units — positive = wind blowing
// rightward (so the bullet drifts right), negative = leftward.
// Range is roughly [-3.0, +3.0]; difficulty caps it.
// ═══════════════════════════════════════════════════════════════

class WindSystem {

    var strength;     // signed wind value

    hidden var _rng;

    function initialize() {
        strength = 0.0;
        _rng     = 271828;
    }

    function setSeed(s) { _rng = s; if (_rng == 0) { _rng = 1; } }

    // Roll a new wind value for the next shot.  `diff` is the
    // current difficulty preset — higher difficulty allows bigger
    // gusts.
    function roll(diff) {
        var cap;
        if      (diff == SS_DIFF_EASY) { cap = 1.2; }
        else if (diff == SS_DIFF_HARD) { cap = 3.0; }
        else                            { cap = 2.0; }
        // PRNG: classic LCG, sample twice for a nicer distribution.
        _rng = (_rng * 1103515245 + 12345) & 0x7FFFFFFF;
        var a = (_rng % 10000).toFloat() / 10000.0;
        _rng = (_rng * 1103515245 + 12345) & 0x7FFFFFFF;
        var b = (_rng % 10000).toFloat() / 10000.0;
        var v = (a - 0.5 + b - 0.5);
        strength = v * cap;
    }

    // Human-readable label for HUD (e.g. "→ 1.4" or "← 0.7").
    function label() {
        var w = strength;
        if (w < 0.0) { w = -w; }
        var sign;
        if      (strength >  0.05) { sign = ">"; }
        else if (strength < -0.05) { sign = "<"; }
        else                        { sign = "·"; }
        return sign + " " + w.format("%.1f");
    }
}
