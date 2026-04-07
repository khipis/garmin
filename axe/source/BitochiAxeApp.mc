using Toybox.Application;
using Toybox.WatchUi;

class BitochiAxeApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {}
    function onStop(state) {}

    function getInitialView() {
        var view = new BitochiAxeView();
        return [view, new BitochiAxeDelegate(view)];
    }
}
