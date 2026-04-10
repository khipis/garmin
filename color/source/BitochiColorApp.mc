using Toybox.Application;
using Toybox.WatchUi;

// ─────────────────────────────────────────────────────────────────────────────
//  Bitochi Color Pop  –  Match-3 puzzle game for Garmin watches
// ─────────────────────────────────────────────────────────────────────────────

class BitochiColorApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) {}
    function onStop(state) {}
    function getInitialView() {
        var view = new ColorPopView();
        return [view, new ColorPopDelegate(view)];
    }
}
