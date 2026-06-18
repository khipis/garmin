// ═══════════════════════════════════════════════════════════════
// PixelInvadersApp.mc — Application entry point.
// ═══════════════════════════════════════════════════════════════

using Toybox.Application;

class PixelInvadersApp extends Application.AppBase {
    function initialize()   { AppBase.initialize(); }
    function onStart(state) { Leaderboard.logLaunch("pixelinvaders"); }
    function onStop(state)  {}

    function getInitialView() {
        var v = new MainView();
        return [v, new InputHandler(v)];
    }
}
