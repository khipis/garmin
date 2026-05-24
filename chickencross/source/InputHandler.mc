// ═══════════════════════════════════════════════════════════════
// InputHandler.mc — Swipe-based controls for ChickenCross.
//
// In PLAY:
//   • Swipes (onSwipe) step the chicken one cell in that direction.
//   • A long drag (≥25 px on the dominant axis) is also treated as
//     a swipe — fallback for firmwares without native onSwipe.
//   • Taps during play are ignored (so a fingertip rest doesn't
//     accidentally retrigger movement).
//
// In MENU / WIN / OVER:
//   • UP / PreviousPage     → row up      / back to menu
//   • DOWN / NextPage       → row down    / back to menu
//   • SELECT                → activate    / back to menu
//   • Tap                   → hit-test menu row (handled by view)
//   • ESC                   → leave the app / back to menu
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

    function initialize(view) {
        BehaviorDelegate.initialize();
        _v                = view;
        _dragStartX       = 0;
        _dragStartY       = 0;
        _dragActive       = false;
        _dragHandledInput = false;
        _swipeHandled     = false;
        _lastTapMs        = 0;
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
        var consumed = _v.navBack();
        WatchUi.requestUpdate();
        if (consumed) { return true; }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    // ── Touch ────────────────────────────────────────────────────

    function onTap(evt) {
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
            if (_swipeHandled) { _swipeHandled = false; return true; }

            var dx  = xy[0] - _dragStartX;
            var dy  = xy[1] - _dragStartY;
            var adx = (dx < 0) ? -dx : dx;
            var ady = (dy < 0) ? -dy : dy;

            if (adx < 18 && ady < 18) {
                // Short displacement → treat as tap.
                _dragHandledInput = true;
                _lastTapMs = System.getTimer();
                _v.handleTap(xy[0], xy[1]);
                WatchUi.requestUpdate();
            } else if (adx >= 25 || ady >= 25) {
                // Long displacement → swipe on dominant axis.
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
