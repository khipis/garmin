// ═══════════════════════════════════════════════════════════════
// StackTowerApp.mc — Application entry point.
// ═══════════════════════════════════════════════════════════════
using Toybox.Application;
using Toybox.WatchUi;

class StackTowerApp extends Application.AppBase {
    function initialize()    { AppBase.initialize(); }
    function onStart(state)  {
        Leaderboard.logLaunch("stacktower");
        // Advance the daily login streak + grant the daily coin bonus once per
        // launch. On the day's first launch, queue a one-shot toast the game
        // view surfaces over the first frame (no new blocking view).
        try {
            var ci = Progress.checkIn();
            if (ci["first"]) {
                Application.Storage.setValue("st_daily_msg",
                    "Daily +" + ci["bonus"] + "  Streak " + ci["streak"]);
            }
        } catch (e) {}
    }
    function onStop(state)   {}

    function getInitialView() {
        // Root view is the shared unified menu; START launches MainView.
        return buildStackTowerMenu();
    }
}
