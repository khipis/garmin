// ═══════════════════════════════════════════════════════════════
// SlotBanditApp.mc — Application entry point.
// ═══════════════════════════════════════════════════════════════
using Toybox.Application;
using Toybox.WatchUi;

class SlotBanditApp extends Application.AppBase {
    function initialize()   { AppBase.initialize(); }
    function onStart(state) { Leaderboard.logLaunch("slotbandit"); }
    function onStop(state)  { }

    function getInitialView() {
        var v = new MainView();
        return [v, new InputHandler(v)];
    }
}
