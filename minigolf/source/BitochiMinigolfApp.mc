using Toybox.Application;
using Toybox.WatchUi;

class BitochiMinigolfApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) {}
    function onStop(state) {}
    function getInitialView() {
        var view = new BitochiMinigolfView();
        return [view, new BitochiMinigolfDelegate(view)];
    }
}
