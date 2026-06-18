// ═══════════════════════════════════════════════════════════════
// KakuroApp.mc — Application entry point.
// ═══════════════════════════════════════════════════════════════

using Toybox.Application;

class KakuroApp extends Application.AppBase {
    function initialize()   { AppBase.initialize(); }
    function onStart(state) { Leaderboard.logLaunch("kakuro"); }
    function onStop(state)  {}

    function getInitialView() {
        var v = new MainView();
        return [v, new InputHandler(v)];
    }
}
