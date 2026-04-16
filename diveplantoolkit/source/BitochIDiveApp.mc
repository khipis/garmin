// BitochIDiveApp.mc  (App.mc)
// ─────────────────────────────────────────────────────────────────────────────
// Dive Gas & Planning Toolkit — application entry point
// ─────────────────────────────────────────────────────────────────────────────

using Toybox.Application;
using Toybox.WatchUi;

class BitochIDiveApp extends Application.AppBase {

    hidden var _view;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) as Void {
    }

    function onStop(state) as Void {
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        _view = new DiveView();
        var delegate = new DiveDelegate(_view);
        return [_view, delegate];
    }
}
