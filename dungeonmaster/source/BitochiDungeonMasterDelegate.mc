// ═══════════════════════════════════════════════════════════════════════════
// BitochiDungeonMasterDelegate.mc — Input.
//
// Classic crawler controls squeezed onto a watch. The design rule: a fenix with
// no touchscreen must be able to reach every system — spells, items, gear, map
// — using only SELECT, UP, DOWN, MENU and BACK.
//
//   SELECT / tap        context action, and "confirm" in every menu
//   UP / DOWN           turn left / right, and move the cursor in every menu
//   MENU (long SELECT)  open the pack; press again to cycle its pages
//   BACK                leave a submenu, then offer to save and exit
//   swipe               up walks, down searches, left/right turn
//
// Flicks are measured from raw drag coordinates rather than from onSwipe. A
// rightward flick is the system back gesture on Garmin touch panels: the
// firmware consumes it and delivers onBack, so SWIPE_RIGHT never arrives and
// turning right was dead — it opened the save-and-exit prompt instead.
// Tracking DRAG_TYPE_START to DRAG_TYPE_STOP gives a direction on every
// device, and the phantom onBack that follows is swallowed by the guard below.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.System;

class BitochiDungeonMasterDelegate extends WatchUi.BehaviorDelegate {

    hidden var _view;
    hidden var _lastGestureMs;
    hidden var _flickMs;
    hidden var _dragX;
    hidden var _dragY;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
        _lastGestureMs = 0;
        _flickMs = 0;
        _dragX = -1;
        _dragY = -1;
    }

    hidden function _mark() { _lastGestureMs = System.getTimer(); }

    hidden function _isPhantomBack() {
        if (_lastGestureMs == 0) { return false; }
        var dt = System.getTimer() - _lastGestureMs;
        return (dt >= 0 && dt < 800);
    }

    // True while the raw-drag handler owns the current finger movement, so the
    // system's own gesture events for it do not fire the action a second time.
    hidden function _flickHandled() {
        if (_flickMs == 0) { return false; }
        var dt = System.getTimer() - _flickMs;
        return (dt >= 0 && dt < 500);
    }

    function onSelect() {
        _view.advance();
        WatchUi.requestUpdate();
        return true;
    }

    function onMenu() {
        _view.toggleInventory();
        WatchUi.requestUpdate();
        return true;
    }

    function onPreviousPage() {
        if (_flickHandled()) { return true; }
        _view.turn(-1);
        WatchUi.requestUpdate();
        return true;
    }

    function onNextPage() {
        if (_flickHandled()) { return true; }
        _view.turn(1);
        WatchUi.requestUpdate();
        return true;
    }

    function onTap(evt) {
        _mark();
        if (_flickHandled()) { return true; }
        _view.advance();
        WatchUi.requestUpdate();
        return true;
    }

    // Fallback for panels that report no drag coordinates. It stands down
    // whenever the raw-drag path has just acted on the same movement.
    function onSwipe(evt) {
        _mark();
        if (_flickHandled()) { return true; }
        var d = evt.getDirection();
        if (d == WatchUi.SWIPE_UP) {
            _view.advance();
        } else if (d == WatchUi.SWIPE_DOWN) {
            _view.interact();
        } else if (d == WatchUi.SWIPE_LEFT) {
            _view.turn(-1);
        } else if (d == WatchUi.SWIPE_RIGHT) {
            _view.turn(1);
        } else {
            return true;
        }
        WatchUi.requestUpdate();
        return true;
    }

    // Raw flick detection. Deltas are pixel travel, so a positive dx always
    // means the finger went right no matter what the firmware calls it.
    function onDrag(evt) {
        _mark();
        var c = null;
        try { c = evt.getCoordinates(); } catch (e) { c = null; }
        if (c == null) { return true; }
        var t = evt.getType();
        if (t == WatchUi.DRAG_TYPE_START) {
            _dragX = c[0];
            _dragY = c[1];
            return true;
        }
        if (t != WatchUi.DRAG_TYPE_STOP || _dragX < 0) { return true; }

        var dx = c[0] - _dragX;
        var dy = c[1] - _dragY;
        _dragX = -1;
        _dragY = -1;
        var adx = (dx < 0) ? -dx : dx;
        var ady = (dy < 0) ? -dy : dy;
        // Below the threshold the panel reports a tap instead, which is what
        // keeps a poke on the screen meaning "advance".
        var minTravel = _view.width() / 8;
        if (minTravel < 16) { minTravel = 16; }
        if (adx < minTravel && ady < minTravel) { return true; }

        _flickMs = System.getTimer();
        if (adx >= ady) { _view.turn(dx > 0 ? 1 : -1); }
        else if (dy < 0) { _view.advance(); }
        else { _view.interact(); }
        WatchUi.requestUpdate();
        return true;
    }

    function onBack() {
        // A rightward flick arrives here as well as at onDrag; swallow it, or
        // turning right would also offer to quit the run.
        if (_isPhantomBack()) {
            _lastGestureMs = 0;
            return true;
        }
        // BACK first backs out of an overlay or combat submenu, and only then
        // offers to save.
        if (_view.closeOverlay()) {
            WatchUi.requestUpdate();
            return true;
        }
        return SaveResume.confirmExit("dungeonmaster", _view.method(:exportSave));
    }
}
