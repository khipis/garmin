using Toybox.Application;
using Toybox.WatchUi;

class SolitaireApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) {
        Leaderboard.logLaunch("solitaire");
        // Advance the daily login streak + grant the daily coin bonus. On the
        // day's first launch, queue a toast the game view shows on first frame.
        try {
            var ci = Progress.checkIn();
            if (ci["first"]) {
                Application.Storage.setValue("sol_daily_msg",
                    "Daily +" + ci["bonus"] + "  Streak " + ci["streak"]);
            }
        } catch (e) {}
    }
    function onStop(state) {}
    function getInitialView() {
        // Root view is the shared unified menu; START deals a new game.
        return buildSolitaireMenu();
    }
}
