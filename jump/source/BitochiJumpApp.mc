using Toybox.Application;
using Toybox.WatchUi;

class BitochiJumpApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
    }

    function onStop(state) {
    }

    function getInitialView() {
        var view = new BitochiJumpView();
        return [view, new BitochiJumpDelegate(view)];
    }
}
