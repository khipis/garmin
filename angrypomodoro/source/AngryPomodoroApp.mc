using Toybox.Application;
using Toybox.WatchUi;

class AngryPomodoroApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {}
    function onStop(state)  {}

    function getInitialView() {
        var view     = new AngryPomodoroView();
        var delegate = new AngryPomodoroDelegate(view);
        return [view, delegate];
    }
}
