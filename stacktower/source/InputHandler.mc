// ═══════════════════════════════════════════════════════════════
// InputHandler.mc — Input routing.
//
//   MENU state
//     UP    / onPreviousPage  → previous row
//     DOWN  / onNextPage      → next row
//     SELECT / ENTER          → activate selected row
//     tap on a row            → activate that row
//     BACK                    → pop view
//
//   PLAY / OVER state
//     any key / tap / swipe   → drop the moving block
//     BACK                    → return to menu
//
// Chess pattern: nav is handled only through the semantic
// callbacks (onPreviousPage / onNextPage / onSelect) plus tap.
// Raw `onKey` is used only for ESC and as a fallback that maps
// to "drop" in play state.
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.System;

class InputHandler extends WatchUi.BehaviorDelegate {
    hidden var _v;

    // Phantom-back guard.  Touch panels deliver onBack alongside
    // an onSwipe/onTap for a single right-edge gesture; swallow it
    // so the user's gameplay swipe doesn't also bounce the view.
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
        // In MENU let the high-level page/select callbacks handle
        // navigation so we don't fire twice per press.
        if (_v.inMenu()) { return false; }
        _v.handleDrop();
        WatchUi.requestUpdate();
        return true;
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
        if (_v.inMenu()) {
            var xy = evt.getCoordinates();
            _v.handleTap(xy[0], xy[1]);
        } else {
            _v.handleDrop();
        }
        WatchUi.requestUpdate();
        return true;
    }
    function onSwipe(evt) {
        _markGesture();
        // Swipes in MENU are ignored so a stray flick doesn't
        // accidentally start a game.
        if (!_v.inMenu()) { _v.handleDrop(); WatchUi.requestUpdate(); }
        return true;
    }
    function onHold(evt) {
        if (!_v.inMenu()) { _v.handleDrop(); WatchUi.requestUpdate(); }
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
