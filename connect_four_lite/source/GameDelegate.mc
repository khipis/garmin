using Toybox.WatchUi;

// Controls
//   UP button      / onPreviousPage  → column left
//   DOWN button    / onNextPage      → column right
//   SELECT / tap                     → drop disc  (or new game when over)
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
        if      (k == WatchUi.KEY_UP)   { _v.moveColumn(-1); }
        else if (k == WatchUi.KEY_DOWN) { _v.moveColumn( 1); }
        else                            { _v.doAction(); }
        WatchUi.requestUpdate();
        return true;
    }

    function onSelect()       { _v.doAction();      WatchUi.requestUpdate(); return true; }
    function onPreviousPage() { _v.moveColumn(-1);  WatchUi.requestUpdate(); return true; }
    function onNextPage()     { _v.moveColumn( 1);  WatchUi.requestUpdate(); return true; }
    function onTap(evt)       { _v.doAction();      WatchUi.requestUpdate(); return true; }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
