using Toybox.Application;
using Toybox.WatchUi;

class BitochiRunApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
    }

    function onStop(state) {
    }

    function getInitialView() {
        var view = new RunView();
        return [view, new RunDelegate(view)];
    }
}
