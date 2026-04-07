using Toybox.Application;
using Toybox.WatchUi;

class BitochiAxeArcadeApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) {}
    function onStop(state) {}
    function getInitialView() {
        var view = new BitochiAxeArcadeView();
        return [view, new BitochiAxeArcadeDelegate(view)];
    }
}
