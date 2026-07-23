// ═══════════════════════════════════════════════════════════════
// SlotBanditApp.mc — Application entry point.
// ═══════════════════════════════════════════════════════════════
using Toybox.Application;
using Toybox.WatchUi;

class SlotBanditApp extends Application.AppBase {
    function initialize()   { AppBase.initialize(); }
    function onStart(state) {
        Leaderboard.logLaunch("slotbandit");
        // Advance the daily login streak + grant the daily coin bonus exactly
        // once per launch. On the day's first launch, queue a lightweight toast
        // MainView surfaces over the reels on the first frame.
        try {
            var ci = Progress.checkIn();
            if (ci["first"]) {
                Application.Storage.setValue("sb_daily_msg",
                    "Daily +" + ci["bonus"] + "  Streak " + ci["streak"]);
            }
        } catch (e) {}
    }
    function onStop(state)  { }

    function getInitialView() {
        // Root view is the shared unified menu; START launches MainView.
        return buildSlotBanditMenu();
    }
}
