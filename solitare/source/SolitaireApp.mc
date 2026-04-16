using Toybox.Application;
using Toybox.WatchUi;

class SolitaireApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) {}
    function onStop(state) {}
    function getInitialView() {
        var view = new SolitaireView();
        return [view, new SolitaireDelegate(view)];
    }
}
