// ═══════════════════════════════════════════════════════════════
// JumpTowerApp.mc — Application entry point.
// ═══════════════════════════════════════════════════════════════
using Toybox.Application;
using Toybox.WatchUi;

class JumpTowerApp extends Application.AppBase {
    function initialize()    { AppBase.initialize(); }
    function onStart(state)  {
        Leaderboard.logLaunch("jumptower");
        // Advance the daily login streak + grant the daily coin bonus once per
        // launch. On the day's first launch, queue a one-shot toast the game
        // view surfaces over the first frame (no new blocking view).
        try {
            var ci = Progress.checkIn();
            if (ci["first"]) {
                Application.Storage.setValue("jt_daily_msg",
                    "Daily +" + ci["bonus"] + "  Streak " + ci["streak"]);
            }
        } catch (e) {}
    }
    function onStop(state)   {}

    function getInitialView() {
        return buildJumpTowerMenu();
    }
}
