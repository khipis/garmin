// ═══════════════════════════════════════════════════════════════
// InputHandler.mc — Routes all watch input to the active game state.
//
// Button mapping (Fenix-style 5-button layout):
//   KEY_UP    / KEY_MENU  → menu cursor up   /  in-game: cycle digit UP
//   KEY_DOWN              → menu cursor down /  in-game: cycle digit DOWN
//   KEY_ENTER / SELECT    → confirm menu / in-game cell move-right
//   KEY_ESC / BACK        → menu: exit, in-game: pause → menu
//
// Touchscreen (where available):
//   onTap on grid cell      → select that cell
//   onTap on number bar     → place that digit (long-press = clear)
//   onSwipe                 → move cursor (4 directions)
//
// The handler keeps the View only loosely coupled to specific keys —
// MainView exposes high-level intents (cellAction, navAction, …).
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
        else if (k == WatchUi.KEY_MENU)  { _v.navUp();    }
        else if (k == WatchUi.KEY_DOWN)  { _v.navDown();  }
        else if (k == WatchUi.KEY_ESC)   { return onBack(); }
        else                              { _v.navSelect(); }
        WatchUi.requestUpdate();
        return true;
    }

    function onSelect() {
        _v.navSelect();
        WatchUi.requestUpdate();
        return true;
    }

    function onBack() {
        if (_isPhantomBack()) { _lastGestureMs = 0; return true; }
        var consumed = _v.navBack();
        WatchUi.requestUpdate();
        if (consumed) { return true; }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    function onPreviousPage() {
        _v.navUp();
        WatchUi.requestUpdate();
        return true;
    }

    function onNextPage() {
        _v.navDown();
        WatchUi.requestUpdate();
        return true;
    }

    function onTap(evt) {
        _markGesture();
        var xy = evt.getCoordinates();
        _v.handleTap(xy[0], xy[1]);
        WatchUi.requestUpdate();
        return true;
    }

    // Long-tap (held) on grid = clear current cell.
    function onHold(evt) {
        var xy = evt.getCoordinates();
        _v.handleHold(xy[0], xy[1]);
        WatchUi.requestUpdate();
        return true;
    }

    function onSwipe(evt) {
        _markGesture();
        var dir = evt.getDirection();
        _v.handleSwipe(dir);
        WatchUi.requestUpdate();
        return true;
    }
}
