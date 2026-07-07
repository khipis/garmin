// ═══════════════════════════════════════════════════════════════
// PixelInvadersApp.mc — Application entry point.
// ═══════════════════════════════════════════════════════════════

using Toybox.Application;

class PixelInvadersApp extends Application.AppBase {
    function initialize()   { AppBase.initialize(); }
    function onStart(state) { Leaderboard.logLaunch("pixelinvaders"); }
    function onStop(state)  {}

    function getInitialView() {
        // Root view is the shared unified menu; START launches MainView.
        return buildPixelInvadersMenu();
    }
}
