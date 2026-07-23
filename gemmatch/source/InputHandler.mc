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
// Touch (GS_PLAY) — grab-and-flick (v8):
//
//   TAP on a gem        → that gem is SELECTED exactly where the finger lands.
//   FLICK / SWIPE       → the gem under the finger moves one cell in the swipe
//                         direction: left→left, right→right, up→up, down→down.
//   LIFT without moving → resolves as a TAP and selects the touched gem.
//
// The whole gesture is driven by the drag stream (START/CONT/STOP). onTap and
// onSwipe are treated as REDUNDANT fallbacks:
//   • onTap → selectCell — idempotent, so if it fires alongside a drag it just
//     re-selects the same gem (harmless). Taps are NEVER gated.
//   • onSwipe → move the selected gem — this MUST be de-duped against a drag
//     swipe, so a short "_swipeGuardMs" window (set ONLY when a drag swipe
//     commits) swallows the trailing onSwipe/onTap echo of that same flick.
//
// DRAG_TYPE_START selects immediately. Garmin touch firmware often reports a
// tap as a very short drag, so waiting until STOP made taps feel ignored. The
// cell under the finger always owns the cursor.
//
// A gesture becomes a SWIPE once the finger travels past _swipeMin() px, a
// threshold scaled to the board cell size so a deliberate tap never trips it.
//
// Precision (v8) — on small round watches a cell can be ~25-30px, well
// within normal fingertip placement error, which used to make the wrong
// neighbour gem get grabbed. Two mitigations:
//   • MainView.cellAt() is border-sticky toward the gem the player was last
//     focused on (_ctrl.curR/curC): a touch landing just inside a
//     neighbouring cell, close to the shared border, still resolves to the
//     anchor cell. A decisive touch well inside the new cell always wins.
//   • While a drag stays BELOW the swipe threshold, onDrag CONTINUE keeps
//     re-selecting whatever cell is currently under the finger (instead of
//     freezing the selection to the touch-down cell) and re-anchors the
//     origin there — so nudging the finger to correct an imprecise
//     touch-down before flicking now works, instead of silently moving the
//     wrong gem.
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

    // A flick counts as a SWIPE once travel passes ~45% of a cell (min 18px),
    // so a deliberate tap — even a slightly sloppy one — never trips a swap.
    hidden function _swipeMin() {
        var cp = _v.cellSize();
        if (cp == null || cp <= 0) { return _SWIPE_MIN_FALLBACK; }
        var t = cp * 45 / 100;
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
            // Select immediately: where the finger touches, the cursor goes.
            // This covers firmwares that emit taps as short drag START/STOP
            // pairs and gives instant visual confirmation.
            var rc0 = _v.cellAt(px, py);
            if (rc0 != null) {
                _startR = rc0[0]; _startC = rc0[1];
                _v.selectCell(_startR, _startC);
                WatchUi.requestUpdate();
            } else {
                _startR = -1; _startC = -1;
            }
            return true;
        }

        if (t == WatchUi.DRAG_TYPE_CONTINUE) {
            if (_dragStartX < 0 || _committed) { return true; }
            var cdx = px - _dragStartX;
            var cdy = py - _dragStartY;
            if (!_maybeSwipe(cdx, cdy)) {
                // Still below the swipe threshold — let the highlight track
                // the finger. This lets a touch-down that landed on the
                // wrong gem be silently corrected by nudging toward the
                // intended one before flicking, instead of being frozen to
                // whatever cell START happened to register. Re-anchors the
                // drag origin to the corrected cell so the swipe threshold
                // and direction are measured from where the player is
                // actually holding, not the original touch-down point.
                var rc = _v.cellAt(px, py);
                if (rc != null && (rc[0] != _startR || rc[1] != _startC)) {
                    _startR = rc[0]; _startC = rc[1];
                    _v.selectCell(_startR, _startC);
                    _dragStartX = px;
                    _dragStartY = py;
                    WatchUi.requestUpdate();
                }
            }
            return true;
        }

        if (t == WatchUi.DRAG_TYPE_STOP) {
            if (_dragStartX < 0) { return true; }
            var dx = px - _dragStartX;
            var dy = py - _dragStartY;
            _dragStartX = -1;
            _dragStartY = -1;
            _markGesture();
            // Resolve as a swipe if it crossed the threshold. If not, it was a
            // tap and START already selected the exact touched cell.
            if (!_committed) {
                _maybeSwipe(dx, dy);
            }
            _startR = -1; _startC = -1;
            return true;
        }

        return true;
    }

    // Fire the grabbed gem's move if the finger has travelled far enough for a
    // swipe. Arms the swipe-guard so the trailing onSwipe/onTap echo is
    // dropped. Returns true if it committed a swipe (false = still below
    // threshold, so the caller may keep tracking the finger instead).
    hidden function _maybeSwipe(dx, dy) {
        var adx = (dx < 0) ? -dx : dx;
        var ady = (dy < 0) ? -dy : dy;
        var minPx = _swipeMin();
        if (adx < minPx && ady < minPx) { return false; }
        var pd = _dirFromVec(dx, dy);
        _committed    = true;
        _swipeGuardMs = System.getTimer();
        _v.swipeMoveFrom(pd[0], pd[1], _startR, _startC);
        WatchUi.requestUpdate();
        return true;
    }

    function onTap(evt) {
        _markGesture();
        var xy = evt.getCoordinates();
        if (xy == null) { return true; }
        _v.handleTap(xy[0], xy[1]);       // selects the tapped gem in play
        WatchUi.requestUpdate();
        return true;
    }
}
