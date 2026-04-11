using Toybox.Application;
using Toybox.WatchUi;

class BitochiCheckersApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) {}
    function onStop(state) {}
    function getInitialView() {
        var view = new BitochiCheckersView();
        return [view, new BitochiCheckersDelegate(view)];
    }
}
