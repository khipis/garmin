using Toybox.Application;
using Toybox.WatchUi;

class TerritoryClashApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) { Leaderboard.logLaunch("territory_clash"); }
    function onStop(state) {}
    function getInitialView() {
        // Root view is the shared unified menu; START launches GameView.
        return buildTerritoryMenu();
    }
}
