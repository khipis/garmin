using Toybox.Application;
using Toybox.WatchUi;

class BitochiPokerApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) { Leaderboard.logLaunch("poker"); }
    function onStop(state) {}
    function getInitialView() {
        // Root view is the shared unified menu; START launches the table.
        return buildPokerMenu();
    }
}
