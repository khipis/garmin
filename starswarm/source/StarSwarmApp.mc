// ═══════════════════════════════════════════════════════════════
// StarSwarmApp.mc — Application entry point.
// Returns the MainView + InputHandler pair.
// ═══════════════════════════════════════════════════════════════

using Toybox.Application;

class StarSwarmApp extends Application.AppBase {
    function initialize()   { AppBase.initialize(); }
    function onStart(state) {}
    function onStop(state)  {}

    function getInitialView() {
        var v = new MainView();
        return [v, new InputHandler(v)];
    }
}
