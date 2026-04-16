using Toybox.Application;
using Toybox.WatchUi;

class RecoveryTimerApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) {}
    function onStop(state) {}
    function getInitialView() {
        var view = new RecoveryTimerView();
        return [view, new RecoveryTimerDelegate(view)];
    }
}
