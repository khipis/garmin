// ═══════════════════════════════════════════════════════════════
// BattleshipApp.mc — Application entry point.
// ═══════════════════════════════════════════════════════════════
using Toybox.Application;
using Toybox.WatchUi;

class BattleshipApp extends Application.AppBase {
    function initialize()    { AppBase.initialize(); }
    function onStart(state)  {
        Leaderboard.logLaunch("battleship");
        // Advance the shared daily login streak + grant the daily coin
        // bonus exactly once per launch. On the day's first launch, queue
        // a toast the MainView surfaces once as a lightweight banner.
        try {
            var ci = Progress.checkIn();
            if (ci["first"]) {
                Application.Storage.setValue("bs_daily_msg",
                    "Daily +" + ci["bonus"] + "  Streak " + ci["streak"]);
            }
        } catch (e) {}
    }
    function onStop(state)   {}

    function getInitialView() {
        return buildBattleshipMenu();
    }
}
