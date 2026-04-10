using Toybox.Application;
using Toybox.WatchUi;

class BitochiBlocksApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) {}
    function onStop(state) {}
    function getInitialView() {
        var view = new BitochiBlocksView();
        return [view, new BitochiBlocksDelegate(view)];
    }
}
