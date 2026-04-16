using Toybox.Application;
using Toybox.WatchUi;

class BitochiTimerApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) {}
    function onStop(state) {}
    function getInitialView() {
        var view = new BitochiTimerView();
        return [view, new BitochiTimerDelegate(view)];
    }
}
