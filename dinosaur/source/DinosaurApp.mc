using Toybox.Application;
using Toybox.WatchUi;

class DinosaurApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) { Leaderboard.logLaunch("dinosaur"); }
    function onStop(state) {}
    function getInitialView() {
        // Root view is the shared unified menu; START launches the run view.
        return buildDinoMenu();
    }
}
