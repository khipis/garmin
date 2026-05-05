using Toybox.Application;
using Toybox.WatchUi;

class CellWarsApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) {}
    function onStop(state) {}
    function getInitialView() {
        var view = new CellWarsView();
        return [view, new CellWarsDelegate(view)];
    }
}
