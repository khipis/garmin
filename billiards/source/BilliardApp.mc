// ═══════════════════════════════════════════════════════════════
// BilliardApp.mc  —  App entry point
// ═══════════════════════════════════════════════════════════════
using Toybox.Application;
using Toybox.WatchUi;

class BilliardApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state)  { Leaderboard.logLaunch("billiards"); }
    function onStop(state)   {}
    function getInitialView() {
        var v = new BilliardView();
        return [v, new BilliardDelegate(v)];
    }
}
