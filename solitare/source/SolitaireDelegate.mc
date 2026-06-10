using Toybox.WatchUi;
using Toybox.System;

// ─── Input Delegate ─────────────────────────────────────────────────────────
// Touch + buttons.
//
//   Buttons:
//     UP   (left-middle, onPreviousPage) → cursor prev
//     DOWN (left-bottom, onNextPage)     → cursor next
//     SELECT                             → pick up / place / smart move
//     BACK button                        → play → menu → exit app
//
//   Touch:
//     Tap          → cursor jumps to the tapped pile (+ pick up when nothing
//                    is held); when a pile is held, tapping elsewhere does
//                    nothing (you must deselect first)
//     Drag         → cursor follows the finger across piles
//     Swipe L / R  → cursor one step left / right
//
// PHANTOM-BACK GUARD
//   On touch Garmin devices a swipe-right is often delivered to the app as an
//   onBack() right after the gesture, which would kick the player out of the
//   game.  We timestamp every touch gesture and swallow any onBack() that lands
//   within PHANTOM_BACK_MS of one.  A real BACK button press (not preceded by a
//   gesture) passes through normally.
class SolitaireDelegate extends WatchUi.BehaviorDelegate {
    hidden var _v;
    hidden var _lastGestureMs;
    hidden var _lastDragMs;
    hidden const PHANTOM_BACK_MS = 700;
    hidden const DRAG_SWIPE_GUARD_MS = 250;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _v = view;
        _lastGestureMs = 0;
        _lastDragMs = 0;
    }

    hidden function _markGesture() { _lastGestureMs = System.getTimer(); }

    hidden function _isPhantomBack() {
        if (_lastGestureMs == 0) { return false; }
        var dt = System.getTimer() - _lastGestureMs;
        return (dt >= 0 && dt < PHANTOM_BACK_MS);
    }

    function onSelect()       { _v.doSelect(); WatchUi.requestUpdate(); return true; }
    function onPreviousPage() { _v.doUp();     WatchUi.requestUpdate(); return true; }
    function onNextPage()     { _v.doDown();   WatchUi.requestUpdate(); return true; }

    function onBack() {
        if (_isPhantomBack()) { _lastGestureMs = 0; return true; }
        var h = _v.doBack();
        WatchUi.requestUpdate();
        return h;
    }

    function onSwipe(evt) {
        _markGesture();
        // If a drag just moved the cursor (finger-follow), ignore the trailing
        // swipe so the cursor doesn't jump an extra step.
        var dt = System.getTimer() - _lastDragMs;
        if (_lastDragMs != 0 && dt >= 0 && dt < DRAG_SWIPE_GUARD_MS) {
            return true;
        }
        _v.doSwipe(evt.getDirection());
        WatchUi.requestUpdate();
        return true;
    }

    function onDrag(evt) {
        _markGesture();
        _lastDragMs = System.getTimer();
        var c = evt.getCoordinates();
        if (c != null) { _v.doDrag(c[0], c[1]); }
        WatchUi.requestUpdate();
        return true;
    }

    function onTap(evt) {
        _markGesture();
        var c = evt.getCoordinates();
        if (c != null) { _v.doTap(c[0], c[1]); }
        WatchUi.requestUpdate();
        return true;
    }
}
