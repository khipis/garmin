// ═══════════════════════════════════════════════════════════════
// VoidRocksApp.mc — Application entry point.
// ═══════════════════════════════════════════════════════════════

using Toybox.Application;

class VoidRocksApp extends Application.AppBase {
    function initialize()   { AppBase.initialize(); }
    function onStart(state) { Leaderboard.logLaunch("voidrocks"); }
    function onStop(state)  {}

    function getInitialView() {
        // Root view is the shared unified menu; START launches MainView.
        return buildVoidRocksMenu();
    }
}
