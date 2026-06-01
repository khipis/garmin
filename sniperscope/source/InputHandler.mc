// ═══════════════════════════════════════════════════════════════
// InputHandler.mc — Button + touch dispatch.
//
//   MENU
//     UP / onPreviousPage   → previous row
//     DOWN / onNextPage     → next row
//     SELECT / onEnter      → activate row
//     tap on a row          → activate that row
//
//   PLAY (scanning + aiming)
//     tilt                  → look around (in MainView.onTick)
//     UP                    → recalibrate (zero the wrist)
//     DOWN / SELECT / tap   → FIRE
//
//   RESULT / OVER
//     any key / tap         → next round / back to menu
//
// Touch behaviour: we ignore native onSwipe.  A short drag
// becomes a tap on STOP — this dramatically reduces accidental
// misses on slightly noisy fingertips.
//
// Phantom-back guard: the watch firmware fires an `onBack` when
// the user swipes from the right edge.  Without the guard a
// gameplay swipe would silently pop the view.
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.System;

const SS_PAGE_GUARD_MS = 350;

class InputHandler extends WatchUi.BehaviorDelegate {
    hidden var _v;
    hidden var _dx0;
    hidden var _dy0;
    hidden var _dragActive;
    hidden var _handled;
    hidden var _lastTouchMs;
    hidden var _lastDragEndMs;
    hidden var _lastGestureMs;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _v             = view;
        _dx0           = 0;
        _dy0           = 0;
        _dragActive    = false;
        _handled       = false;
        _lastTouchMs   = 0;
        _lastDragEndMs = 0;
        _lastGestureMs = 0;
    }

    hidden function _markGesture() { _lastGestureMs = System.getTimer(); }
    hidden function _isPhantomBack() {
        if (_lastGestureMs == 0) { return false; }
        var dt = System.getTimer() - _lastGestureMs;
        return (dt >= 0 && dt < 500);
    }

    hidden function _pageFromTouch() {
        if (_dragActive) { return true; }
        if (_lastDragEndMs == 0) { return false; }
        var dt = System.getTimer() - _lastDragEndMs;
        return (dt >= 0 && dt < SS_PAGE_GUARD_MS);
    }

    function onKey(evt) {
        var k = evt.getKey();
        if      (k == WatchUi.KEY_ESC)  { return onBack(); }
        else if (k == WatchUi.KEY_UP)   { _v.navUp(); }
        else if (k == WatchUi.KEY_DOWN) { _v.navDown(); }
        else                            { _v.navSelect(); }
        WatchUi.requestUpdate();
        return true;
    }

    function onSelect() {
        _v.navSelect();
        WatchUi.requestUpdate();
        return true;
    }

    function onPreviousPage() {
        if (_v.ctrl.state == SS_PLAY && _pageFromTouch()) { return true; }
        _v.navUp(); WatchUi.requestUpdate(); return true;
    }
    function onNextPage() {
        if (_v.ctrl.state == SS_PLAY && _pageFromTouch()) { return true; }
        _v.navDown(); WatchUi.requestUpdate(); return true;
    }

    function onBack() {
        if (_isPhantomBack()) { _lastGestureMs = 0; return true; }
        var consumed = _v.navBack();
        WatchUi.requestUpdate();
        if (consumed) { return true; }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
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
            _dx0        = xy[0];
            _dy0        = xy[1];
            _dragActive = true;
            _handled    = false;
            return true;
        }
        if (t == WatchUi.DRAG_TYPE_STOP && _dragActive) {
            _dragActive    = false;
            _handled       = true;
            _lastTouchMs   = System.getTimer();
            _lastDragEndMs = _lastTouchMs;
            _markGesture();
            var dx = xy[0] - _dx0;
            var dy = xy[1] - _dy0;
            var adx = (dx < 0) ? -dx : dx;
            var ady = (dy < 0) ? -dy : dy;
            if (adx < 40 && ady < 40) {
                _v.handleTap(xy[0], xy[1]);
                WatchUi.requestUpdate();
            }
        }
        return true;
    }
}
