using Toybox.Application;
using Toybox.WatchUi;

class BitochiBeeperApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) {}
    function onStop(state) {}
    function getInitialView() {
        var view = new BitochiBeeperView();
        return [view, new BitochiBeeperDelegate(view)];
    }
}
