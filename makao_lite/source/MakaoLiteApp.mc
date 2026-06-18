using Toybox.Application;
using Toybox.WatchUi;

class MakaoLiteApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) { Leaderboard.logLaunch("makao_lite"); }
    function onStop(state) {}
    function getInitialView() {
        var v = new GameView();
        return [v, new GameDelegate(v)];
    }
}
