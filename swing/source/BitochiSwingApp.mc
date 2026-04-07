using Toybox.Application;
using Toybox.WatchUi;

class BitochiSwingApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) {}
    function onStop(state) {}
    function getInitialView() {
        var view = new BitochiSwingView();
        return [view, new BitochiSwingDelegate(view)];
    }
}
