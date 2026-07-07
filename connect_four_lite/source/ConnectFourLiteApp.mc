using Toybox.Application;
using Toybox.WatchUi;

class ConnectFourLiteApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) { Leaderboard.logLaunch("connectfour"); }
    function onStop(state) {}
    function getInitialView() {
        // Root view is the shared unified menu; START launches GameView.
        return buildConnectFourMenu();
    }
}
