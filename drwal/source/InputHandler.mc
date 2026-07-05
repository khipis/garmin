// ═══════════════════════════════════════════════════════════════
// InputHandler.mc — Input routing.
//
//   MENU state
//     UP / onPreviousPage      → previous row
//     DOWN / onNextPage        → next row
//     SELECT / ENTER           → activate selected row
//     tap on a row             → activate that row
//     BACK                     → pop view
//
//   PLAY state — every input resolves to ONE instant chop, no delay:
//     UP / onPreviousPage      → chop from the LEFT
//     DOWN / onNextPage        → chop from the RIGHT
//     tap left half / right half of the screen → chop that side
//     SELECT / ENTER           → chop again on the current side
//                                 (single-button fallback)
//
//   OVER state — instant-restart loop:
//     ANY key / tap / swipe    → start a new run immediately
//     BACK                     → return to menu
//
// Chess pattern: menu nav goes only through the semantic callbacks
// (onPreviousPage / onNextPage / onSelect) plus tap; raw onKey is a
// fallback for devices that don't route UP/DOWN through those.
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.System;

class InputHandler extends WatchUi.BehaviorDelegate {
    hidden var _v;

    // Phantom-back guard — touch panels sometimes deliver onBack
    // alongside an onSwipe/onTap for a single right-edge gesture;
    // swallow the paired back so a gameplay swipe doesn't also pop
    // the view.
    hidden var _lastGestureMs;
    hidden const _PHANTOM_BACK_MS = 500;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _v             = view;
        _lastGestureMs = 0;
    }

    hidden function _markGesture() { _lastGestureMs = System.getTimer(); }
    hidden function _isPhantomBack() {
        if (_lastGestureMs == 0) { return false; }
        var dt = System.getTimer() - _lastGestureMs;
        return (dt >= 0 && dt < _PHANTOM_BACK_MS);
    }

    function onKey(evt) {
        var k = evt.getKey();
        if (k == WatchUi.KEY_ESC) { return onBack(); }
        // In MENU, let the semantic page/select callbacks handle nav so
        // we don't double-fire per physical press.
        if (_v.inMenu()) { return false; }
        // Fallback for devices where UP/DOWN don't route through
        // onPreviousPage/onNextPage — mirror the same action.
        if (k == WatchUi.KEY_UP)   { _v.navUp();   WatchUi.requestUpdate(); return true; }
        if (k == WatchUi.KEY_DOWN) { _v.navDown(); WatchUi.requestUpdate(); return true; }
        return false;
    }
    function onSelect() {
        _v.navSelect();
        WatchUi.requestUpdate();
        return true;
    }
    function onPreviousPage() {
        _v.navUp();
        WatchUi.requestUpdate();
        return true;
    }
    function onNextPage() {
        _v.navDown();
        WatchUi.requestUpdate();
        return true;
    }
    function onTap(evt) {
        _markGesture();
        var xy = evt.getCoordinates();
        _v.handleTap(xy[0], xy[1]);
        WatchUi.requestUpdate();
        return true;
    }
    function onSwipe(evt) {
        _markGesture();
        // A stray swipe never fires a chop mid-run (would feel random);
        // in MENU/OVER it's a convenient "confirm / play again".
        if (_v.isPassiveState()) { _v.navSelect(); WatchUi.requestUpdate(); }
        return true;
    }

    function onBack() {
        if (_isPhantomBack()) { _lastGestureMs = 0; return true; }
        if (_v.handleBack()) {
            WatchUi.requestUpdate();
            return true;
        }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
