using Toybox.Application;
using Toybox.WatchUi;

class DinosaurApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) {}
    function onStop(state) {}
    function getInitialView() {
        var view = new DinosaurView();
        return [view, new DinosaurDelegate(view)];
    }
}
