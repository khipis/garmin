using Toybox.Application;
using Toybox.WatchUi;

class DiverCommApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
    }

    function onStop(state) {
    }

    function getInitialView() {
        var view     = new DiverCommView();
        var delegate = new DiverCommDelegate(view);
        return [view, delegate];
    }
}
