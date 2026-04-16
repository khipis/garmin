using Toybox.Application;
using Toybox.WatchUi;

class DiveGasBlenderApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
    }

    function onStop(state) {
    }

    function getInitialView() {
        var view     = new DiveGasBlenderView();
        var delegate = new DiveGasBlenderDelegate(view);
        return [view, delegate];
    }
}
