// ═══════════════════════════════════════════════════════════════
// InputHandler.mc — Map inputs to menu navigation + paddle motion.
//
// Buttons
//   In GS_MENU
//     UP / DOWN           → cycle difficulty (prev / next)
//     SELECT / ENTER      → START match
//     BACK                → exit app
//
//   In GS_PLAY / GS_SERVE
//     UP pressed/released   → continuous paddle "up" hold
//     DOWN pressed/released → continuous paddle "down" hold
//     SELECT                → no-op (paddle already held by UP/DOWN)
//     BACK                  → return to menu
//
//   In GS_OVER
//     any input              → return to menu
//
// Touch
//   GS_MENU: tap on a difficulty pill picks it; tap anywhere else
//            STARTS the match.
//   GS_PLAY: tap upper half → impulse up; tap lower half → impulse
//            down; swipe up/down → impulse in that direction.
//   GS_OVER: tap → return to menu.
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
        // Paddle hold only applies while a match is live. In menu /
        // over states UP/DOWN are routed through onKey() below so we
        // never start a phantom "hold" that lingers into the next
        // match.
        if (!_v.isInMatch()) { return false; }
        var k = evt.getKey();
        if      (k == WatchUi.KEY_UP)    { _v.holdUp(true);   return true; }
        else if (k == WatchUi.KEY_DOWN)  { _v.holdDown(true); return true; }
        return false;
    }
    function onKeyReleased(evt) {
        if (!_v.isInMatch()) { return false; }
        var k = evt.getKey();
        if      (k == WatchUi.KEY_UP)    { _v.holdUp(false);   return true; }
        else if (k == WatchUi.KEY_DOWN)  { _v.holdDown(false); return true; }
        return false;
    }

    function onKey(evt) {
        var k = evt.getKey();
        if (k == WatchUi.KEY_ESC) { return onBack(); }
        if (_v.isMenu()) {
            if      (k == WatchUi.KEY_UP)    { _v.menuPrev();  WatchUi.requestUpdate(); return true; }
            else if (k == WatchUi.KEY_DOWN)  { _v.menuNext();  WatchUi.requestUpdate(); return true; }
            else if (k == WatchUi.KEY_ENTER) { _v.menuStart(); WatchUi.requestUpdate(); return true; }
            return false;
        }
        if (_v.isOver()) {
            _v.gotoMenu();
            WatchUi.requestUpdate();
            return true;
        }
        return false;
    }

    function onSelect() {
        if (_v.isMenu()) { _v.menuStart(); WatchUi.requestUpdate(); return true; }
        if (_v.isOver()) { _v.gotoMenu(); WatchUi.requestUpdate(); return true; }
        return false;
    }

    // BehaviorDelegate convenience routes — make sure page-up /
    // page-down also cycle difficulty in the menu.
    function onNextPage() {
        if (_v.isMenu()) { _v.menuNext(); WatchUi.requestUpdate(); return true; }
        return false;
    }
    function onPreviousPage() {
        if (_v.isMenu()) { _v.menuPrev(); WatchUi.requestUpdate(); return true; }
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
        var d = evt.getDirection();
        if (_v.isMenu()) {
            if (d == WatchUi.SWIPE_UP)   { _v.menuPrev();  }
            else if (d == WatchUi.SWIPE_DOWN) { _v.menuNext();  }
            else                              { _v.menuStart(); }
            WatchUi.requestUpdate();
            return true;
        }
        if (_v.isOver()) {
            _v.gotoMenu();
            WatchUi.requestUpdate();
            return true;
        }
        if      (d == WatchUi.SWIPE_UP)   { _v.impulse(-1); }
        else if (d == WatchUi.SWIPE_DOWN) { _v.impulse( 1); }
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
