// ═══════════════════════════════════════════════════════════════
// InputHandler.mc — Gameplay input for the live match view.
//
// The main menu is the shared GameMenuView (a separate root view), so this
// delegate only handles play / serve / game-over. BACK pops back to the menu.
//
// Buttons
//   GS_PLAY / GS_SERVE
//     UP pressed/released   → continuous paddle "up" hold
//     DOWN pressed/released → continuous paddle "down" hold
//     BACK                  → return to the menu (pop)
//   GS_OVER
//     SELECT / tap / swipe   → rematch
//     BACK                   → return to the menu (pop)
//
// Touch
//   GS_PLAY: tap upper half → impulse up; lower half → impulse down;
//            swipe up/down → impulse in that direction.
//   GS_OVER: tap / swipe → rematch.
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.System;

class InputHandler extends WatchUi.BehaviorDelegate {
    hidden var _v;
    // Phantom-back guard — a touch gesture can emit a spurious BACK on some
    // firmwares right after a tap/swipe; swallow one BACK within 500 ms.
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
        if (!_v.isInMatch()) { return false; }
        var k = evt.getKey();
        if      (k == WatchUi.KEY_UP)   { _v.holdUp(true);   return true; }
        else if (k == WatchUi.KEY_DOWN) { _v.holdDown(true); return true; }
        return false;
    }
    function onKeyReleased(evt) {
        if (!_v.isInMatch()) { return false; }
        var k = evt.getKey();
        if      (k == WatchUi.KEY_UP)   { _v.holdUp(false);   return true; }
        else if (k == WatchUi.KEY_DOWN) { _v.holdDown(false); return true; }
        return false;
    }

    function onKey(evt) {
        var k = evt.getKey();
        if (k == WatchUi.KEY_ESC) { return onBack(); }
        if (_v.isOver() && k == WatchUi.KEY_ENTER) {
            _v.restart(); WatchUi.requestUpdate(); return true;
        }
        return false;
    }

    function onSelect() {
        if (_v.isOver()) { _v.restart(); WatchUi.requestUpdate(); return true; }
        return false;
    }

    function onTap(evt) {
        _markGesture();
        var xy = evt.getCoordinates();
        _v.handleTap(xy[0], xy[1]);
        WatchUi.requestUpdate();
        return true;
    }

    function onSwipe(evt) {
        _markGesture();
        if (_v.isOver()) { _v.restart(); WatchUi.requestUpdate(); return true; }
        var d = evt.getDirection();
        if      (d == WatchUi.SWIPE_UP)   { _v.impulse(-1); }
        else if (d == WatchUi.SWIPE_DOWN) { _v.impulse( 1); }
        WatchUi.requestUpdate();
        return true;
    }

    function onBack() {
        if (_isPhantomBack()) { _lastGestureMs = 0; return true; }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);   // back to the shared menu
        return true;
    }
}
