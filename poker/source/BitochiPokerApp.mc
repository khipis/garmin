using Toybox.Application;
using Toybox.WatchUi;

class BitochiPokerApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) {}
    function onStop(state) {}
    function getInitialView() {
        var view = new BitochiPokerView();
        return [view, new BitochiPokerDelegate(view)];
    }
}
