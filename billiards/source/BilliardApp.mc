// ═══════════════════════════════════════════════════════════════
// BilliardApp.mc  —  App entry point
// ═══════════════════════════════════════════════════════════════
using Toybox.Application;
using Toybox.WatchUi;

class BilliardApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state)  {
        Leaderboard.logLaunch("billiards");
        // Advance the daily login streak + grant the daily coin bonus. On the
        // day's first launch, queue a toast the game view shows over the table.
        try {
            var ci = Progress.checkIn();
            if (ci["first"]) {
                Application.Storage.setValue("bill_daily_msg",
                    "Daily +" + ci["bonus"] + "  Streak " + ci["streak"]);
            }
        } catch (e) {}
    }
    function onStop(state)   {}
    function getInitialView() {
        // Root view is the shared unified menu; START launches the game view.
        return buildBilliardsMenu();
    }
}
