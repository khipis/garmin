using Toybox.Application;
using Toybox.WatchUi;

class BitochiJumpApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
        Leaderboard.logLaunch("skijump");
    }

    function onStop(state) {
    }

    function getInitialView() {
        // Root view is the shared unified menu; START launches the competition.
        return buildSkiJumpMenu();
    }
}
