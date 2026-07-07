using Toybox.Application;
using Toybox.WatchUi;

class OthelloApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) { Leaderboard.logLaunch("othello"); }
    function onStop(state) {}
    function getInitialView() {
        // Root view is the shared unified menu; START launches GameView.
        return buildOthelloMenu();
    }
}
