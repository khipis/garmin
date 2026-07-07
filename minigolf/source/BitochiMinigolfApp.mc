using Toybox.Application;
using Toybox.WatchUi;

class BitochiMinigolfApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) { Leaderboard.logLaunch("minigolf"); }
    function onStop(state) {}
    function getInitialView() {
        // Root view is the shared unified menu; START launches the round.
        return buildMinigolfMenu();
    }
}
