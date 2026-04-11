using Toybox.Application;
using Toybox.WatchUi;

class BitochiSolitareApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) {}
    function onStop(state) {}
    function getInitialView() {
        var view = new BitochiSolitareView();
        return [view, new BitochiSolitareDelegate(view)];
    }
}
