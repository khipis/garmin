// ═══════════════════════════════════════════════════════════════
// NonogramApp.mc — Application entry point.
// ═══════════════════════════════════════════════════════════════

using Toybox.Application;

class NonogramApp extends Application.AppBase {
    function initialize()   { AppBase.initialize(); }
    function onStart(state) { Leaderboard.logLaunch("nonogram"); }
    function onStop(state)  {}

    function getInitialView() {
        var v = new MainView();
        return [v, new InputHandler(v)];
    }
}
