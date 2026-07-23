// ═══════════════════════════════════════════════════════════════
// PixelInvadersApp.mc — Application entry point.
// ═══════════════════════════════════════════════════════════════

using Toybox.Application;

class PixelInvadersApp extends Application.AppBase {
    function initialize()   { AppBase.initialize(); }
    function onStart(state) {
        Leaderboard.logLaunch("pixelinvaders");
        // Advance the daily login streak + grant the daily coin bonus. On the
        // day's first launch, queue a toast the game view shows on the first frame.
        try {
            var ci = Progress.checkIn();
            if (ci["first"]) {
                Application.Storage.setValue("pi_daily_msg",
                    "Daily +" + ci["bonus"] + "  Streak " + ci["streak"]);
            }
        } catch (e) {}
    }
    function onStop(state)  {}

    function getInitialView() {
        // Root view is the shared unified menu; START launches MainView.
        return buildPixelInvadersMenu();
    }
}
