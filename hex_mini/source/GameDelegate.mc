using Toybox.WatchUi;

// Controls
//   UP button      / D-pad up        → cursor row -1 (menu: prev row)
//   DOWN button    / D-pad down      → cursor row +1 (menu: next row)
//   onPreviousPage / left scroll     → retreat cursor in reading order (menu: prev row)
//   onNextPage     / right scroll    → advance cursor in reading order (menu: next row)
//   SELECT / tap                     → place stone (or new game when over)
//   BACK                             → exit

class GameDelegate extends WatchUi.BehaviorDelegate {
    hidden var _v;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _v = view;
    }

    function onKey(evt) {
        if (evt.getType() != 0) { return false; }
        var k = evt.getKey();
        if      (k == WatchUi.KEY_UP)   { _v.moveCursor(-1,  0); }
        else if (k == WatchUi.KEY_DOWN) { _v.moveCursor( 1,  0); }
        else                            { _v.doAction(); }
        WatchUi.requestUpdate();
        return true;
    }

    function onSelect()       { _v.doAction();        WatchUi.requestUpdate(); return true; }
    function onPreviousPage() { _v.retreatCursor();   WatchUi.requestUpdate(); return true; }
    function onNextPage()     { _v.advanceCursor();   WatchUi.requestUpdate(); return true; }
    function onTap(evt)       { _v.doAction();      WatchUi.requestUpdate(); return true; }

    function onBack() {
        if (!_v.doBack()) {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
        } else {
            WatchUi.requestUpdate();
        }
        return true;
    }
}
