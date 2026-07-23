// ═══════════════════════════════════════════════════════════════
// StarCombatApp.mc — Application entry point.
// ═══════════════════════════════════════════════════════════════

using Toybox.Application;

class StarCombatApp extends Application.AppBase {
    function initialize()   { AppBase.initialize(); }
    function onStart(state) {
        Leaderboard.logLaunch("starcombat");
        // Advance the daily login streak + grant the daily coin bonus. On the
        // day's first launch, queue a toast the game view flashes once.
        try {
            var ci = Progress.checkIn();
            if (ci["first"]) {
                Application.Storage.setValue(SC_K_DAILY,
                    "Daily +" + ci["bonus"] + "  Streak " + ci["streak"]);
            }
        } catch (e) {}
    }
    function onStop(state)  {}

    function getInitialView() {
        // Root view is the shared unified menu; START launches MainView.
        return buildStarCombatMenu();
    }
}
