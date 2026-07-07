using Toybox.Application;
using Toybox.WatchUi;

class MorrisClassicApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) { Leaderboard.logLaunch("morris_classic"); }
    function onStop(state) {}
    function getInitialView() {
        // Root view is the shared unified menu; START launches GameView.
        return buildMorrisMenu();
    }
}
