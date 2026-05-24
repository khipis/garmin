using Toybox.Application;
using Toybox.WatchUi;

class GravityMinerApp extends Application.AppBase {
    function initialize()   { AppBase.initialize(); }
    function onStart(state) {}
    function onStop(state)  {}

    function getInitialView() {
        var v = new MainView();
        return [v, new InputHandler(v)];
    }
}
