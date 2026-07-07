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
        // Root view is the shared unified menu; START launches MainView.
        return buildSudokuMenu();
    }
}
