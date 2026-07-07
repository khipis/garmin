// ═══════════════════════════════════════════════════════════════
// GemMatchApp.mc — Application entry-point.
// ═══════════════════════════════════════════════════════════════
using Toybox.Application;
using Toybox.WatchUi;

class GemMatchApp extends Application.AppBase {
    function initialize()    { AppBase.initialize(); }
    function onStart(state)  { Leaderboard.logLaunch("gemmatch"); }
    function onStop(state)   {}

    function getInitialView() {
        return buildGemMatchMenu();
    }
}
