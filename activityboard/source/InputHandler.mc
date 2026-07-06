// ═══════════════════════════════════════════════════════════════════════════
// InputHandler.mc — Behaviour delegate for the flex dashboard.
//
// SELECT / ENTER / MENU / tap opens the "flex on the world" chooser. The
// dashboard scrolls when it has more sport boards than fit on screen: swipe
// up/down or use the UP/DOWN buttons. First-timers are sent to name entry so
// their world debut is under their own tag (never "anon"). BACK exits.
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

    // Swipe up reveals boards below; swipe down goes back up.
    function onSwipe(evt) {
        var d = evt.getDirection();
        if (d == WatchUi.SWIPE_UP)   { _view.scrollBy(_view.pageStep());  return true; }
        if (d == WatchUi.SWIPE_DOWN) { _view.scrollBy(-_view.pageStep()); return true; }
        return false;
    }

    // Physical page buttons scroll the dashboard on button watches.
    function onNextPage()     { _view.scrollBy(_view.pageStep());  return true; }
    function onPreviousPage() { _view.scrollBy(-_view.pageStep()); return true; }

    function onKey(evt) {
        var k = evt.getKey();
        if (k == WatchUi.KEY_ENTER) { return _flex(); }
        if (k == WatchUi.KEY_MENU)  { return _flex(); }
        if (k == WatchUi.KEY_DOWN)  { _view.scrollBy(_view.pageStep());  return true; }
        if (k == WatchUi.KEY_UP)    { _view.scrollBy(-_view.pageStep()); return true; }
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
