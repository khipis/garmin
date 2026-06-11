// ═══════════════════════════════════════════════════════════════
// InputHandler.mc — Every input is a "flap" (single action game).
//
// BACK gives the player a way out of the game / overlay loop.
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.System;

class InputHandler extends WatchUi.BehaviorDelegate {
    hidden var _v;
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

    function onKey(evt) {
        var k = evt.getKey();
        if (k == WatchUi.KEY_ESC) { return onBack(); }
        // MENU only: a discrete button (UP / MENU) opens the leaderboard.
        // In-game these keys still flap (gameplay untouched).
        if (_v.inMenu() && (k == WatchUi.KEY_UP || k == WatchUi.KEY_MENU)) {
            _v.openLeaderboard();
            return true;
        }
        _v.handleFlap();
        WatchUi.requestUpdate();
        return true;
    }
    function onSelect()       { _v.handleFlap(); WatchUi.requestUpdate(); return true; }
    function onMenu() {
        if (_v.inMenu()) { _v.openLeaderboard(); return true; }
        _v.handleFlap(); WatchUi.requestUpdate(); return true;
    }
    // Page-up on the menu opens the board; otherwise it flaps as before.
    function onPreviousPage() {
        if (_v.inMenu()) { _v.openLeaderboard(); return true; }
        _v.handleFlap(); WatchUi.requestUpdate(); return true;
    }
    function onNextPage()     { _v.handleFlap(); WatchUi.requestUpdate(); return true; }
    function onTap(evt) {
        _markGesture();
        var c = evt.getCoordinates();
        _v.handleTap(c[0], c[1]);
        WatchUi.requestUpdate();
        return true;
    }
    function onSwipe(evt)     { _markGesture(); _v.handleFlap(); WatchUi.requestUpdate(); return true; }
    function onHold(evt)      { _v.handleFlap(); WatchUi.requestUpdate(); return true; }

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
