using Toybox.Application;
using Toybox.WatchUi;

class BitochiSerpentApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) {
        Leaderboard.logLaunch("serpent");
        // Advance the daily login streak + grant the daily coin bonus. On the
        // day's first launch, queue a toast the game view surfaces once over
        // the board. Fully guarded — never blocks launch on any device.
        try {
            var ci = Progress.checkIn();
            if (ci["first"]) {
                Application.Storage.setValue("sp_daily_msg",
                    "Daily +" + ci["bonus"] + "  Streak " + ci["streak"]);
            }
        } catch (e) {}
    }
    function onStop(state) {}
    function getInitialView() {
        // Root view is the shared unified menu; START launches the game.
        return buildSerpentMenu();
    }
}
