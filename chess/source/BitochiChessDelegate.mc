using Toybox.WatchUi;
using Toybox.System;

// ═══════════════════════════════════════════════════════════════════════════
//  Input routing for chess.
//
//  Touch design — "drag-to-aim, lift to commit" (same model as battleship)
//  ────────────────────────────────────────────────────────────────────────
//  Selecting one of 64 tiny squares with a pixel-perfect tap is hard, and
//  Garmin touch panels routinely report a press as a small drag rather than a
//  clean onTap.  So instead of demanding an exact tap we track the finger:
//
//    • While the finger moves, the cursor highlight follows the square under
//      it (live visual feedback — you SEE where you'll land).
//    • On lift-off the square under the finger is committed (select piece /
//      move there) — regardless of how far the finger travelled.
//    • A clean onTap (devices that send one) is handled too, with a short
//      dedupe window so a press never activates a square twice.
// ═══════════════════════════════════════════════════════════════════════════
class BitochiChessDelegate extends WatchUi.BehaviorDelegate {
    hidden var _view;

    hidden var _dragging;
    hidden var _lastTapMs;

    // Suppress a duplicate tap arriving this soon after one was handled.
    hidden const _TAP_DEDUPE_MS = 180;

    // After a drag/swipe the touch panel routinely emits a spurious onBack a
    // few hundred ms later. Swallow it so a rightward "move the piece" drag can
    // never bounce the player out of the game.
    hidden var _lastGestureMs;
    hidden const _PHANTOM_BACK_MS = 500;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view          = view;
        _dragging      = false;
        _lastTapMs     = 0;
        _lastGestureMs = 0;
    }

    hidden function _markGesture() { _lastGestureMs = System.getTimer(); }
    hidden function _isPhantomBack() {
        if (_lastGestureMs == 0) { return false; }
        var dt = System.getTimer() - _lastGestureMs;
        return (dt >= 0 && dt < _PHANTOM_BACK_MS);
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

    function onTap(evt) {
        var xy = evt.getCoordinates();
        if (xy == null) { return true; }
        if (_recentlyTapped()) { return true; }   // already handled via onDrag
        _commit(xy[0], xy[1]);
        return true;
    }

    // While the board is live, swallow every swipe so a left↔right (or any)
    // flick across the board moves the cursor instead of triggering the
    // system back/exit gesture. In the menu we let swipes through so the
    // player can still swipe-back out of the app.
    function onSwipe(evt) {
        _markGesture();
        if (_view.inPlay()) { return true; }
        return false;
    }

    function onDrag(evt) {
        var t = evt.getType();
        var coords = evt.getCoordinates();
        if (coords == null) { return false; }

        if (t == WatchUi.DRAG_TYPE_START) {
            // Only hijack drags while the board is live; elsewhere (menu, etc.)
            // let the framework handle the gesture (taps, edge-swipe back).
            if (!_view.inPlay()) { return false; }
            _markGesture();
            _dragging = true;
            _view.hoverAt(coords[0], coords[1]);
            WatchUi.requestUpdate();
            return true;
        }

        if (t == WatchUi.DRAG_TYPE_CONTINUE) {
            if (!_dragging) { return false; }
            _markGesture();
            _view.hoverAt(coords[0], coords[1]);
            WatchUi.requestUpdate();
            return true;
        }

        if (t == WatchUi.DRAG_TYPE_STOP) {
            if (!_dragging) { return false; }
            _dragging = false;
            _markGesture();
            // Lift-off commits the square under the finger, however far it moved.
            // When a piece is already selected this lands the move on the
            // destination square (handled in the view's doTap/handleSquare).
            _commit(coords[0], coords[1]);
            return true;
        }
        return false;
    }
}
