// ═══════════════════════════════════════════════════════════════
// InputHandler.mc — Map keys / taps to cursor + confirm.
//
// Buttons
//   KEY_UP   → cursor up   (cycles)
//   KEY_DOWN → cursor down (cycles)
//   KEY_ENTER / SELECT → confirm current option
//   KEY_ESC  → back / pause confirm
//
// Touch
//   Tap on an option row → move cursor + confirm
//   Tap anywhere else    → confirm (useful for single-button screens)
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

    function onKey(evt) {
        var k = evt.getKey();
        if      (k == WatchUi.KEY_UP)    { _v.navUp();    }
        else if (k == WatchUi.KEY_DOWN)  { _v.navDown();  }
        else if (k == WatchUi.KEY_ESC)   { return onBack(); }
        else                              { _v.navSelect(); }
        WatchUi.requestUpdate();
        return true;
    }
    function onSelect()       { _v.navSelect(); WatchUi.requestUpdate(); return true; }
    function onPreviousPage() { _v.navUp();     WatchUi.requestUpdate(); return true; }
    function onNextPage()     { _v.navDown();   WatchUi.requestUpdate(); return true; }

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
        if      (d == WatchUi.SWIPE_UP)   { _v.navUp();   }
        else if (d == WatchUi.SWIPE_DOWN) { _v.navDown(); }
        else                              { _v.navSelect();}
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
