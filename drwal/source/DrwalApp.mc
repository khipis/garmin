// ═══════════════════════════════════════════════════════════════
// DrwalApp.mc — Application entry point.
// ═══════════════════════════════════════════════════════════════
using Toybox.Application;
using Toybox.WatchUi;

class DrwalApp extends Application.AppBase {
    function initialize()   { AppBase.initialize(); }
    function onStart(state) { Leaderboard.logLaunch("drwal"); }
    function onStop(state)  { }

    function getInitialView() {
        return buildDrwalMenu();
    }
}
