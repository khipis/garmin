using Toybox.Application;
using Toybox.WatchUi;

class BitochiJazzBallApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) { Leaderboard.logLaunch("jazzball"); }
    function onStop(state) {}
    function getInitialView() {
        // Root view is the shared unified menu; START launches the game.
        return buildJazzBallMenu();
    }
}
