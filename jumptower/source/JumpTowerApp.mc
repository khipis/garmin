// ═══════════════════════════════════════════════════════════════
// JumpTowerApp.mc — Application entry point.
// ═══════════════════════════════════════════════════════════════
using Toybox.Application;
using Toybox.WatchUi;

class JumpTowerApp extends Application.AppBase {
    function initialize()    { AppBase.initialize(); }
    function onStart(state)  { Leaderboard.logLaunch("jumptower"); }
    function onStop(state)   {}

    function getInitialView() {
        var v = new MainView();
        return [v, new InputHandler(v)];
    }
}
