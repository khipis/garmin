// ═══════════════════════════════════════════════════════════════
// PinballProApp.mc — Application entry point.
// ═══════════════════════════════════════════════════════════════
using Toybox.Application;
using Toybox.WatchUi;

class PinballProApp extends Application.AppBase {
    function initialize()    { AppBase.initialize(); }
    function onStart(state)  { Leaderboard.logLaunch("pinballpro"); }
    function onStop(state)   {}

    function getInitialView() {
        return buildPinballProMenu();
    }
}
