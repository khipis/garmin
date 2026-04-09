using Toybox.Application;
using Toybox.WatchUi;

class BitochiBricksApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) {}
    function onStop(state) {}
    function getInitialView() {
        var view = new BitochiBricksView();
        return [view, new BitochiBricksDelegate(view)];
    }
}
