// ═══════════════════════════════════════════════════════════════
// LightsOutApp.mc — Application entry point.
// ═══════════════════════════════════════════════════════════════

using Toybox.Application;

class LightsOutApp extends Application.AppBase {
    function initialize()   { AppBase.initialize(); }
    function onStart(state) { Leaderboard.logLaunch("lightsout"); }
    function onStop(state)  {}

    function getInitialView() {
        var v = new MainView();
        return [v, new InputHandler(v)];
    }
}
