using Toybox.Application;
using Toybox.WatchUi;

class BitochiBricksApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) {
        Leaderboard.logLaunch("bricks");
        // Advance the daily login streak + grant the daily coin bonus. On the
        // day's first launch, queue a toast the game view shows once over play.
        try {
            var ci = Progress.checkIn();
            if (ci["first"]) {
                Application.Storage.setValue("bricks_daily_msg",
                    "Daily +" + ci["bonus"] + "  Streak " + ci["streak"]);
            }
        } catch (e) {}
    }
    function onStop(state) {}
    function getInitialView() {
        // Root view is the shared unified menu; PLAY launches the game view.
        return buildBricksMenu();
    }
}
