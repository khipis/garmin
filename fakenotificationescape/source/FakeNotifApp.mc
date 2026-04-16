using Toybox.Application;
using Toybox.WatchUi;

class FakeNotifApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) {}
    function onStop(state) {}
    function getInitialView() {
        var view = new FakeNotifView();
        return [view, new FakeNotifDelegate(view)];
    }
}
