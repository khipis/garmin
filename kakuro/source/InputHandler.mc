// ═══════════════════════════════════════════════════════════════
// InputHandler.mc — Routes input to MainView intents.
//
//   MENU:
//     UP / onPreviousPage    → previous row
//     DOWN / onNextPage      → next row
//     SELECT / onEnter       → activate row
//     tap on row             → activate
//
//   PLAY:
//     UP key                 → cycle digit UP   (1→2→…→9→0→1)
//     DOWN key               → cycle digit DOWN
//     SELECT / onEnter       → advance cursor to next white cell
//     ESC                    → back to menu
//     tap on white cell      → set cursor
//     tap on selected cell   → cycle digit UP
//     swipe ↑/↓/←/→          → move cursor
//     long-press (hold)      → clear current cell
//
//   WIN:
//     any key / tap          → back to menu
//
// Touch pipeline mirrors the recent dice/arcade games: we ignore
// firmware `onSwipe` and resolve every touch in `onDrag`.  Small
// displacements become taps (≤30 px); larger ones with a dominant
// axis become cursor swipes.
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
        if      (k == WatchUi.KEY_ESC)  { return onBack(); }
        else if (k == WatchUi.KEY_UP)   { _v.navUp();    }
        else if (k == WatchUi.KEY_DOWN) { _v.navDown();  }
        else                            { _v.navSelect(); }
        WatchUi.requestUpdate();
        return true;
    }

    function onSelect()       { _v.navSelect(); WatchUi.requestUpdate(); return true; }
    function onPreviousPage() { _v.navUp();     WatchUi.requestUpdate(); return true; }
    function onNextPage()     { _v.navDown();   WatchUi.requestUpdate(); return true; }

    function onBack() {
        if (_isPhantomBack()) { _lastGestureMs = 0; return true; }
        var consumed = _v.navBack();
        WatchUi.requestUpdate();
        if (consumed) { return true; }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    function onHold(evt) {
        var xy = evt.getCoordinates();
        _v.handleHold(xy[0], xy[1]);
        WatchUi.requestUpdate();
        return true;
    }

    function onSwipe(evt) { _markGesture(); return true; }

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
            _dx0          = xy[0];
            _dy0          = xy[1];
            _dragActive   = true;
            _handled      = false;
            _holdStartMs  = System.getTimer();
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
                // Stationary touch → tap.  Long stationary press (>= 500 ms)
                // becomes a CLEAR on the cell under the finger.
                if (dur >= 500) {
                    _v.handleHold(xy[0], xy[1]);
                } else {
                    _v.handleTap(xy[0], xy[1]);
                }
                WatchUi.requestUpdate();
            } else if (adx >= 30 || ady >= 30) {
                if (adx >= ady) {
                    if (dx > 0) { _v.handleSwipe( 0,  1); }
                    else        { _v.handleSwipe( 0, -1); }
                } else {
                    if (dy > 0) { _v.handleSwipe( 1,  0); }
                    else        { _v.handleSwipe(-1,  0); }
                }
                WatchUi.requestUpdate();
            }
        }
        return true;
    }
}
