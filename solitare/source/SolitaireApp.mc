using Toybox.Application;
using Toybox.WatchUi;

class SolitaireApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) { Leaderboard.logLaunch("solitaire"); }
    function onStop(state) {}
    function getInitialView() {
        // Root view is the shared unified menu; START deals a new game.
        return buildSolitaireMenu();
    }
}
