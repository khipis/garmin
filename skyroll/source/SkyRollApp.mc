// ═══════════════════════════════════════════════════════════════
// SkyRollApp.mc — Application entry point.
// ═══════════════════════════════════════════════════════════════

using Toybox.Application;

class SkyRollApp extends Application.AppBase {
    function initialize()   { AppBase.initialize(); }
    function onStart(state) { Leaderboard.logLaunch("skyroll"); }
    function onStop(state)  {}

    function getInitialView() {
        var v = new MainView();
        return [v, new InputHandler(v)];
    }
}
