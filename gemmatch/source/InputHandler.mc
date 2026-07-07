// ═══════════════════════════════════════════════════════════════
// InputHandler.mc — BehaviorDelegate mapping watch input to
// MainView high-level intents.
//
// Buttons:
//   KEY_UP / onPreviousPage → navUp
//       menu:  select previous row
//       play:  step cursor LEFT (col-wrap)
//   KEY_DOWN / onNextPage   → navDown
//       menu:  select next row
//       play:  step cursor DOWN (row-wrap)
//   KEY_ENTER / onSelect    → navSelect
//       menu:  activate focused row (cycle value / start game)
//       play:  pick gem at cursor; second SELECT on adjacent = swap
//   KEY_ESC / onBack        → navBack
//       ZEN play: end session → show score → back key again → menu
//       other play: clear selection → menu
//       menu/over: pop view
//
// Touch (GS_PLAY) — grab-and-flick (v7):
//
//   TAP on a gem        → that gem is SELECTED exactly where the finger lands.
//   FLICK / SWIPE       → the currently SELECTED gem moves one cell in the
//                         swipe direction: left→left, right→right, up→up,
//                         down→down. If nothing is selected yet, the gem under
//                         the start of the swipe is used.
//   LIFT without moving → resolves as a TAP and selects the touched gem.
//
// The whole gesture is driven by the drag stream (START/CONT/STOP). onTap and
// onSwipe are treated as REDUNDANT fallbacks:
//   • onTap → selectCell — idempotent, so if it fires alongside a drag it just
//     re-selects the same gem (harmless). This is why taps are NEVER gated.
//   • onSwipe → move the selected gem — this MUST be de-duped against a drag
//     swipe, so a short "_swipeGuardMs" window (set ONLY when a drag swipe
//     commits) swallows the trailing onSwipe/onTap echo of that same flick.
//
// DRAG_TYPE_START deliberately does NOT change selection: a swipe that begins
// on some other cell must still move the gem the player previously selected,
// instead of "randomly" replacing selection with the cell under the finger.
// Because the guard is armed only by swipes — never by taps — a burst of quick
// taps can never swallow one another.
//
// A gesture becomes a SWIPE once the finger travels past _swipeMin() px, a
// threshold scaled to the board cell size so a deliberate tap never trips it.
//
// Touch (GS_MENU / GS_OVER):
//   Tap → activate / confirm.
//
// Phantom-back guard:
//   Right-edge swipes on touch panels fire onBack alongside onDrag.
//   Any onBack within 500 ms of a recent touch is silently consumed.
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.System;

class InputHandler extends WatchUi.BehaviorDelegate {
    hidden var _v;

    // Drag tracking state.
    hidden var _dragStartX;
    hidden var _dragStartY;
    hidden var _startR;         // board cell the gesture started (was grabbed) on
    hidden var _startC;
    hidden var _committed;      // this drag already fired its swipe

    // Timestamp (ms) of the last DRAG-DRIVEN SWIPE. A firmware often tacks a
    // stray onSwipe/onTap onto the end of the drag stream — anything landing
    // within this short window is that echo and is ignored. Crucially this is
    // armed ONLY by swipes, so quick successive TAPS never gate each other.
    hidden var _swipeGuardMs;

    // Phantom-back guard.
    hidden var _lastGestureMs;

    // Fallback swipe threshold (px) when the board cell size isn't known yet.
    hidden const _SWIPE_MIN_FALLBACK = 18;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _v             = view;
        _dragStartX    = -1;
        _dragStartY    = -1;
        _startR        = -1;
        _startC        = -1;
        _committed     = false;
        _swipeGuardMs  = 0;
        _lastGestureMs = 0;
    }

    // A flick counts as a SWIPE once travel passes ~55% of a cell (min 18px),
    // so a deliberate tap — even a slightly sloppy one — never trips a swap.
    hidden function _swipeMin() {
        var cp = _v.cellSize();
        if (cp == null || cp <= 0) { return _SWIPE_MIN_FALLBACK; }
        var t = cp * 55 / 100;
        return (t < _SWIPE_MIN_FALLBACK) ? _SWIPE_MIN_FALLBACK : t;
    }

    // True if a drag-swipe just fired and this onSwipe/onTap is its echo.
    hidden function _inSwipeGuard() {
        if (_swipeGuardMs == 0) { return false; }
        var dt = System.getTimer() - _swipeGuardMs;
        return (dt >= 0 && dt < 320);
    }

    hidden function _markGesture() { _lastGestureMs = System.getTimer(); }
    hidden function _isPhantomBack() {
        if (_lastGestureMs == 0) { return false; }
        var dt = System.getTimer() - _lastGestureMs;
        return (dt >= 0 && dt < 500);
    }

    // ── Button events ────────────────────────────────────────────────

    function onKey(evt) {
        var k = evt.getKey();
        if      (k == WatchUi.KEY_UP)   { _v.navUp();     }
        else if (k == WatchUi.KEY_DOWN) { _v.navDown();   }
        else if (k == WatchUi.KEY_ESC)  { return onBack(); }
        else                             { _v.navSelect(); }
        WatchUi.requestUpdate();
        return true;
    }

    function onSelect()       { _v.navSelect(); WatchUi.requestUpdate(); return true; }
    function onPreviousPage() { _v.navUp();     WatchUi.requestUpdate(); return true; }
    function onNextPage()     { _v.navDown();   WatchUi.requestUpdate(); return true; }

    function onBack() {
        if (_isPhantomBack()) { _lastGestureMs = 0; return true; }
        var consumed = _v.navBack();
        WatchUi.requestUpdate();
        if (consumed) { return true; }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    // ── Touch (grab-and-flick) ────────────────────────────────────────

    // Map a swipe/flick vector to a unit board direction (dominant axis).
    hidden function _dirFromVec(dx, dy) {
        var adx = (dx < 0) ? -dx : dx;
        var ady = (dy < 0) ? -dy : dy;
        if (adx >= ady) { return [0, (dx > 0) ? 1 : -1]; }
        return [(dy > 0) ? 1 : -1, 0];
    }

    function onSwipe(evt) {
        _markGesture();
        // A drag swipe already handled this flick — ignore its echo. (Taps
        // never arm the guard, so this can't swallow a genuine tap.)
        if (_inSwipeGuard()) { return true; }
        var d  = evt.getDirection();
        var dr = 0;
        var dc = 0;
        if      (d == WatchUi.SWIPE_UP)    { dr = -1; }
        else if (d == WatchUi.SWIPE_DOWN)  { dr =  1; }
        else if (d == WatchUi.SWIPE_LEFT)  { dc = -1; }
        else if (d == WatchUi.SWIPE_RIGHT) { dc =  1; }
        else { return true; }
        // Move the grabbed gem (falls back to the selection / cursor when this
        // firmware emits onSwipe without a preceding onDrag START).
        _v.swipeMoveFrom(dr, dc, _startR, _startC);
        WatchUi.requestUpdate();
        return true;
    }

    function onDrag(evt) {
        var t  = evt.getType();
        var xy = evt.getCoordinates();
        if (xy == null) { return true; }
        var px = xy[0];
        var py = xy[1];

        if (t == WatchUi.DRAG_TYPE_START) {
            _dragStartX = px;
            _dragStartY = py;
            _committed  = false;
            // Record the cell under the finger, but do not select it yet. We
            // only know this was a TAP when STOP arrives without crossing the
            // swipe threshold. This keeps swipes bound to the already selected
            // gem instead of unexpectedly jumping to the finger-start cell.
            var rc0 = _v.cellAt(px, py);
            if (rc0 != null) {
                _startR = rc0[0]; _startC = rc0[1];
            } else {
                _startR = -1; _startC = -1;
            }
            return true;
        }

        if (t == WatchUi.DRAG_TYPE_CONTINUE) {
            if (_dragStartX < 0 || _committed) { return true; }
            var cdx = px - _dragStartX;
            var cdy = py - _dragStartY;
            _maybeSwipe(cdx, cdy);
            return true;
        }

        if (t == WatchUi.DRAG_TYPE_STOP) {
            if (_dragStartX < 0) { return true; }
            var dx = px - _dragStartX;
            var dy = py - _dragStartY;
            _dragStartX = -1;
            _dragStartY = -1;
            _markGesture();
            // Resolve as a swipe if it crossed the threshold. If not, this is
            // a plain tap from firmware that reports taps as START/STOP instead
            // of onTap, so select the exact start cell.
            if (!_committed) {
                _maybeSwipe(dx, dy);
                if (!_committed && _startR >= 0) {
                    _v.selectCell(_startR, _startC);
                    WatchUi.requestUpdate();
                }
            }
            _startR = -1; _startC = -1;
            return true;
        }

        return true;
    }

    // Fire the grabbed gem's move if the finger has travelled far enough for a
    // swipe. Arms the swipe-guard so the trailing onSwipe/onTap echo is dropped.
    hidden function _maybeSwipe(dx, dy) {
        var adx = (dx < 0) ? -dx : dx;
        var ady = (dy < 0) ? -dy : dy;
        var minPx = _swipeMin();
        if (adx < minPx && ady < minPx) { return; }
        var pd = _dirFromVec(dx, dy);
        _committed    = true;
        _swipeGuardMs = System.getTimer();
        _v.swipeMoveFrom(pd[0], pd[1], _startR, _startC);
        WatchUi.requestUpdate();
    }

    function onTap(evt) {
        _markGesture();
        // Only a swipe echo is gated here; genuine taps are always honoured so
        // rapid taps on different gems each land where the finger touched.
        if (_inSwipeGuard()) { return true; }
        var xy = evt.getCoordinates();
        if (xy == null) { return true; }
        _v.handleTap(xy[0], xy[1]);       // selects the tapped gem in play
        WatchUi.requestUpdate();
        return true;
    }
}
