using Toybox.WatchUi;

// Input routing:
//   UP button / swipe up      → retreatCursor (reading order backward)
//   DOWN button / swipe down  → advanceCursor (reading order forward)
//   KEY_DOWN                  → moveCursorRow(+1) — move cursor down one row
//   KEY_UP                    → moveCursorRow(-1) — move cursor up one row
//   SELECT / tap              → doAction
//   BACK                      → pop view

class GameDelegate extends WatchUi.BehaviorDelegate {
    hidden var _v;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _v = view;
    }

    function onKey(evt) {
        if (evt.getType() != 0) { return false; }
        var k = evt.getKey();
        if      (k == WatchUi.KEY_UP)   { _v.moveCursorRow(-1); }
        else if (k == WatchUi.KEY_DOWN) { _v.moveCursorRow(1); }
        else                            { _v.doAction(); }
        WatchUi.requestUpdate();
        return true;
    }

    function onSelect()       { _v.doAction();        WatchUi.requestUpdate(); return true; }
    function onNextPage()     { _v.advanceCursor();   WatchUi.requestUpdate(); return true; }
    function onPreviousPage() { _v.retreatCursor();   WatchUi.requestUpdate(); return true; }
    function onTap(evt)       { _v.doAction();        WatchUi.requestUpdate(); return true; }

    function onBack() {
        if (!_v.doBack()) {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
        } else {
            WatchUi.requestUpdate();
        }
        return true;
    }
}
