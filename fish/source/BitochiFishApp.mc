using Toybox.Application;
using Toybox.WatchUi;

class BitochiFishApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) { Leaderboard.logLaunch("fish"); }
    function onStop(state) {}
    function getInitialView() {
        // Root view is the shared unified menu; START launches the session.
        return buildFishMenu();
    }
}
