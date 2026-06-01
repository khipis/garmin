// ═══════════════════════════════════════════════════════════════
// InputHandler.mc — Maps Garmin inputs to player intent.
//
// Buttons (5-button watch layout)
//   KEY_UP press/release   → hold "left"  (continuous)
//   KEY_DOWN press/release → hold "right" (continuous)
//   KEY_ENTER / SELECT     → start round (when on menu) or harmless
//   KEY_ESC                → BACK
//
// Touch
//   Tap left half  → impulse left
//   Tap right half → impulse right
//   Swipe L/R      → strong impulse in swipe direction
//
// onKeyPressed / onKeyReleased give us "hold" behaviour without
// polling the key state every tick.
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.System;

class InputHandler extends WatchUi.BehaviorDelegate {
    hidden var _v;
    // Phantom-back guard — see onBack.
    hidden var _lastGestureMs;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _v             = view;
        _lastGestureMs = 0;
    }

    hidden function _markGesture() { _lastGestureMs = System.getTimer(); }
    hidden function _isPhantomBack() {
        if (_lastGestureMs == 0) { return false; }
        var dt = System.getTimer() - _lastGestureMs;
        return (dt >= 0 && dt < 500);
    }

    function onKeyPressed(evt) {
        var k = evt.getKey();
        if      (k == WatchUi.KEY_UP)    { _v.holdLeft(true);  }
        else if (k == WatchUi.KEY_DOWN)  { _v.holdRight(true); }
        return true;
    }
    function onKeyReleased(evt) {
        var k = evt.getKey();
        if      (k == WatchUi.KEY_UP)    { _v.holdLeft(false);  }
        else if (k == WatchUi.KEY_DOWN)  { _v.holdRight(false); }
        return true;
    }

    function onKey(evt) {
        var k = evt.getKey();
        if (k == WatchUi.KEY_ESC) { return onBack(); }
        // For ENTER and others — treat as "confirm" on menu/over screens.
        if (_v.isPassiveState()) {
            _v.confirm();
            WatchUi.requestUpdate();
        }
        return true;
    }

    function onSelect()       { _v.confirm(); WatchUi.requestUpdate(); return true; }
    function onPreviousPage() { _v.tap(-1);   WatchUi.requestUpdate(); return true; }
    function onNextPage()     { _v.tap( 1);   WatchUi.requestUpdate(); return true; }

    function onTap(evt) {
        _markGesture();
        var xy = evt.getCoordinates();
        _v.handleTap(xy[0]);
        WatchUi.requestUpdate();
        return true;
    }

    function onSwipe(evt) {
        _markGesture();
        var d = evt.getDirection();
        if      (d == WatchUi.SWIPE_LEFT)  { _v.tap(-1); }
        else if (d == WatchUi.SWIPE_RIGHT) { _v.tap( 1); }
        else                                { _v.confirm(); }
        WatchUi.requestUpdate();
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
