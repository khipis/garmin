using Toybox.Application;
using Toybox.WatchUi;

class BitochiChessApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) {}
    function onStop(state) {}
    function getInitialView() {
        var view = new BitochiChessView();
        return [view, new BitochiChessDelegate(view)];
    }
}
