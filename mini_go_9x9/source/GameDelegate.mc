using Toybox.WatchUi;

// Routes input to GameView.
// D-pad navigation:
//   KEY_UP   → cursor row -1, wrapping (in menu: row backward)
//   KEY_DOWN → cursor row +1, wrapping (in menu: row forward)
//   onNextPage     (DOWN button) → reading-order advance col+1 (in menu: forward)
//   onPreviousPage (UP button)   → reading-order retreat col-1  (in menu: backward)
//   SELECT   → place stone / cycle menu option / new game
//   BACK     → pass (or exit in menu / after game over)

class GameDelegate extends WatchUi.BehaviorDelegate {
    hidden var _v;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _v = view;
    }

    function onKey(evt) {
        var k = evt.getKey();
        if (evt.getType() != 0) { return false; }
        if      (k == WatchUi.KEY_UP)   { _v.moveCursor(0, -1); }
        else if (k == WatchUi.KEY_DOWN) { _v.moveCursor(0,  1); }
        else                            { _v.doAction(); }
        WatchUi.requestUpdate();
        return true;
    }

    function onSelect()       { _v.doAction();       WatchUi.requestUpdate(); return true; }
    function onPreviousPage() { _v.retreatCursor();  WatchUi.requestUpdate(); return true; }
    function onNextPage()     { _v.advanceCursor();  WatchUi.requestUpdate(); return true; }
    function onTap(evt)       { _v.doAction();       WatchUi.requestUpdate(); return true; }

    function onBack() {
        if (!_v.doBack()) {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
        } else {
            WatchUi.requestUpdate();
        }
        return true;
    }
}
