// ═══════════════════════════════════════════════════════════════
// ScoreSystem.mc — Round score, spin budget, jackpot count,
// persisted best score (per round length).
// ═══════════════════════════════════════════════════════════════
using Toybox.Application;

class ScoreSystem {
    var score;
    var spinsUsed;
    var spinsTotal;
    var jackpots;
    var hi;

    function initialize() {
        hi = 0;
        score = 0; spinsUsed = 0; spinsTotal = 10; jackpots = 0;
    }

    function reset(totalSpins) {
        score      = 0;
        spinsUsed  = 0;
        spinsTotal = totalSpins;
        jackpots   = 0;
    }

    function loadHi(key) {
        try {
            var v = Application.Storage.getValue(key);
            if (v != null && v instanceof Number && v >= 0) { hi = v; return; }
        } catch (e) { }
        hi = 0;
    }
    function saveHi(key) {
        try { Application.Storage.setValue(key, hi); } catch (e) { }
    }

    // Registers one resolved spin's payout, returns the points it added.
    function registerResult(result) {
        var pts = result["payout"];
        score = score + pts;
        if (result["kind"] == "JACKPOT") { jackpots = jackpots + 1; }
        spinsUsed = spinsUsed + 1;
        return pts;
    }

    // Registers a resolved spin using an already multiplier-adjusted gain
    // (combo streak applied by the controller). Returns the points added.
    function registerResultGain(result, gain) {
        score = score + gain;
        if (result["kind"] == "JACKPOT") { jackpots = jackpots + 1; }
        spinsUsed = spinsUsed + 1;
        return gain;
    }

    // Award extra spins (free-spin bonus) without consuming budget.
    function addSpins(n) { spinsTotal = spinsTotal + n; }

    function spinsLeft() {
        var left = spinsTotal - spinsUsed;
        return (left < 0) ? 0 : left;
    }
    function roundOver() { return spinsUsed >= spinsTotal; }
}
