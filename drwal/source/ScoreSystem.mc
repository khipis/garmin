// ═══════════════════════════════════════════════════════════════
// ScoreSystem.mc — Score, fast-chop combo bonus, persisted best.
// ═══════════════════════════════════════════════════════════════
using Toybox.Application;

class ScoreSystem {
    var score;
    var hi;
    var combo;             // consecutive fast-chop streak (0-based)
    hidden var _lastChopMs;

    function initialize() {
        hi = _load();
        reset();
    }

    function reset() {
        score       = 0;
        combo       = 0;
        _lastChopMs = -1000000;
    }

    hidden function _load() {
        try {
            var v = Application.Storage.getValue(DR_HI_KEY);
            if (v != null && v instanceof Number && v > 0) { return v; }
        } catch (e) { }
        return 0;
    }
    function saveHi() {
        try { Application.Storage.setValue(DR_HI_KEY, hi); } catch (e) { }
    }

    // Registers a successful chop at `nowMs`. Consecutive chops inside
    // COMBO_WINDOW_MS build a streak that adds bonus points on top of
    // the flat +1 — rewards fast continuous chopping without punishing
    // a slower, more careful pace.
    function registerChop(nowMs) {
        var dt = nowMs - _lastChopMs;
        if (dt >= 0 && dt < COMBO_WINDOW_MS) {
            combo = combo + 1;
        } else {
            combo = 0;
        }
        _lastChopMs = nowMs;

        var bonus = combo;
        if (bonus > COMBO_CAP) { bonus = COMBO_CAP; }
        var pts = 1 + bonus;
        score = score + pts;
        if (score > hi) { hi = score; }
        return pts;
    }
}
