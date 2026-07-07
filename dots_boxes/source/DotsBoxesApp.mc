using Toybox.Application;
using Toybox.WatchUi;

class DotsBoxesApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) { Leaderboard.logLaunch("dots_boxes"); }
    function onStop(state) {}
    function getInitialView() {
        // Root view is the shared unified menu; START launches GameView.
        return buildDotsBoxesMenu();
    }
}
