// ═══════════════════════════════════════════════════════════════════════════
// BackroomsDelegate.mc — Input manager.
//
// Gestures first (swipe up walks, left/right turn, down uses), with the same
// intents mirrored onto physical keys and tap zones so the game is fully
// playable on button-only watches.
//
// Flicks are measured from raw drag coordinates, not from onSwipe. A rightward
// flick is the system back gesture on Garmin touch panels: the firmware eats
// it and delivers onBack, so SWIPE_RIGHT never arrives and turning right is
// simply dead. Tracking DRAG_TYPE_START to DRAG_TYPE_STOP ourselves gives a
// direction on every device, and the phantom onBack that follows is swallowed
// by the guard below. onSwipe stays as a fallback for panels that report no
// drag coordinates, and stands down whenever the drag path has just acted.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.System;

class BackroomsDelegate extends WatchUi.BehaviorDelegate {
    hidden var _v;
    hidden var _lastGestureMs;
    hidden var _flickMs;      // a drag-derived flick just acted
    hidden var _dragX;
    hidden var _dragY;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _v = view;
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

    // ── Keys ─────────────────────────────────────────────────────────────────
    // Physical UP/DOWN steer. Consuming them here also stops the firmware from
    // turning them into page behaviours, which leaves onPreviousPage /
    // onNextPage free to mean what a *swipe* up or down means.
    function onKey(evt) {
        var k = evt.getKey();
        if (k == WatchUi.KEY_ENTER || k == WatchUi.KEY_START) { _v.doForward(); return true; }
        if (k == WatchUi.KEY_UP)   { _v.doTurn(-1); return true; }
        if (k == WatchUi.KEY_DOWN) { _v.doTurn(1);  return true; }
        if (k == WatchUi.KEY_MENU) { _v.doSprint(); return true; }
        // The torch belongs on the light button and nowhere else.
        if (k == WatchUi.KEY_LIGHT) { _v.doTorch(); return true; }
        if (k == WatchUi.KEY_ESC)  { return onBack(); }
        return false;
    }

    function onSelect() { _v.doForward(); return true; }
    function onMenu() { _v.doSprint(); return true; }

    // Touch watches have no light button, so a long press anywhere is the
    // torch. It is also the natural panic gesture: grab the screen and hold.
    function onHold(evt) {
        _mark();
        _v.doTorch();
        WatchUi.requestUpdate();
        return true;
    }

    // Swipe up / swipe down reach us as page behaviours on touch watches.
    // Swiping up pages *forward*, which is also how it should read here.
    function onNextPage() {
        if (_flickHandled()) { return true; }
        _v.doForward();
        return true;
    }

    function onPreviousPage() {
        if (_flickHandled()) { return true; }
        _v.doInteract();
        return true;
    }

    // ── Gestures ─────────────────────────────────────────────────────────────

    function onSwipe(evt) {
        _mark();
        if (_flickHandled()) { return true; }
        var d = evt.getDirection();
        if (d == WatchUi.SWIPE_UP)         { _v.doForward(); }
        else if (d == WatchUi.SWIPE_LEFT)  { _v.doTurn(-1); }
        else if (d == WatchUi.SWIPE_RIGHT) { _v.doTurn(1); }
        else if (d == WatchUi.SWIPE_DOWN)  { _v.doInteract(); }
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
        // Below the threshold the panel will report a tap instead; leaving it
        // alone here is what keeps the tap zones working.
        var minTravel = _v.width() / 8;
        if (minTravel < 16) { minTravel = 16; }
        if (adx < minTravel && ady < minTravel) { return true; }

        _flickMs = System.getTimer();
        if (adx >= ady) { _v.doTurn(dx > 0 ? 1 : -1); }
        else if (dy < 0) { _v.doForward(); }
        else { _v.doInteract(); }
        WatchUi.requestUpdate();
        return true;
    }

    // Tap zones for anyone who would rather poke than swipe. Some panels report
    // no coordinates at all, in which case a tap is simply a step forward.
    function onTap(evt) {
        _mark();
        if (_flickHandled()) { return true; }
        var c = null;
        try { c = evt.getCoordinates(); } catch (e) { c = null; }
        var w = _v.width(); var h = _v.height();
        if (c == null || w <= 0 || h <= 0) {
            _v.doForward();
            WatchUi.requestUpdate();
            return true;
        }
        var x = c[0]; var y = c[1];
        if (y < h * 40 / 100)      { _v.doForward(); }
        else if (y > h * 78 / 100) { _v.doInteract(); }
        else if (x < w * 35 / 100) { _v.doTurn(-1); }
        else if (x > w * 65 / 100) { _v.doTurn(1); }
        else                       { _v.doForward(); }
        WatchUi.requestUpdate();
        return true;
    }

    function onBack() {
        if (_isPhantomBack()) {
            _lastGestureMs = 0;
            return true;
        }
        if (_v.isEnded()) {
            try { WatchUi.popView(WatchUi.SLIDE_RIGHT); } catch (e) {}
            return true;
        }
        return SaveResume.confirmExit(Br.GAME_ID, _v.method(:exportSave));
    }
}
