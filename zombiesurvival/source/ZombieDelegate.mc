// ═══════════════════════════════════════════════════════════════════════════
// ZombieDelegate.mc — Input.
//
// There is very little to map, which is the point: a sideways flick walks the
// five pages, UP and DOWN move the cursor on whichever one is open, and SELECT
// buys, opens or answers. The only input that touches the simulation is SELECT
// while a wave is playing, and all that does is fire your rifle at whatever is
// nearest — there is no aiming and no lane to pick.
//
// Flicks are measured from raw drag coordinates rather than from onSwipe: a
// rightward flick is the system back gesture on Garmin touch panels, so
// SWIPE_RIGHT never arrives and the page would only ever turn one way.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.System;

class ZombieDelegate extends WatchUi.BehaviorDelegate {
    hidden var _v;
    hidden var _held;          // press/release supported → suppress the onKey
    hidden var _lastGestureMs;
    hidden var _flickMs;
    hidden var _dragX; hidden var _dragY;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _v = view;
        _held = false;
        _lastGestureMs = 0;
        _flickMs = 0;
        _dragX = -1; _dragY = -1;
    }

    hidden function _mark() { _lastGestureMs = System.getTimer(); }
    hidden function _isPhantomBack() {
        if (_lastGestureMs == 0) { return false; }
        var dt = System.getTimer() - _lastGestureMs;
        return (dt >= 0 && dt < 800);
    }
    hidden function _flickHandled() {
        if (_flickMs == 0) { return false; }
        var dt = System.getTimer() - _flickMs;
        return (dt >= 0 && dt < 500);
    }

    hidden function _isTrigger(k) {
        return k == WatchUi.KEY_ENTER || k == WatchUi.KEY_START;
    }

    // Holding SELECT through a wave keeps the rifle firing at its own rate.
    function onKeyPressed(evt) {
        var k = evt.getKey();
        if (_isTrigger(k) && _v.isWatching()) {
            _held = true;
            _v.holdFire(true);
            return true;
        }
        return false;
    }

    function onKeyReleased(evt) {
        var k = evt.getKey();
        if (_isTrigger(k) && _held) {
            _held = false;
            _v.holdFire(false);
            return true;
        }
        return false;
    }

    function onKey(evt) {
        var k = evt.getKey();
        if (_isTrigger(k)) {
            if (_held) { return true; }
            _v.activate();
            return true;
        }
        if (k == WatchUi.KEY_UP)   { _v.move(-1); return true; }
        if (k == WatchUi.KEY_DOWN) { _v.move(1);  return true; }
        if (k == WatchUi.KEY_ESC)  { return onBack(); }
        return false;
    }

    function onSelect() {
        if (_held) { return true; }
        _v.activate();
        return true;
    }

    function onNextPage() {
        if (_flickHandled()) { return true; }
        _v.move(1);
        return true;
    }
    function onPreviousPage() {
        if (_flickHandled()) { return true; }
        _v.move(-1);
        return true;
    }

    // Fallback for panels that report no drag coordinates.
    function onSwipe(evt) {
        _mark();
        if (_flickHandled()) { return true; }
        var d = evt.getDirection();
        if (d == WatchUi.SWIPE_UP)    { _v.move(-1); return true; }
        if (d == WatchUi.SWIPE_DOWN)  { _v.move(1);  return true; }
        if (d == WatchUi.SWIPE_LEFT)  { return _v.page(1); }
        if (d == WatchUi.SWIPE_RIGHT) { return _v.page(-1); }
        return false;
    }

    function onDrag(evt) {
        _mark();
        var c = null;
        try { c = evt.getCoordinates(); } catch (e) { c = null; }
        if (c == null) { return true; }
        var t = evt.getType();
        if (t == WatchUi.DRAG_TYPE_START) {
            _dragX = c[0]; _dragY = c[1];
            return true;
        }
        if (t != WatchUi.DRAG_TYPE_STOP || _dragX < 0) { return true; }

        var dx = c[0] - _dragX;
        var dy = c[1] - _dragY;
        _dragX = -1; _dragY = -1;
        var adx = (dx < 0) ? -dx : dx;
        var ady = (dy < 0) ? -dy : dy;
        // Below the threshold the panel reports a tap instead, which is what
        // keeps a poke on a row meaning "buy this".
        if (adx < 28 && ady < 28) { return true; }

        _flickMs = System.getTimer();
        if (adx >= ady) { _v.page(dx > 0 ? -1 : 1); }
        else { _v.move(dy > 0 ? -1 : 1); }
        WatchUi.requestUpdate();
        return true;
    }

    function onTap(evt) {
        _mark();
        if (_flickHandled()) { return true; }
        var c = evt.getCoordinates();
        return _v.onTapXY(c[0], c[1]);
    }

    function onBack() {
        if (_isPhantomBack()) {
            _lastGestureMs = 0;
            return true;
        }
        try { if (_v.back()) { return true; } } catch (e) {}
        try { _v.model().save(); } catch (e) {}
        return false;
    }
}
