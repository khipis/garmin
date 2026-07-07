using Toybox.WatchUi;
using Toybox.System;

// ═══════════════════════════════════════════════════════════════════════════
//  Input routing for chess.
//
//  Touch design — "tap-select + flick-to-move" (same model as gemmatch)
//  ────────────────────────────────────────────────────────────────────────
//  The old model let the highlight FOLLOW the finger and committed the square
//  under the LIFT point — so any drift between touch-down and lift landed on
//  the wrong square. Garmin panels routinely report a tap as a tiny drag, so
//  that drift was common and the selection felt imprecise.
//
//  Now:
//    • TOUCH-DOWN commits the square the finger FIRST landed on (via doTap).
//      Tapping your piece selects it; tapping a highlighted square moves there
//      — always exactly where you touched, never a drifted neighbour.
//    • A FLICK (finger travels past a cell-scaled threshold) on a just-grabbed
//      piece moves it toward the legal destination in the swipe direction —
//      grab-and-flick, one gesture.
//    • Each physical gesture commits exactly once: the tap fires on START, a
//      flick fires on CONTINUE, and a short swipe-guard drops the trailing
//      onTap/onSwipe echo the panel tacks on after a drag.
// ═══════════════════════════════════════════════════════════════════════════
class BitochiChessDelegate extends WatchUi.BehaviorDelegate {
    hidden var _view;

    hidden var _dragging;
    hidden var _downX; hidden var _downY;
    hidden var _actedOnStart;   // START already committed the down square
    hidden var _committed;      // a flick already fired this gesture
    hidden var _lastTapMs;
    hidden var _swipeGuardMs;

    // Suppress a duplicate tap arriving this soon after one was handled.
    hidden const _TAP_DEDUPE_MS  = 180;
    // A drag-flick's trailing onTap/onSwipe echo is ignored inside this window.
    hidden const _SWIPE_GUARD_MS = 320;
    // Fallback swipe threshold (px) if the board size isn't known yet.
    hidden const _SWIPE_MIN_FALLBACK = 16;

    // After a drag/swipe the touch panel routinely emits a spurious onBack a
    // few hundred ms later. Swallow it so a "move the piece" drag can never
    // bounce the player out of the game.
    hidden var _lastGestureMs;
    hidden const _PHANTOM_BACK_MS = 500;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view          = view;
        _dragging      = false;
        _downX         = -1;
        _downY         = -1;
        _actedOnStart  = false;
        _committed     = false;
        _lastTapMs     = 0;
        _swipeGuardMs  = 0;
        _lastGestureMs = 0;
    }

    hidden function _markGesture() { _lastGestureMs = System.getTimer(); }
    hidden function _isPhantomBack() {
        if (_lastGestureMs == 0) { return false; }
        var dt = System.getTimer() - _lastGestureMs;
        return (dt >= 0 && dt < _PHANTOM_BACK_MS);
    }

    // Flick becomes a swipe past ~55% of a cell (min 16px) so a deliberate tap
    // — even a slightly sloppy one — never trips a move.
    hidden function _swipeMin() {
        var c = _view.cellSize();
        if (c == null || c <= 0) { return _SWIPE_MIN_FALLBACK; }
        var t = c * 55 / 100;
        return (t < _SWIPE_MIN_FALLBACK) ? _SWIPE_MIN_FALLBACK : t;
    }

    hidden function _inSwipeGuard() {
        if (_swipeGuardMs == 0) { return false; }
        var dt = System.getTimer() - _swipeGuardMs;
        return (dt >= 0 && dt < _SWIPE_GUARD_MS);
    }

    function onSelect() {
        _view.doSelect();
        WatchUi.requestUpdate();
        return true;
    }

    function onBack() {
        // Ignore the phantom back the panel fires right after a drag/swipe so a
        // piece-move gesture can't exit the game.
        if (_isPhantomBack()) { _lastGestureMs = 0; return true; }
        var h = _view.doBack();
        WatchUi.requestUpdate();
        return h;
    }

    function onMenu() {
        var h = _view.doBack();
        WatchUi.requestUpdate();
        return h;
    }

    function onPreviousPage() {
        _view.doPrev();
        WatchUi.requestUpdate();
        return true;
    }

    function onNextPage() {
        _view.doNext();
        WatchUi.requestUpdate();
        return true;
    }

    // ── Touch ────────────────────────────────────────────────────────────────
    hidden function _commit(px, py) {
        _lastTapMs = System.getTimer();
        _view.doTap(px, py);
        WatchUi.requestUpdate();
    }

    hidden function _recentlyTapped() {
        if (_lastTapMs == 0) { return false; }
        var dt = System.getTimer() - _lastTapMs;
        return (dt >= 0 && dt < _TAP_DEDUPE_MS);
    }

    // Map a 4-way swipe to a unit screen vector for flickMove.
    hidden function _swipeVec(d) {
        if      (d == WatchUi.SWIPE_UP)    { return [0, -1]; }
        else if (d == WatchUi.SWIPE_DOWN)  { return [0,  1]; }
        else if (d == WatchUi.SWIPE_LEFT)  { return [-1, 0]; }
        else if (d == WatchUi.SWIPE_RIGHT) { return [1,  0]; }
        return null;
    }

    function onTap(evt) {
        var xy = evt.getCoordinates();
        if (xy == null) { return true; }
        if (_recentlyTapped()) { return true; }   // already handled via onDrag
        if (_inSwipeGuard())   { return true; }   // trailing echo of a flick
        _commit(xy[0], xy[1]);
        return true;
    }

    // In the menu, let swipes through so the player can still swipe-back out of
    // the app. On the board, a swipe is a flick-move of the selected piece.
    function onSwipe(evt) {
        _markGesture();
        if (!_view.inPlay()) { return false; }
        if (_inSwipeGuard()) { return true; }      // a drag already handled it
        var v = _swipeVec(evt.getDirection());
        if (v != null) { _view.flickMove(v[0], v[1]); WatchUi.requestUpdate(); }
        return true;
    }

    function onDrag(evt) {
        var t = evt.getType();
        var coords = evt.getCoordinates();

        if (t == WatchUi.DRAG_TYPE_START) {
            // Only hijack drags while the board is live; elsewhere (menu, etc.)
            // let the framework handle the gesture (taps, edge-swipe back).
            if (!_view.inPlay()) { return false; }
            _markGesture();
            _dragging     = true;
            _committed    = false;
            _actedOnStart = false;
            if (coords != null) {
                _downX = coords[0]; _downY = coords[1];
                // GRAB: act on the square the finger FIRST landed on — selecting
                // a piece or moving to a highlighted square, exactly under the
                // touch. A following flick then moves that grabbed piece.
                _commit(_downX, _downY);
                _actedOnStart = true;
            } else {
                _downX = -1; _downY = -1;
            }
            return true;
        }

        if (t == WatchUi.DRAG_TYPE_CONTINUE) {
            if (!_dragging || _committed || coords == null || _downX < 0) { return true; }
            _markGesture();
            var ddx = coords[0] - _downX;
            var ddy = coords[1] - _downY;
            var adx = (ddx < 0) ? -ddx : ddx;
            var ady = (ddy < 0) ? -ddy : ddy;
            var minPx = _swipeMin();
            if (adx >= minPx || ady >= minPx) {
                _committed    = true;
                _swipeGuardMs = System.getTimer();
                _view.flickMove(ddx, ddy);   // move the grabbed piece that way
                WatchUi.requestUpdate();
            }
            return true;
        }

        if (t == WatchUi.DRAG_TYPE_STOP) {
            if (!_dragging) { return false; }
            _dragging = false;
            _markGesture();
            if (_committed) { return true; }     // flick already handled
            // Tap that never produced a valid START (null down coords): commit
            // at the lift point as a fallback so no touch is lost.
            if (!_actedOnStart && coords != null) { _commit(coords[0], coords[1]); }
            return true;
        }
        return false;
    }
}
