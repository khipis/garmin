// ═══════════════════════════════════════════════════════════════
// FlappyPidgeonApp.mc — Application entry point.
// ═══════════════════════════════════════════════════════════════
using Toybox.Application;
using Toybox.WatchUi;

class FlappyPidgeonApp extends Application.AppBase {
    function initialize()    { AppBase.initialize(); }
    function onStart(state)  { Leaderboard.logLaunch("flappypidgeon"); }
    function onStop(state)   {}

    function getInitialView() {
        return buildFlappyMenu();
    }
}
