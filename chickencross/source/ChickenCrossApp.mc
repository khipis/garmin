using Toybox.Application;
using Toybox.WatchUi;

class ChickenCrossApp extends Application.AppBase {
    function initialize()   { AppBase.initialize(); }
    function onStart(state) { Leaderboard.logLaunch("chickencross"); }
    function onStop(state)  {}

    function getInitialView() {
        var v = new MainView();
        return [v, new InputHandler(v)];
    }
}
