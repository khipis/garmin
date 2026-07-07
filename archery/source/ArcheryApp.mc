// ═══════════════════════════════════════════════════════════════
// ArcheryApp.mc — Application entry point.
// ═══════════════════════════════════════════════════════════════

using Toybox.Application;

class ArcheryApp extends Application.AppBase {
    function initialize()   { AppBase.initialize(); }
    function onStart(state) { Leaderboard.logLaunch("archery"); }
    function onStop(state)  {}

    function getInitialView() {
        return buildArcheryMenu();
    }
}
