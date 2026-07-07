using Toybox.Application;
using Toybox.WatchUi;

class GobbletMiniApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) { Leaderboard.logLaunch("gobblet_mini"); }
    function onStop(state) {}
    function getInitialView() {
        // Root view is the shared unified menu; START launches GameView.
        return buildGobbletMenu();
    }
}
