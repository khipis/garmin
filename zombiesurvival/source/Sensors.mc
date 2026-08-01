// ═══════════════════════════════════════════════════════════════════════════
// Sensors.mc — ActivityMonitor wrappers for Zombie Survival.
// Steps → scrap; active minutes → daily bonus multiplier scrap.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.ActivityMonitor;
using Toybox.Activity;
using Toybox.Lang;

module Sensors {

    function getStepsToday() as Lang.Number {
        try {
            if (Toybox has :ActivityMonitor) {
                var info = ActivityMonitor.getInfo();
                if (info != null && info has :steps && info.steps != null) { return info.steps; }
            }
        } catch (e) {}
        return 0;
    }

    function getActivityMinutes() as Lang.Number {
        try {
            if (Toybox has :ActivityMonitor) {
                var info = ActivityMonitor.getInfo();
                if (info != null) {
                    if (info has :activeMinutesDay && info.activeMinutesDay != null &&
                        info.activeMinutesDay has :total && info.activeMinutesDay.total != null) {
                        return info.activeMinutesDay.total;
                    }
                }
            }
        } catch (e) {}
        return 0;
    }

    function getHeartRate() as Lang.Number {
        try {
            if (Toybox has :Activity) {
                var a = Activity.getActivityInfo();
                if (a != null && a has :currentHeartRate && a.currentHeartRate != null) {
                    return a.currentHeartRate;
                }
            }
        } catch (e) {}
        return 0;
    }
}
