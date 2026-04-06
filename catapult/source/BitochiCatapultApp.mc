using Toybox.Application;
using Toybox.WatchUi;

class BitochiCatapultApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
    }

    function onStop(state) {
    }

    function getInitialView() {
        var view = new BitochiCatapultView();
        return [view, new BitochiCatapultDelegate(view)];
    }
}
