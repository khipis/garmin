using Toybox.Application;
using Toybox.WatchUi;

class EdgeSurvivorApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) { Leaderboard.logLaunch("edgesurvivor"); }
    function onStop(state) {}
    function getInitialView() {
        var v = new GameView();
        return [v, new GameDelegate(v)];
    }
}
