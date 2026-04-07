using Toybox.Application;
using Toybox.WatchUi;

class BitochiBoxingApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) {}
    function onStop(state) {}
    function getInitialView() {
        var view = new BitochiBoxingView();
        return [view, new BitochiBoxingDelegate(view)];
    }
}
