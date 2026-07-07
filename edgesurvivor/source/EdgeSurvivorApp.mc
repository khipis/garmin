using Toybox.Application;
using Toybox.WatchUi;

class EdgeSurvivorApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) { Leaderboard.logLaunch("edgesurvivor"); }
    function onStop(state) {}
    function getInitialView() {
        // Root view is the shared unified menu; START launches GameView.
        return buildEdgeSurvivorMenu();
    }
}
