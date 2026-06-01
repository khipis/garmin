// ═══════════════════════════════════════════════════════════════
// InputHandler.mc — Buttons + touch + swipe fallback for GyroMaze.
//
// MENU:
//   UP / onPreviousPage   → prev row
//   DOWN / onNextPage     → next row
//   SELECT / tap          → activate row
//   ESC                   → exit app
//
// PLAY (gyro is primary; buttons are fallback):
//   UP button             → tilt-up acceleration  (vy -= step)
//   DOWN button           → tilt-down acceleration (vy += step)
//   onPreviousPage        → tilt-up (some models fire this for UP)
//   onNextPage            → tilt-down
//   swipe ↑↓←→            → directional acceleration
//   SELECT short          → restart level
//   SELECT long / hold    → recalibrate gyro
//   tap anywhere          → restart (same as SELECT in play)
//   ESC                   → menu
//
// PAUSE:
//   SELECT / tap / ESC    → resume + recalibrate
//
// WIN / OVER:
//   SELECT / tap          → next level / retry
//   ESC                   → menu
//
// Button acceleration magnitude (cell-units/tick per tick):
//   We use a small step (0.003) and hold it continuous via btnAx/
//   btnAy in the controller.  Released each onKey END.
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.System;

class InputHandler extends WatchUi.BehaviorDelegate {
    hidden var _v;

    hidden var _dx0;
    hidden var _dy0;
    hidden var _dragActive;
    hidden var _handled;
    hidden var _lastTouchMs;
    hidden var _holdStartMs;
    // Phantom-back guard — see onBack.
    hidden var _lastGestureMs;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _v             = view;
        _dx0           = 0;
        _dy0           = 0;
        _dragActive    = false;
        _handled       = false;
        _lastTouchMs   = 0;
        _holdStartMs   = 0;
        _lastGestureMs = 0;
    }

    hidden function _markGesture() { _lastGestureMs = System.getTimer(); }
    hidden function _isPhantomBack() {
        if (_lastGestureMs == 0) { return false; }
        var dt = System.getTimer() - _lastGestureMs;
        return (dt >= 0 && dt < 500);
    }

    function onKey(evt) {
        var k = evt.getKey();
        if (k == WatchUi.KEY_ESC)  { return onBack(); }
        if (k == WatchUi.KEY_UP)   { _v.navUp();    WatchUi.requestUpdate(); return true; }
        if (k == WatchUi.KEY_DOWN) { _v.navDown();  WatchUi.requestUpdate(); return true; }
        _v.navSelect(); WatchUi.requestUpdate(); return true;
    }

    function onSelect()       { _v.navSelect(); WatchUi.requestUpdate(); return true; }
    function onPreviousPage() { _v.navUp();     WatchUi.requestUpdate(); return true; }
    function onNextPage()     { _v.navDown();   WatchUi.requestUpdate(); return true; }

    function onBack() {
        // Swallow the phantom back that follows a right-edge touch.
        if (_isPhantomBack()) { _lastGestureMs = 0; return true; }
        var consumed = _v.navBack();
        WatchUi.requestUpdate();
        if (consumed) { return true; }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    function onHold(evt) {
        _v.handleHold();
        WatchUi.requestUpdate();
        return true;
    }

    function onSwipe(evt) { _markGesture(); return true; }   // handled via onDrag

    function onTap(evt) {
        _markGesture();
        if (_handled) { _handled = false; return true; }
        var now = System.getTimer();
        if (_lastTouchMs != 0 && (now - _lastTouchMs) < 120) { return true; }
        _lastTouchMs = now;
        var xy = evt.getCoordinates();
        _v.handleTap(xy[0], xy[1]);
        WatchUi.requestUpdate();
        return true;
    }

    function onDrag(evt) {
        var xy = evt.getCoordinates();
        var t  = evt.getType();
        if (t == WatchUi.DRAG_TYPE_START) {
            _dx0         = xy[0];
            _dy0         = xy[1];
            _dragActive  = true;
            _handled     = false;
            _holdStartMs = System.getTimer();
            return true;
        }
        if (t == WatchUi.DRAG_TYPE_STOP && _dragActive) {
            _dragActive  = false;
            _handled     = true;
            _lastTouchMs = System.getTimer();
            _markGesture();
            var dx  = xy[0] - _dx0;
            var dy  = xy[1] - _dy0;
            var adx = (dx < 0) ? -dx : dx;
            var ady = (dy < 0) ? -dy : dy;
            var dur = System.getTimer() - _holdStartMs;
            if (adx < 30 && ady < 30) {
                if (dur >= 600) { _v.handleHold(); }
                else            { _v.handleTap(xy[0], xy[1]); }
            } else {
                if (adx >= ady) {
                    _v.handleSwipeDir(0, (dx > 0) ? 1 : -1);
                } else {
                    _v.handleSwipeDir((dy > 0) ? 1 : -1, 0);
                }
            }
            WatchUi.requestUpdate();
        }
        return true;
    }
}
