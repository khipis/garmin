using Toybox.Application;
using Toybox.WatchUi;

class BitochiSniperApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
    }

    function onStop(state) {
    }

    function getInitialView() {
        var view = new BitochiSniperView();
        return [view, new BitochiSniperDelegate(view)];
    }
}
