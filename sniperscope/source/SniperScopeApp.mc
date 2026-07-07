// ═══════════════════════════════════════════════════════════════
// SniperScopeApp.mc — Application entry point.
// ═══════════════════════════════════════════════════════════════

using Toybox.Application;

class SniperScopeApp extends Application.AppBase {
    function initialize()   { AppBase.initialize(); }
    function onStart(state) { Leaderboard.logLaunch("sniperscope"); }
    function onStop(state)  {}

    function getInitialView() {
        // Root view is the shared unified menu; START launches MainView.
        return buildSniperScopeMenu();
    }
}
