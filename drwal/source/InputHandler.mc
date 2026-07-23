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

    // Every public handler is wrapped so a stray exception during rapid input
    // (e.g. mashing buttons on the game-over screen) can never surface the
    // Connect IQ crash dialog — worst case the input is silently ignored.
    function onKey(evt) {
        try {
            var k = evt.getKey();
            if (k == WatchUi.KEY_ESC) { return onBack(); }
            // In MENU, let the semantic page/select callbacks handle nav so
            // we don't double-fire per physical press.
            if (_v.inMenu()) { return false; }
            // Fallback for devices where UP/DOWN don't route through
            // onPreviousPage/onNextPage — mirror the same action.
            if (k == WatchUi.KEY_UP)   { _v.navUp();   WatchUi.requestUpdate(); return true; }
            if (k == WatchUi.KEY_DOWN) { _v.navDown(); WatchUi.requestUpdate(); return true; }
        } catch (e) { }
        return false;
    }
    function onSelect() {
        try { _v.navSelect(); WatchUi.requestUpdate(); } catch (e) { }
        return true;
    }
    function onPreviousPage() {
        try { _v.navUp(); WatchUi.requestUpdate(); } catch (e) { }
        return true;
    }
    function onNextPage() {
        try { _v.navDown(); WatchUi.requestUpdate(); } catch (e) { }
        return true;
    }
    function onTap(evt) {
        try {
            _markGesture();
            var xy = evt.getCoordinates();
            _v.handleTap(xy[0], xy[1]);
            WatchUi.requestUpdate();
        } catch (e) { }
        return true;
    }
    function onSwipe(evt) {
        try {
            _markGesture();
            // A stray swipe never fires a chop mid-run (would feel random);
            // in MENU/OVER it's a convenient "confirm / play again".
            if (_v.isPassiveState()) { _v.navSelect(); WatchUi.requestUpdate(); }
        } catch (e) { }
        return true;
    }

    function onBack() {
        try {
            if (_isPhantomBack()) { _lastGestureMs = 0; return true; }
            if (_v.handleBack()) {
                WatchUi.requestUpdate();
                return true;
            }
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
        } catch (e) { }
        return true;
    }
}
