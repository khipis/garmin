using Toybox.Application;
using Toybox.WatchUi;

class BitochiTowerDefenseApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }

    function onStart(state) {
        Leaderboard.logLaunch("towerdefense");
        try {
            var ci = Progress.checkIn();
            if (ci["first"]) {
                Application.Storage.setValue("td_daily_msg",
                    "Daily +" + ci["bonus"] + "  Streak " + ci["streak"]);
            }
        } catch (e) {}
    }

    function onStop(state) {}

    function getInitialView() {
        return buildTowerDefenseMenu();
    }
}
