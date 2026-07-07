// ═══════════════════════════════════════════════════════════════
// MinesweeperApp.mc — Application entry point.
// ═══════════════════════════════════════════════════════════════
using Toybox.Application;
using Toybox.WatchUi;

class MinesweeperApp extends Application.AppBase {
    function initialize()    { AppBase.initialize(); }
    function onStart(state)  { Leaderboard.logLaunch("minesweeper"); }
    function onStop(state)   {}

    function getInitialView() {
        return buildMinesweeperMenu();
    }
}
