using Toybox.Application;
using Toybox.WatchUi;

// ─────────────────────────────────────────────────────────────────────────────
//  Bitochi Dungeon  –  Auto-run roguelite for Garmin watches
//  "Diablo meets endless runner meets micro decisions"
// ─────────────────────────────────────────────────────────────────────────────

class BitochiDungeonApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) {}
    function onStop(state) {}
    function getInitialView() {
        var view = new DungeonView();
        return [view, new DungeonDelegate(view)];
    }
}
