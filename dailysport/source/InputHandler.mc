// ═══════════════════════════════════════════════════════════════════════════
// InputHandler.mc — One-button controls.
//
// SELECT / tap / any key drives the whole shot: lock the angle, lock the
// power, hit the release. Timing is the game, so every path funnels into the
// same press() with no extra decisions in between.
//
// BACK ends a live run into the result card, and pops to the shared menu from
// there. A short guard swallows the phantom BACK some firmwares emit right
// after a swipe.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Lang;
using Toybox.System;
using Toybox.WatchUi;

class InputHandler extends WatchUi.BehaviorDelegate {

    hidden var _v;
    hidden var _lastGestureMs;

    function initialize(view as MainView) {
        BehaviorDelegate.initialize();
        _v = view;
        _lastGestureMs = 0;
    }

    hidden function _phantomBack() as Lang.Boolean {
        if (_lastGestureMs == 0) { return false; }
        var dt = System.getTimer() - _lastGestureMs;
        return (dt >= 0 && dt < 500);
    }

    function onKey(evt) {
        var k = evt.getKey();
        if (k == WatchUi.KEY_ESC) { return onBack(); }
        _v.press();
        WatchUi.requestUpdate();
        return true;
    }

    function onSelect()       { _v.press(); WatchUi.requestUpdate(); return true; }
    function onNextPage()     { _v.press(); WatchUi.requestUpdate(); return true; }
    function onPreviousPage() { _v.press(); WatchUi.requestUpdate(); return true; }

    function onTap(evt) {
        _lastGestureMs = System.getTimer();
        _v.press();
        WatchUi.requestUpdate();
        return true;
    }

    function onSwipe(evt) {
        _lastGestureMs = System.getTimer();
        _v.press();
        WatchUi.requestUpdate();
        return true;
    }

    function onBack() {
        if (_phantomBack()) { _lastGestureMs = 0; return true; }
        if (_v.back()) { WatchUi.requestUpdate(); return true; }
        return false;
    }
}
