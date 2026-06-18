// ═══════════════════════════════════════════════════════════════
// TwentyFortyEightApp.mc — Application entry point.
// ═══════════════════════════════════════════════════════════════
using Toybox.Application;
using Toybox.WatchUi;

class TwentyFortyEightApp extends Application.AppBase {
    function initialize()    { AppBase.initialize(); }
    function onStart(state)  { Leaderboard.logLaunch("twentyfortyeight"); }
    function onStop(state)   {}

    function getInitialView() {
        var v = new MainView();
        return [v, new InputHandler(v)];
    }
}
