// ═══════════════════════════════════════════════════════════════
// HangmanApp.mc — Application entry point.
// ═══════════════════════════════════════════════════════════════
using Toybox.Application;
using Toybox.WatchUi;

class HangmanApp extends Application.AppBase {
    function initialize()    { AppBase.initialize(); }
    function onStart(state)  { Leaderboard.logLaunch("hangman"); }
    function onStop(state)   {}

    function getInitialView() {
        return buildHangmanMenu();
    }
}
