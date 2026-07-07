// ═══════════════════════════════════════════════════════════════
// PongProApp.mc — Application entry point.
// ═══════════════════════════════════════════════════════════════
using Toybox.Application;
using Toybox.WatchUi;

class PongProApp extends Application.AppBase {
    function initialize()    { AppBase.initialize(); }
    function onStart(state)  { Leaderboard.logLaunch("pongpro"); }
    function onStop(state)   {}

    function getInitialView() {
        // Root view is the shared unified menu; START launches MainView.
        return buildPongMenu();
    }
}
