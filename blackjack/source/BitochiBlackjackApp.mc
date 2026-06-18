using Toybox.Application;
using Toybox.WatchUi;

class BitochiBlackjackApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) { Leaderboard.logLaunch("blackjack"); }
    function onStop(state) {}
    function getInitialView() {
        var view = new BitochiBlackjackView();
        return [view, new BitochiBlackjackDelegate(view)];
    }
}
