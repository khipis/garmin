// ═══════════════════════════════════════════════════════════════
// DrwalApp.mc — Application entry point.
// ═══════════════════════════════════════════════════════════════
using Toybox.Application;
using Toybox.WatchUi;

class DrwalApp extends Application.AppBase {
    function initialize()   { AppBase.initialize(); }
    function onStart(state) {
        Leaderboard.logLaunch("drwal");
        // Advance the daily login streak + grant the daily coin bonus ONCE per
        // launch. On the day's first launch, queue a lightweight toast the game
        // view surfaces over the first frame (no blocking/modal view).
        try {
            var ci = Progress.checkIn();
            if (ci["first"]) {
                Application.Storage.setValue("dr_daily_msg",
                    "Daily +" + ci["bonus"] + "  Streak " + ci["streak"]);
            }
        } catch (e) {}
    }
    function onStop(state)  { }

    function getInitialView() {
        return buildDrwalMenu();
    }
}
