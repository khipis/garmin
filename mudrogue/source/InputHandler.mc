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

class InputHandler extends WatchUi.BehaviorDelegate {
    hidden var _v;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _v = view;
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
        var xy = evt.getCoordinates();
        _v.handleTap(xy[0], xy[1]);
        WatchUi.requestUpdate();
        return true;
    }
    function onSwipe(evt) {
        var d = evt.getDirection();
        if      (d == WatchUi.SWIPE_UP)   { _v.navUp();   }
        else if (d == WatchUi.SWIPE_DOWN) { _v.navDown(); }
        else                              { _v.navSelect();}
        WatchUi.requestUpdate();
        return true;
    }

    function onBack() {
        if (_v.handleBack()) {
            WatchUi.requestUpdate();
            return true;
        }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
