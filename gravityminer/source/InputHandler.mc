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
        if      (k == WatchUi.KEY_DOWN) { _v.navHoriz(); }
        else if (k == WatchUi.KEY_UP)   { _v.navVert();  }
        else if (k == WatchUi.KEY_ESC)  { return onBack(); }
        WatchUi.requestUpdate();
        return true;
    }
    function onNextPage()     { _v.navHoriz(); WatchUi.requestUpdate(); return true; }
    function onPreviousPage() { _v.navVert();  WatchUi.requestUpdate(); return true; }
    function onSelect()       { _v.navSelect(); WatchUi.requestUpdate(); return true; }
    function onTap(evt) {
        _markGesture();
        var xy = evt.getCoordinates();
        _v.handleTap(xy[0], xy[1]);
        WatchUi.requestUpdate();
        return true;
    }
    function onSwipe(evt) { _markGesture(); return true; }
    function onBack() {
        if (_isPhantomBack()) { _lastGestureMs = 0; return true; }
        if (_v.navBack()) { WatchUi.requestUpdate(); return true; }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
