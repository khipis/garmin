using Toybox.Application;
using Toybox.WatchUi;

// ─────────────────────────────────────────────────────────────────────────────
//  Bitochi Moon Lander — classic lunar landing game for Garmin watches
// ─────────────────────────────────────────────────────────────────────────────

class BitochiMoonApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) {
        Leaderboard.logLaunch("moon");
        // Advance the daily login streak + grant the daily coin bonus. On the
        // day's first launch, queue a toast the game view shows over the moon.
        try {
            var ci = Progress.checkIn();
            if (ci["first"]) {
                Application.Storage.setValue("moon_daily_msg",
                    "Daily +" + ci["bonus"] + "  Streak " + ci["streak"]);
            }
        } catch (e) {}
    }
    function onStop(state) {}
    function getInitialView() {
        // Root view is the shared unified menu; START launches the lander.
        return buildMoonMenu();
    }
}
