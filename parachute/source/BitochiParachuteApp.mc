using Toybox.Application;
using Toybox.WatchUi;

class BitochiParachuteApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
    }

    function onStop(state) {
    }

    function getInitialView() {
        var view = new BitochiParachuteView();
        return [view, new BitochiParachuteDelegate(view)];
    }
}
