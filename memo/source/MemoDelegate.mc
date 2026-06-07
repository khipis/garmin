using Toybox.WatchUi;

// ─── Input Delegate ─────────────────────────────────────────────────────────
// Garmin 5-button mapping (and full touch / gesture support):
//   Left-MIDDLE button (onPreviousPage) → vertical cursor move   (row+1, wrap)
//   Left-BOTTOM button (onNextPage)     → horizontal cursor move  (col+1, wrap)
//   START / SELECT                      → flip tile / confirm menu row
//   BACK                                → exit play → menu → app
//   Swipe U/D/L/R                       → move cursor in that direction (wrap)
//   TAP                                 → flip the tapped tile; double-tap on a
//                                         mismatch clears the wait
class MemoDelegate extends WatchUi.BehaviorDelegate {
    hidden var _v;
    function initialize(view) { BehaviorDelegate.initialize(); _v = view; }

    function onPreviousPage() { _v.btnVert();  WatchUi.requestUpdate(); return true; }
    function onNextPage()     { _v.btnHoriz(); WatchUi.requestUpdate(); return true; }
    function onSelect()       { _v.doSelect(); WatchUi.requestUpdate(); return true; }

    function onBack() {
        var h = _v.doBack();
        WatchUi.requestUpdate();
        return h;
    }

    function onSwipe(evt) {
        _v.swipe(evt.getDirection());
        WatchUi.requestUpdate();
        return true;
    }

    function onTap(evt) {
        var c = evt.getCoordinates();
        _v.doTap(c[0], c[1]);
        WatchUi.requestUpdate();
        return true;
    }
}
