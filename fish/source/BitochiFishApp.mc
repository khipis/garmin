using Toybox.Application;
using Toybox.WatchUi;

class BitochiFishApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) {}
    function onStop(state) {}
    function getInitialView() {
        var view = new BitochiFishView();
        return [view, new BitochiFishDelegate(view)];
    }
}
