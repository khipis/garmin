// ═══════════════════════════════════════════════════════════════════════════
// FitnessIntegration.mc — What the watch already knows about you, turned into
// opportunity rather than advantage.
//
// Rule of the game: real-world fitness NEVER touches the score. A fitter
// player gets more chances at the daily challenge and more currency for
// cosmetics; they still have to shoot straight to climb the board. Practice
// mode is always unlimited, so a rest day can never lock anyone out.
//
//   steps today      → training points, extra energy (attempts)
//   active minutes   → extra energy
//   calories burned  → bonus coins, once per day
//
// Every accessor degrades to 0 on devices without ActivityMonitor.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.ActivityMonitor;
using Toybox.Lang;

module FitnessIntegration {

    const BASE_ENERGY = 3;    // everyone gets these, fitness or not
    const MAX_ENERGY  = 8;

    function steps() as Lang.Number {
        try {
            if (Toybox has :ActivityMonitor) {
                var info = ActivityMonitor.getInfo();
                if (info != null && info has :steps && info.steps != null) {
                    return info.steps;
                }
            }
        } catch (e) {}
        return 0;
    }

    function activeMinutes() as Lang.Number {
        try {
            if (Toybox has :ActivityMonitor) {
                var info = ActivityMonitor.getInfo();
                if (info != null) {
                    if (info has :activeMinutesDay && info.activeMinutesDay != null &&
                        info.activeMinutesDay has :total &&
                        info.activeMinutesDay.total != null) {
                        return info.activeMinutesDay.total;
                    }
                }
            }
        } catch (e) {}
        return 0;
    }

    function calories() as Lang.Number {
        try {
            if (Toybox has :ActivityMonitor) {
                var info = ActivityMonitor.getInfo();
                if (info != null && info has :calories && info.calories != null) {
                    return info.calories;
                }
            }
        } catch (e) {}
        return 0;
    }

    // Training points — the cosmetic "you moved today" number on the briefing.
    function trainingPoints() as Lang.Number { return steps() / 100; }

    // Extra daily attempts earned by moving: up to +3 from steps, +2 from
    // active minutes.
    function energyBonus() as Lang.Number {
        var b = steps() / 4000;
        if (b > 3) { b = 3; }
        var a = activeMinutes() / 20;
        if (a > 2) { a = 2; }
        return b + a;
    }

    function dailyEnergy() as Lang.Number {
        var e = BASE_ENERGY + energyBonus();
        if (e > MAX_ENERGY) { e = MAX_ENERGY; }
        return e;
    }

    // Once-a-day currency drop for cosmetics — never for score.
    function bonusCoins() as Lang.Number {
        var c = calories() / 100;
        if (c > 20) { c = 20; }
        return c;
    }

    // Short line for the briefing card, e.g. "8.4k steps  +3 energy".
    function summary() as Lang.String {
        var s = steps();
        var txt;
        if (s >= 1000) {
            txt = (s / 1000).toString() + "." + ((s % 1000) / 100).toString() + "k steps";
        } else {
            txt = s.toString() + " steps";
        }
        var b = energyBonus();
        if (b > 0) { txt = txt + "  +" + b.toString() + " energy"; }
        return txt;
    }
}
