// ═══════════════════════════════════════════════════════════════
// BattleshipApp.mc — Application entry point.
// ═══════════════════════════════════════════════════════════════
using Toybox.Application;
using Toybox.WatchUi;

class BattleshipApp extends Application.AppBase {
    function initialize()    { AppBase.initialize(); }
    function onStart(state)  { Leaderboard.logLaunch("battleship"); }
    function onStop(state)   {}

    function getInitialView() {
        return buildBattleshipMenu();
    }
}
