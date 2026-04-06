using Toybox.Application;
using Toybox.WatchUi;

class BitochiSkywalkerApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
    }

    function onStop(state) {
    }

    function getInitialView() {
        var view = new BitochiSkywalkerView();
        return [view, new BitochiSkywalkerDelegate(view)];
    }
}
