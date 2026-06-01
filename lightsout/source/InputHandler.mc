// ═══════════════════════════════════════════════════════════════
// InputHandler.mc — Buttons + tap + swipe + hold for LightsOut.
//
//   MENU:
//     UP / onPreviousPage    → prev row
//     DOWN / onNextPage      → next row
//     SELECT / onEnter       → activate row
//     tap on row             → activate
//
//   PLAY:
//     UP key                 → cursor PREV (scan order)
//     DOWN key               → cursor NEXT (scan order)
//     SELECT / onEnter       → TOGGLE at cursor
//     swipe ↑/↓/←/→          → move cursor 4-way
//     tap on cell            → TOGGLE that cell (also moves cursor)
//     hold (long-press)      → RESTART current level
//     ESC                    → menu
//
//   WIN:
//     SEL / tap              → next level (or menu when last)
//     UP / DOWN              → next level / restart current
//     ESC                    → menu
//
// Native firmware `onSwipe` is ignored; we resolve every touch in
// `onDrag` with a 30 px tap window and dominant-axis swipe.
// Stationary press ≥ 500 ms triggers HOLD → restart.
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
                if (dur >= 600) {
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
