// ═══════════════════════════════════════════════════════════════════════════
// Sensors.mc — Garmin sensor hooks for BITOCHI CREATURES.
//
// Reads real device data where the platform exposes it, and degrades to safe
// neutral values everywhere else. These feed creature growth and steer the
// evolution path (steps→Runner, training→Warrior, sleep→Dreamer, HR→Dynamo).
//
// Every accessor is fully guarded: a missing capability or a firmware quirk
// must NEVER throw into the game loop — it just returns 0 / a placeholder.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.ActivityMonitor;
using Toybox.Activity;
using Toybox.Lang;

module Sensors {

    // Steps recorded so far today. Drives growth + movement mutations.
    function getStepsToday() as Lang.Number {
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

    // Current heart rate (bpm) or 0 when unavailable. Influences energy traits.
    function getHeartRate() as Lang.Number {
        try {
            if (Toybox has :Activity) {
                var a = Activity.getActivityInfo();
                if (a != null && a has :currentHeartRate && a.currentHeartRate != null) {
                    return a.currentHeartRate;
                }
            }
        } catch (e) {}
        try {
            if (Toybox has :ActivityMonitor && ActivityMonitor has :getHeartRateHistory) {
                var it = ActivityMonitor.getHeartRateHistory(1, true);
                if (it != null) {
                    var s = it.next();
                    if (s != null && s.heartRate != null &&
                        s.heartRate != ActivityMonitor.INVALID_HR_SAMPLE) {
                        return s.heartRate;
                    }
                }
            }
        } catch (e) {}
        return 0;
    }

    // Sleep proxy in minutes. The on-device SDK does not expose scored sleep to
    // 3rd-party apps, so we approximate "recovery" from yesterday's inactivity
    // budget and return minutes of rest. Placeholder — safe on every device.
    function getSleepData() as Lang.Number {
        try {
            if (Toybox has :ActivityMonitor) {
                var info = ActivityMonitor.getInfo();
                // moveBarLevel low => the wearer has been resting → treat as recovery.
                if (info != null && info has :moveBarLevel && info.moveBarLevel != null) {
                    var rest = ActivityMonitor.MOVE_BAR_LEVEL_MAX - info.moveBarLevel;
                    if (rest < 0) { rest = 0; }
                    return rest * 90;   // ~0..7h proxy
                }
            }
        } catch (e) {}
        return 0;
    }

    // Active/intensity minutes today (weekly figure / 7 as a daily proxy).
    // Unlocks evolution bonuses.
    function getActivityMinutes() as Lang.Number {
        try {
            if (Toybox has :ActivityMonitor) {
                var info = ActivityMonitor.getInfo();
                if (info != null) {
                    var mins = 0;
                    if (info has :activeMinutesDay && info.activeMinutesDay != null &&
                        info.activeMinutesDay has :total && info.activeMinutesDay.total != null) {
                        mins = info.activeMinutesDay.total;
                    } else if (info has :activeMinutesWeek && info.activeMinutesWeek != null &&
                               info.activeMinutesWeek has :total && info.activeMinutesWeek.total != null) {
                        mins = info.activeMinutesWeek.total / 7;
                    }
                    return mins;
                }
            }
        } catch (e) {}
        return 0;
    }

    // A single small, non-negative "activity mix" hint used at hatch/evolution
    // to bias the evolution path. Returns the dominant PATH_* constant (or
    // PATH_NONE when the watch is quiet / offline).
    function dominantPath() as Lang.Number {
        var steps = getStepsToday();
        var hr    = getHeartRate();
        var sleep = getSleepData();
        var act   = getActivityMinutes();

        // Normalise each signal to a rough 0..100 score.
        var sSteps = steps / 120;          // 12000 steps -> 100
        var sHr    = (hr > 60) ? (hr - 60) * 2 : 0;   // 110bpm -> 100
        var sSleep = sleep / 5;            // ~500min rest -> 100
        var sAct   = act * 2;              // 50min -> 100

        var best = 0; var bestPath = Cr.PATH_NONE;
        if (sSteps > best) { best = sSteps; bestPath = Cr.PATH_RUNNER; }
        if (sAct   > best) { best = sAct;   bestPath = Cr.PATH_WARRIOR; }
        if (sSleep > best) { best = sSleep; bestPath = Cr.PATH_DREAM; }
        if (sHr    > best) { best = sHr;    bestPath = Cr.PATH_ENERGY; }
        if (best < 20) { return Cr.PATH_NONE; }
        return bestPath;
    }
}
