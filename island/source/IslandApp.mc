using Toybox.Application;
using Toybox.WatchUi;

class IslandApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) { Leaderboard.logLaunch(Is.GAME_ID); }
    function onStop(state) {}
    function getInitialView() {
        // Root view is the shared unified menu; START launches the game.
        return buildIslandMenu();
    }
}
