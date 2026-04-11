using Toybox.Application;
using Toybox.WatchUi;

class BitochiJazzBallApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) {}
    function onStop(state) {}
    function getInitialView() {
        var view = new BitochiJazzBallView();
        return [view, new BitochiJazzBallDelegate(view)];
    }
}
