using Toybox.Application;
using Toybox.WatchUi;

class BitochiPokerApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) {
        Leaderboard.logLaunch("poker");
        // Advance the daily login streak + grant the daily coin bonus. On the
        // day's first launch, queue a toast the table view shows on first frame.
        try {
            var ci = Progress.checkIn();
            if (ci["first"]) {
                Application.Storage.setValue("pk_daily_msg",
                    "Daily +" + ci["bonus"] + "  Streak " + ci["streak"]);
            }
        } catch (e) {}
    }
    function onStop(state) {}
    function getInitialView() {
        // Root view is the shared unified menu; START launches the table.
        return buildPokerMenu();
    }
}
