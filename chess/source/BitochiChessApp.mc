using Toybox.Application;
using Toybox.WatchUi;

class BitochiChessApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) { Leaderboard.logLaunch("chess"); }
    function onStop(state) {}
    function getInitialView() {
        // Root view is the shared unified menu; START launches the game view.
        return buildChessMenu();
    }
}
