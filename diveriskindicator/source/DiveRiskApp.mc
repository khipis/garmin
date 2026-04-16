// DiveRiskApp.mc — application entry point

using Toybox.Application;
using Toybox.WatchUi;

class DiveRiskApp extends Application.AppBase {

    hidden var _view;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) as Void {
    }

    function onStop(state) as Void {
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        _view = new DiveRiskView();
        var delegate = new DiveRiskDelegate(_view);
        return [_view, delegate];
    }
}
