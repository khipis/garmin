// ═══════════════════════════════════════════════════════════════
// StarCombatApp.mc — Application entry point.
// ═══════════════════════════════════════════════════════════════

using Toybox.Application;

class StarCombatApp extends Application.AppBase {
    function initialize()   { AppBase.initialize(); }
    function onStart(state) { Leaderboard.logLaunch("starcombat"); }
    function onStop(state)  {}

    function getInitialView() {
        // Root view is the shared unified menu; START launches MainView.
        return buildStarCombatMenu();
    }
}
