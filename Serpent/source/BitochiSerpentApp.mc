using Toybox.Application;
using Toybox.WatchUi;

class BitochiSerpentApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) {}
    function onStop(state) {}
    function getInitialView() {
        var view = new BitochiSerpentView();
        return [view, new BitochiSerpentDelegate(view)];
    }
}
