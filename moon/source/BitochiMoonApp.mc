using Toybox.Application;
using Toybox.WatchUi;

// ─────────────────────────────────────────────────────────────────────────────
//  Bitochi Moon Lander — classic lunar landing game for Garmin watches
// ─────────────────────────────────────────────────────────────────────────────

class BitochiMoonApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) { Leaderboard.logLaunch("moon"); }
    function onStop(state) {}
    function getInitialView() {
        // Root view is the shared unified menu; START launches the lander.
        return buildMoonMenu();
    }
}
