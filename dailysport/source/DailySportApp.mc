using Toybox.Application;
using Toybox.Lang;
using Toybox.WatchUi;

class BitochiDailySportApp extends Application.AppBase {

    function initialize() { AppBase.initialize(); }

    function onStart(state) {
        Leaderboard.logLaunch(DS_GAME_ID);
        // Shared login streak + daily coin bonus, surfaced on the menu footer.
        try {
            var ci = Progress.checkIn();
            if (ci["first"]) {
                Application.Storage.setValue("ds_daily_msg",
                    "Daily +" + ci["bonus"] + "  Streak " + ci["streak"]);
            }
        } catch (e) {}
        // Calories burned today convert to cosmetic currency, once per day.
        try { ProgressionManager.claimFitnessBonus(); } catch (e) {}
    }

    function onStop(state) {}

    function getInitialView() { return buildDailySportMenu(); }
}
