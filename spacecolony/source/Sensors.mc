// ═══════════════════════════════════════════════════════════════════════════
// Sensors.mc — Garmin sensor hooks for SPACE COLONY.
//
// Reads real device data where available, degrading to safe neutral values
// everywhere else. Steps drive expeditions & discoveries, workouts add
// expedition bonuses, sleep restores colony morale, heart rate feeds activity.
// Every accessor is fully guarded so a missing capability or firmware quirk can
// never throw into the game loop — it just returns 0.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.ActivityMonitor;
using Toybox.Activity;
using Toybox.Lang;

module Sensors {

    // Steps recorded so far today. Drives expeditions & territory discovery.
    function getStepsToday() as Lang.Number {
        try {
            if (Toybox has :ActivityMonitor) {
                var info = ActivityMonitor.getInfo();
                if (info != null && info has :steps && info.steps != null) { return info.steps; }
            }
        } catch (e) {}
        return 0;
    }

    // Current heart rate (bpm) or 0. Feeds "colony activity" bonus.
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
                        s.heartRate != ActivityMonitor.INVALID_HR_SAMPLE) { return s.heartRate; }
                }
            }
        } catch (e) {}
        return 0;
    }

    // Rest/recovery proxy in minutes (SDK exposes no scored sleep to apps).
    // Restores colony morale on return.
    function getSleepData() as Lang.Number {
        try {
            if (Toybox has :ActivityMonitor) {
                var info = ActivityMonitor.getInfo();
                if (info != null && info has :moveBarLevel && info.moveBarLevel != null) {
                    var rest = ActivityMonitor.MOVE_BAR_LEVEL_MAX - info.moveBarLevel;
                    if (rest < 0) { rest = 0; }
                    return rest * 90;
                }
            }
        } catch (e) {}
        return 0;
    }

    // Active/intensity minutes today. Adds expedition success bonus.
    function getActivityMinutes() as Lang.Number {
        try {
            if (Toybox has :ActivityMonitor) {
                var info = ActivityMonitor.getInfo();
                if (info != null) {
                    if (info has :activeMinutesDay && info.activeMinutesDay != null &&
                        info.activeMinutesDay has :total && info.activeMinutesDay.total != null) {
                        return info.activeMinutesDay.total;
                    }
                    if (info has :activeMinutesWeek && info.activeMinutesWeek != null &&
                        info.activeMinutesWeek has :total && info.activeMinutesWeek.total != null) {
                        return info.activeMinutesWeek.total / 7;
                    }
                }
            }
        } catch (e) {}
        return 0;
    }
}
