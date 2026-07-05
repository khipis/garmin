using Toybox.Application;
using Toybox.WatchUi;

class BitochiBombApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
        Leaderboard.logLaunch("bomb");
    }

    function onStop(state) {
    }

    function getInitialView() {
        var view = new BitochiBombView();
        return [view, new BitochiBombDelegate(view)];
    }
}
