using Toybox.WatchUi;

// Controls
//   UP button      / D-pad up        → previous node  (linear cycle 23→0, wrapping)
//   DOWN button    / D-pad down      → next node      (linear cycle 0→23, wrapping)
//   onPreviousPage / UP scroll       → previous node  (same as UP)
//   onNextPage     / DOWN scroll     → next node      (same as DOWN)
//   SELECT / tap                     → action (place / move / remove / new game)
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
        if      (k == WatchUi.KEY_UP)   { _v.navigate(0); }
        else if (k == WatchUi.KEY_DOWN) { _v.navigate(1); }
        else                            { _v.doAction(); }
        WatchUi.requestUpdate();
        return true;
    }

    function onSelect()       { _v.doAction();  WatchUi.requestUpdate(); return true; }
    function onPreviousPage() { _v.navigate(0); WatchUi.requestUpdate(); return true; }
    function onNextPage()     { _v.navigate(1); WatchUi.requestUpdate(); return true; }
    function onTap(evt) {
        var xy = evt.getCoordinates();
        _v.doTap(xy[0], xy[1]);
        WatchUi.requestUpdate(); return true;
    }

    function onBack() {
        if (!_v.doBack()) {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
        } else {
            WatchUi.requestUpdate();
        }
        return true;
    }
}
