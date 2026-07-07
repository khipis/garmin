using Toybox.Application;
using Toybox.WatchUi;

class CellWarsApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) { Leaderboard.logLaunch("cellwars"); }
    function onStop(state) {}
    function getInitialView() {
        return buildCellWarsMenu();
    }
}
