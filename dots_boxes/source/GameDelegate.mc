using Toybox.WatchUi;

// Controls
//   UP button      / D-pad up        → cursor to edge in row above  (wrapping)
//   DOWN button    / D-pad down      → cursor to edge in row below  (wrapping)
//   onPreviousPage / UP scroll       → previous edge  (linear reading order, wrapping)
//   onNextPage     / DOWN scroll     → next edge      (linear reading order, wrapping)
//   SELECT / tap                     → draw the selected edge (or menu action)
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
    function onPreviousPage() { _v.navigate(2); WatchUi.requestUpdate(); return true; }
    function onNextPage()     { _v.navigate(3); WatchUi.requestUpdate(); return true; }
    function onTap(evt)       { _v.doAction();  WatchUi.requestUpdate(); return true; }

    function onBack() {
        if (!_v.doBack()) {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
        } else {
            WatchUi.requestUpdate();
        }
        return true;
    }
}
