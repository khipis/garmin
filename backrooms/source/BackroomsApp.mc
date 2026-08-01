using Toybox.Application;
using Toybox.WatchUi;

class BackroomsApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }

    function onStart(state) {
        Leaderboard.logLaunch(Br.GAME_ID);
        // Daily check-in: streak + coin bonus, surfaced as a toast on the menu.
        try {
            var ci = Progress.checkIn();
            if (ci["first"]) {
                Application.Storage.setValue("br_daily_msg",
                    "Daily +" + ci["bonus"] + "  Streak " + ci["streak"]);
            }
        } catch (e) {}
        // Publish lifetime bests once a day even if today's runs all end badly.
        try { BrSave.submitLifetime(); } catch (e) {}
    }

    function onStop(state) {}

    function getInitialView() {
        // Root view is the shared unified menu; START enters the Backrooms.
        return buildBackroomsMenu();
    }
}
