using Toybox.Application;
using Toybox.WatchUi;

class BitochiBricksApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) { Leaderboard.logLaunch("bricks"); }
    function onStop(state) {}
    function getInitialView() {
        // Root view is the shared unified menu; PLAY launches the game view.
        return buildBricksMenu();
    }
}
