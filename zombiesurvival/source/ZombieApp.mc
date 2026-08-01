using Toybox.Application;
using Toybox.WatchUi;

class ZombieApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) { Leaderboard.logLaunch(Zs.GAME_ID); }
    function onStop(state) {}
    function getInitialView() {
        return buildZombieMenu();
    }
}
