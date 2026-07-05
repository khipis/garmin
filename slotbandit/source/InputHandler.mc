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
//   PLAY state — one input does the right thing for the moment:
//     SELECT / tap             → SPIN (idle) / STOP next reel (spinning)
//                                 / dismiss result (result showing)
//     tap on a reel column     → stop THAT reel directly (spinning only)
//     hold / long-press        → toggle auto-spin
//     BACK                     → return to menu
//
//   OVER state — instant-restart loop:
//     ANY key / tap             → start a new round immediately
//     BACK                      → return to menu
//
// Chess pattern: menu nav goes only through the semantic callbacks
// (onPreviousPage / onNextPage / onSelect) plus tap; raw onKey is a
// fallback for devices that don't route UP/DOWN through those.
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.System;

class InputHandler extends WatchUi.BehaviorDelegate {
    hidden var _v;

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
        if (_v.inMenu()) { return false; }
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
    function onHold(evt) {
        _markGesture();
        _v.navLongPress();
        WatchUi.requestUpdate();
        return true;
    }
    function onSwipe(evt) {
        _markGesture();
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
