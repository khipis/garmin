// ═══════════════════════════════════════════════════════════════
// StarSwarmApp.mc — Application entry point.
// Returns the MainView + InputHandler pair.
// ═══════════════════════════════════════════════════════════════

using Toybox.Application;

class StarSwarmApp extends Application.AppBase {
    function initialize()   { AppBase.initialize(); }
    function onStart(state) { Leaderboard.logLaunch("starswarm"); }
    function onStop(state)  {}

    function getInitialView() {
        // Root view is the shared unified menu; START launches MainView.
        return buildStarSwarmMenu();
    }
}
