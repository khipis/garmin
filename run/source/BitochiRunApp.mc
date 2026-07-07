using Toybox.Application;
using Toybox.WatchUi;

class BitochiRunApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
        Leaderboard.logLaunch("run");
    }

    function onStop(state) {
    }

    function getInitialView() {
        // Root view is the shared unified menu; START launches the run.
        return buildRunMenu();
    }
}
