using Toybox.WatchUi;

// Input routing:
//   UP button      → cursor up
//   DOWN button    → cursor down
//   onPreviousPage → cursor left  (UP-scroll / back gesture)
//   onNextPage     → cursor right (DOWN-scroll / forward gesture)
//   SELECT         → place disc (or new game when game over)
//   BACK           → exit

class GameDelegate extends WatchUi.BehaviorDelegate {
    hidden var _v;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _v = view;
    }

    function onKey(evt) {
        if (evt.getType() != 0) { return false; }  // key-press only
        var k = evt.getKey();
        if      (k == WatchUi.KEY_UP)   { _v.moveCursor(0, -1); }
        else if (k == WatchUi.KEY_DOWN) { _v.moveCursor(0,  1); }
        else                            { _v.doAction(); }
        WatchUi.requestUpdate();
        return true;
    }

    function onSelect()       { _v.doAction();   WatchUi.requestUpdate(); return true; }
    function onPreviousPage() { _v.moveCursor(-1, 0); WatchUi.requestUpdate(); return true; }
    function onNextPage()     { _v.moveCursor( 1, 0); WatchUi.requestUpdate(); return true; }
    function onTap(evt)       { _v.doAction();   WatchUi.requestUpdate(); return true; }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
