// ═══════════════════════════════════════════════════════════════
// PinballProApp.mc — Application entry point.
// ═══════════════════════════════════════════════════════════════
using Toybox.Application;
using Toybox.WatchUi;

class PinballProApp extends Application.AppBase {
    function initialize()    { AppBase.initialize(); }
    function onStart(state)  {}
    function onStop(state)   {}

    function getInitialView() {
        var v = new MainView();
        var d = new InputHandler(v);
        v.setDelegate(d);
        return [v, d];
    }
}
