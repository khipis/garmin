using Toybox.Application;
using Toybox.WatchUi;

// ─────────────────────────────────────────────────────────────────────────────
//  Bitochi Moon Lander — classic lunar landing game for Garmin watches
// ─────────────────────────────────────────────────────────────────────────────

class BitochiMoonApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) {}
    function onStop(state) {}
    function getInitialView() {
        var view = new BitochiMoonView();
        return [view, new BitochiMoonDelegate(view)];
    }
}
