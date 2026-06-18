// ═══════════════════════════════════════════════════════════════
// DiceRoyaleApp.mc — Application entry point.
// ═══════════════════════════════════════════════════════════════

using Toybox.Application;

class DiceRoyaleApp extends Application.AppBase {
    function initialize()   { AppBase.initialize(); }
    function onStart(state) { Leaderboard.logLaunch("diceroyale"); }
    function onStop(state)  {}

    function getInitialView() {
        var v = new MainView();
        return [v, new InputHandler(v)];
    }
}
