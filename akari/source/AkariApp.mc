// ═══════════════════════════════════════════════════════════════
// AkariApp.mc — Application entry point.
// ═══════════════════════════════════════════════════════════════

using Toybox.Application;

class AkariApp extends Application.AppBase {
    function initialize()   { AppBase.initialize(); }
    function onStart(state) { Leaderboard.logLaunch("akari"); }
    function onStop(state)  {}

    function getInitialView() {
        return buildAkariMenu();
    }
}
