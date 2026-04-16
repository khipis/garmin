// QuickDiveApp.mc — application entry point

using Toybox.Application;
using Toybox.WatchUi;

class QuickDiveApp extends Application.AppBase {

    hidden var _view;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) as Void {
    }

    function onStop(state) as Void {
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        _view = new QuickDiveView();
        var delegate = new QuickDiveDelegate(_view);
        return [_view, delegate];
    }
}
