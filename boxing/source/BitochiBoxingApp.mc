using Toybox.Application;
using Toybox.WatchUi;

class BitochiBoxingApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) {
        Leaderboard.logLaunch("boxing");
        // Advance the daily login streak + grant the daily coin bonus. On the
        // day's first launch, queue a toast the view shows on the first frame.
        try {
            var ci = Progress.checkIn();
            if (ci["first"]) {
                Application.Storage.setValue("box_daily_msg",
                    "Daily +" + ci["bonus"] + "  Streak " + ci["streak"]);
            }
        } catch (e) {}
    }
    function onStop(state) {}
    function getInitialView() {
        // Root view is the shared unified menu; FIGHT launches the game view.
        return buildBoxingMenu();
    }
}
