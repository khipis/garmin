using Toybox.Application;
using Toybox.WatchUi;

class BitochiParachuteApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
        Leaderboard.logLaunch("parachute");
    }

    function onStop(state) {
    }

    function getInitialView() {
        // Root view is the shared unified menu; START launches the jump.
        return buildParachuteMenu();
    }
}
