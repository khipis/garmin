using Toybox.Application;
using Toybox.WatchUi;

class BreathTrainingApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) {}
    function onStop(state) {}
    function getInitialView() {
        var view = new BreathTrainingView();
        return [view, new BreathTrainingDelegate(view)];
    }
}
