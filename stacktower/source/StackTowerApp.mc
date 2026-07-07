// ═══════════════════════════════════════════════════════════════
// StackTowerApp.mc — Application entry point.
// ═══════════════════════════════════════════════════════════════
using Toybox.Application;
using Toybox.WatchUi;

class StackTowerApp extends Application.AppBase {
    function initialize()    { AppBase.initialize(); }
    function onStart(state)  { Leaderboard.logLaunch("stacktower"); }
    function onStop(state)   {}

    function getInitialView() {
        // Root view is the shared unified menu; START launches MainView.
        return buildStackTowerMenu();
    }
}
