using Toybox.Application;
using Toybox.WatchUi;

class EdgeSurvivorApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) {
        Leaderboard.logLaunch("edgesurvivor");
        // Advance the daily login streak + grant the daily coin bonus. On the
        // day's first launch, queue a one-shot toast the game view surfaces
        // over the arena. Fully guarded so a Storage hiccup can't crash launch.
        try {
            var ci = Progress.checkIn();
            if (ci["first"]) {
                Application.Storage.setValue("es_daily_msg",
                    "Daily +" + ci["bonus"] + "  Streak " + ci["streak"]);
            }
        } catch (e) {}
    }
    function onStop(state) {}
    function getInitialView() {
        // Root view is the shared unified menu; START launches GameView.
        return buildEdgeSurvivorMenu();
    }
}
