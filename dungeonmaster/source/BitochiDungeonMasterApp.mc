using Toybox.Application;
using Toybox.WatchUi;

class BitochiDungeonMasterApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }

    function onStart(state) {
        Leaderboard.logLaunch("dungeonmaster");
        // Daily login streak → queued as a toast the expedition shows on entry.
        try {
            var ci = Progress.checkIn();
            if (ci["first"]) {
                Application.Storage.setValue("dm_daily_msg",
                    "Daily +" + ci["bonus"] + "  Streak " + ci["streak"]);
            }
        } catch (e) {}
    }

    function onStop(state) {}

    function getInitialView() {
        return buildDungeonMasterMenu();
    }
}
