using Toybox.Application;
using Toybox.WatchUi;

class Bitochi8BallApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
    }

    function onStop(state) {
    }

    function getInitialView() {
        var view = new Bitochi8BallView();
        return [view, new Bitochi8BallDelegate(view)];
    }
}
