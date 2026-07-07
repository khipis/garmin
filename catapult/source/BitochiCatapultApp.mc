using Toybox.Application;
using Toybox.WatchUi;

class BitochiCatapultApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
        Leaderboard.logLaunch("catapult");
    }

    function onStop(state) {
    }

    function getInitialView() {
        // Root view is the shared unified menu; PLAY launches the game view.
        return buildCatapultMenu();
    }
}
