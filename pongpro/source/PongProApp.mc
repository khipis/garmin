// ═══════════════════════════════════════════════════════════════
// PongProApp.mc — Application entry point.
// ═══════════════════════════════════════════════════════════════
using Toybox.Application;
using Toybox.WatchUi;

class PongProApp extends Application.AppBase {
    function initialize()    { AppBase.initialize(); }
    function onStart(state)  {}
    function onStop(state)   {}

    function getInitialView() {
        var v = new MainView();
        return [v, new InputHandler(v)];
    }
}
