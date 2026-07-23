// ═══════════════════════════════════════════════════════════════
// FlappyPidgeonApp.mc — Application entry point.
// ═══════════════════════════════════════════════════════════════
using Toybox.Application;
using Toybox.WatchUi;

class FlappyPidgeonApp extends Application.AppBase {
    function initialize()    { AppBase.initialize(); }
    function onStart(state)  {
        Leaderboard.logLaunch("flappypidgeon");
        // Advance the daily login streak + grant the daily coin bonus. On the
        // day's first launch, queue a toast the game view shows once over the sky.
        try {
            var ci = Progress.checkIn();
            if (ci["first"]) {
                Application.Storage.setValue("fp_daily_msg",
                    "Daily +" + ci["bonus"] + "  Streak " + ci["streak"]);
            }
        } catch (e) {}
    }
    function onStop(state)   {}

    function getInitialView() {
        return buildFlappyMenu();
    }
}
