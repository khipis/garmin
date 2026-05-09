using Toybox.WatchUi;

// Controls
//   UP button      / D-pad up        → cursor row -1
//   DOWN button    / D-pad down      → cursor row +1
//   onPreviousPage / left scroll     → cursor col -1
//   onNextPage     / right scroll    → cursor col +1
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

    function onSelect()       { _v.doAction();      WatchUi.requestUpdate(); return true; }
    function onPreviousPage() { _v.moveCursor(0,-1); WatchUi.requestUpdate(); return true; }
    function onNextPage()     { _v.moveCursor(0, 1); WatchUi.requestUpdate(); return true; }
    function onTap(evt)       { _v.doAction();      WatchUi.requestUpdate(); return true; }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
