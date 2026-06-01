// ═══════════════════════════════════════════════════════════════
// InputHandler.mc — Swipe-driven controls for HoloGrid Escape.
//
// In PLAY:
//   • Swipes move the runner one cell in the swiped direction.
//   • Long drags (≥25 px) on the dominant axis fall back to swipes
//     for firmwares that don't expose onSwipe.
//   • A tap on the play board sets the facing direction (relative
//     to the player) without moving — preserves the legacy "aim"
//     behaviour for thumb users.
//
// In MENU / RESULT:
//   • UP / PreviousPage → previous row
//   • DOWN / NextPage   → next row
//   • SELECT            → activate row
//   • Tap on a row      → activate that row (hit-tested by view)
//   • ESC               → pop view
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.System;

class InputHandler extends WatchUi.BehaviorDelegate {
    hidden var _v;

    hidden var _dragStartX;
    hidden var _dragStartY;
    hidden var _dragActive;
    hidden var _dragHandledInput;
    hidden var _swipeHandled;
    hidden var _lastTapMs;
    // Phantom-back guard — see onBack.
    hidden var _lastGestureMs;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _v                = view;
        _dragStartX       = 0;
        _dragStartY       = 0;
        _dragActive       = false;
        _dragHandledInput = false;
        _swipeHandled     = false;
        _lastTapMs        = 0;
        _lastGestureMs    = 0;
    }

    hidden function _markGesture() { _lastGestureMs = System.getTimer(); }
    hidden function _isPhantomBack() {
        if (_lastGestureMs == 0) { return false; }
        var dt = System.getTimer() - _lastGestureMs;
        return (dt >= 0 && dt < 500);
    }

    function onKey(evt) {
        var k = evt.getKey();
        if      (k == WatchUi.KEY_UP)   { _v.navUp();   }
        else if (k == WatchUi.KEY_DOWN) { _v.navDown(); }
        else if (k == WatchUi.KEY_ESC)  { return onBack(); }
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

    function onTap(evt) {
        _markGesture();
        if (_swipeHandled)     { _swipeHandled     = false; return true; }
        if (_dragHandledInput) { _dragHandledInput = false; return true; }
        var now = System.getTimer();
        if (_lastTapMs != 0 && (now - _lastTapMs) < 250) { return true; }

        var xy = evt.getCoordinates();
        _v.handleTap(xy[0], xy[1]);
        WatchUi.requestUpdate();
        return true;
    }

    function onSwipe(evt) {
        _markGesture();
        _swipeHandled = true;
        var d = evt.getDirection();
        if      (d == WatchUi.SWIPE_UP)    { _v.handleSwipe(-1,  0); }
        else if (d == WatchUi.SWIPE_DOWN)  { _v.handleSwipe( 1,  0); }
        else if (d == WatchUi.SWIPE_LEFT)  { _v.handleSwipe( 0, -1); }
        else if (d == WatchUi.SWIPE_RIGHT) { _v.handleSwipe( 0,  1); }
        WatchUi.requestUpdate();
        return true;
    }

    function onDrag(evt) {
        var xy = evt.getCoordinates();
        var t  = evt.getType();

        if (t == WatchUi.DRAG_TYPE_START) {
            _dragStartX       = xy[0];
            _dragStartY       = xy[1];
            _dragActive       = true;
            _dragHandledInput = false;
            _swipeHandled     = false;
            return true;
        }

        if (t == WatchUi.DRAG_TYPE_STOP && _dragActive) {
            _dragActive = false;
            _markGesture();
            if (_swipeHandled) { _swipeHandled = false; return true; }

            var dx  = xy[0] - _dragStartX;
            var dy  = xy[1] - _dragStartY;
            var adx = (dx < 0) ? -dx : dx;
            var ady = (dy < 0) ? -dy : dy;

            if (adx < 18 && ady < 18) {
                _dragHandledInput = true;
                _lastTapMs = System.getTimer();
                _v.handleTap(xy[0], xy[1]);
                WatchUi.requestUpdate();
            } else if (adx >= 25 || ady >= 25) {
                _dragHandledInput = true;
                if (adx >= ady) {
                    if (dx > 0) { _v.handleSwipe(0,  1); }
                    else        { _v.handleSwipe(0, -1); }
                } else {
                    if (dy > 0) { _v.handleSwipe( 1, 0); }
                    else        { _v.handleSwipe(-1, 0); }
                }
                WatchUi.requestUpdate();
            }
        }
        return true;
    }
}
