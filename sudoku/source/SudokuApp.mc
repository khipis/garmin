// ═══════════════════════════════════════════════════════════════
// SudokuApp.mc — Application entry-point.
// ═══════════════════════════════════════════════════════════════
using Toybox.Application;
using Toybox.WatchUi;

class SudokuApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state)    { Leaderboard.logLaunch("sudoku"); }
    function onStop(state)     {}

    function getInitialView() {
        var v = new MainView();
        return [v, new InputHandler(v)];
    }
}
