using Toybox.Application;
using Toybox.WatchUi;

class MiniGoApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) {}
    function onStop(state) {}
    function getInitialView() {
        var v = new GameView();
        return [v, new GameDelegate(v)];
    }
}
