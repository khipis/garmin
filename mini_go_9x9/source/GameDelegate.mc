using Toybox.WatchUi;

// Routes input to GameView.
// D-pad navigation:
//   UP button    → cursor up
//   DOWN button  → cursor down
//   onNextPage   → cursor right   (DOWN-swipe / LAP on some watches)
//   onPreviousPage → cursor left  (UP-swipe)
//   SELECT       → place stone (or new game if game over)
//   BACK         → pass (or exit)

class GameDelegate extends WatchUi.BehaviorDelegate {
    hidden var _v;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _v = view;
    }

    function onKey(evt) {
        var k = evt.getKey();
        // Only react to key-press events (type 0)
        if (evt.getType() != 0) { return false; }
        if      (k == WatchUi.KEY_UP)   { _v.moveCursor(0, -1); }
        else if (k == WatchUi.KEY_DOWN) { _v.moveCursor(0,  1); }
        else                            { _v.doAction(); }
        WatchUi.requestUpdate();
        return true;
    }

    function onSelect()       { _v.doAction();  WatchUi.requestUpdate(); return true; }
    function onPreviousPage() { _v.moveCursor(-1, 0); WatchUi.requestUpdate(); return true; }
    function onNextPage()     { _v.moveCursor( 1, 0); WatchUi.requestUpdate(); return true; }
    function onTap(evt)       { _v.doAction();  WatchUi.requestUpdate(); return true; }

    function onBack() {
        if (_v.doPass()) { WatchUi.requestUpdate(); return true; }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
