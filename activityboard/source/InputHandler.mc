// ═══════════════════════════════════════════════════════════════════════════
// InputHandler.mc — Behaviour delegate for the flex dashboard.
//
// The whole app is one tap deep: SELECT / ENTER / MENU opens the "flex on the
// world" chooser. First-timers are sent to name entry so their world debut is
// under their own tag (never "anon"). BACK exits.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.WatchUi;

class InputHandler extends WatchUi.BehaviorDelegate {
    hidden var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() { return _flex(); }
    function onMenu()   { return _flex(); }
    function onTap(evt) { return _flex(); }

    function onKey(evt) {
        var k = evt.getKey();
        if (k == WatchUi.KEY_ENTER) { return _flex(); }
        if (k == WatchUi.KEY_MENU)  { return _flex(); }
        return false;
    }

    // Open the flex chooser. On a watch with no web capability the dashboard is
    // still a useful live stats screen, so we simply do nothing here.
    hidden function _flex() {
        if (!Leaderboard.isSupported()) { return true; }
        if (!Leaderboard.hasUser()) {
            var nv = new LbNameEntryView();
            WatchUi.pushView(nv, new LbNameEntryDelegate(nv), WatchUi.SLIDE_LEFT);
            return true;
        }
        _view.refresh();
        var snap = _view.snap();
        var m = new FlexMenu(snap);
        WatchUi.pushView(m, new FlexMenuDelegate(snap), WatchUi.SLIDE_UP);
        return true;
    }
}
