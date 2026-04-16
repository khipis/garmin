using Toybox.Application;
using Toybox.WatchUi;

class FreedivingTrainingApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) {}
    function onStop(state) {}
    function getInitialView() {
        var view = new FreedivingTrainingView();
        return [view, new FreedivingTrainingDelegate(view)];
    }
}
