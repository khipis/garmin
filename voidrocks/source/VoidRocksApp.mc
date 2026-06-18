// ═══════════════════════════════════════════════════════════════
// VoidRocksApp.mc — Application entry point.
// ═══════════════════════════════════════════════════════════════

using Toybox.Application;

class VoidRocksApp extends Application.AppBase {
    function initialize()   { AppBase.initialize(); }
    function onStart(state) { Leaderboard.logLaunch("voidrocks"); }
    function onStop(state)  {}

    function getInitialView() {
        var v = new MainView();
        return [v, new InputHandler(v)];
    }
}
