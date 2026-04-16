// BoatModeApp.mc
using Toybox.Application;
using Toybox.WatchUi;

class BoatModeApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {}
    function onStop(state)  {}

    function getInitialView() {
        var view = new BoatModePlannerView();
        var delegate = new BoatModeDelegate(view);
        return [view, delegate];
    }
}
