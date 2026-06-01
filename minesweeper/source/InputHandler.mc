// ─────────────────────────────────────────────────────────────────
// InputHandler.mc
//
// Physical buttons:
//   DOWN (bottom) → cursor right (col++ wrap)    via onNextPage / KEY_DOWN
//   UP   (upper)  → cursor down  (row++ wrap)    via onPreviousPage / KEY_UP
//   SELECT        → reveal cell at cursor         via onSelect
//   HOLD          → flag cell at cursor           via onHold
//
// Touch:
//   Tap cell      → reveal that cell
//
// IMPORTANT: onKey's else-branch is intentionally empty.
//   Some Garmin firmware fires KEY_ENTER alongside onNextPage/
//   onPreviousPage. Mapping the else-branch to reveal would cause
//   every cursor-move press to also blow open the cell.
// ─────────────────────────────────────────────────────────────────

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
        if      (k == WatchUi.KEY_DOWN) { _v.navHoriz();  }
        else if (k == WatchUi.KEY_UP)   { _v.navVert();   }
        else if (k == WatchUi.KEY_ESC)  { return onBack(); }
        // All other key codes are intentionally ignored here.
        // Reveal is triggered ONLY by onSelect() below.
        WatchUi.requestUpdate();
        return true;
    }

    // These fire when the physical UP/DOWN buttons are pressed on
    // devices that route navigation buttons through page-scroll events.
    function onNextPage()     { _v.navHoriz();  WatchUi.requestUpdate(); return true; }
    function onPreviousPage() { _v.navVert();   WatchUi.requestUpdate(); return true; }

    // SELECT / crown: reveal the cursor cell (or activate menu row).
    function onSelect() { _v.navReveal(); WatchUi.requestUpdate(); return true; }

    // Long press: flag the cursor cell.
    function onHold(evt) { _v.navFlag(); WatchUi.requestUpdate(); return true; }

    // Tap on board: reveal the tapped cell.
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
