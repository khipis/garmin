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
// Touch (GS_PLAY) — drag-to-cursor model (v2, mirrors Battleship v4):
//   touch-down → cursor snaps to the cell under the finger (instant feedback)
//   drag       → cursor follows finger live across cells, with:
//                  • 8 px deadzone before tracking engages (prevents wobbly taps)
//                  • 5 px per-cell hysteresis (slightly damps fast flicks so
//                    the cursor lands close to where the fingertip lifted)
//   lift-off   → if total displacement ≥ 20 px: swap cursor gem in the
//                dominant-axis direction of the whole gesture
//              → if displacement < 20 px: treat as a tap (tapCell)
//
// Touch (GS_MENU / GS_OVER):
//   Tap → activate / confirm.
//   Swipe up/down → navigate rows (firmwares that skip onDrag for menus).
//
// onSwipe fallback:
//   Some firmwares deliver onSwipe but not onDrag (or fire both).
//   In GS_PLAY we suppress onSwipe because onDrag already resolved the
//   gesture (swap was fired at DRAG_TYPE_STOP).  In GS_MENU we keep it
//   for row navigation.  _justSwiped gates onTap after a drag-swap.
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
    hidden var _dragMoved;
    hidden var _justSwiped;     // true after a drag-swap; suppresses the trailing onTap
    hidden var _lastCellR;
    hidden var _lastCellC;
    hidden var _lastCommitX;    // finger px at the last cell-commit point (hysteresis)
    hidden var _lastCommitY;

    // Phantom-back guard.
    hidden var _lastGestureMs;

    // Deadzone before live tracking engages (px).
    hidden const _DRAG_DEAD_PX  = 8;
    // Minimum total displacement to treat lift-off as a swap gesture (px).
    hidden const _SWIPE_MIN_PX  = 20;
    // Per-cell resistance: finger must travel this many px past the last
    // commit point before the cursor steps to the next cell.
    hidden const _CELL_RESIST_PX = 5;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _v             = view;
        _dragStartX    = -1;
        _dragStartY    = -1;
        _dragMoved     = false;
        _justSwiped    = false;
        _lastCellR     = -1;
        _lastCellC     = -1;
        _lastCommitX   = -1;
        _lastCommitY   = -1;
        _lastGestureMs = 0;
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

    // ── Touch ────────────────────────────────────────────────────────

    // onSwipe: used only for MENU row navigation.  In GS_PLAY the drag
    // pipeline handles everything; _justSwiped suppresses the spurious
    // onSwipe that some firmwares send after an onDrag sequence.
    function onSwipe(evt) {
        _markGesture();
        if (_justSwiped) { _justSwiped = false; return true; }
        // Fallback: firmwares that never send onDrag for in-game gestures
        // will reach here.  Route as a direct swap so the game still responds.
        var d = evt.getDirection();
        if      (d == WatchUi.SWIPE_UP)    { _v.handleSwap(-1,  0); }
        else if (d == WatchUi.SWIPE_DOWN)  { _v.handleSwap( 1,  0); }
        else if (d == WatchUi.SWIPE_LEFT)  { _v.handleSwap( 0, -1); }
        else if (d == WatchUi.SWIPE_RIGHT) { _v.handleSwap( 0,  1); }
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
            _dragStartX  = px;
            _dragStartY  = py;
            _dragMoved   = false;
            _justSwiped  = false;
            _lastCellR   = -1;
            _lastCellC   = -1;
            _lastCommitX = -1;
            _lastCommitY = -1;
            // Snap cursor to the touched cell immediately for live feedback.
            var rc0 = _v.cellAt(px, py);
            if (rc0 != null) {
                _v.setCursor(rc0[0], rc0[1]);
                _lastCellR   = rc0[0];
                _lastCellC   = rc0[1];
                _lastCommitX = px;
                _lastCommitY = py;
                WatchUi.requestUpdate();
            }
            return true;
        }

        if (t == WatchUi.DRAG_TYPE_CONTINUE) {
            if (_dragStartX < 0) { return true; }
            var tdx  = px - _dragStartX;
            var tdy  = py - _dragStartY;
            var atdx = (tdx < 0) ? -tdx : tdx;
            var atdy = (tdy < 0) ? -tdy : tdy;

            // Engage live tracking once the finger clears the deadzone.
            if (atdx >= _DRAG_DEAD_PX || atdy >= _DRAG_DEAD_PX) {
                _dragMoved = true;
            }
            if (_dragMoved) {
                var rc = _v.cellAt(px, py);
                if (rc != null && (rc[0] != _lastCellR || rc[1] != _lastCellC)) {
                    // Per-cell hysteresis: require extra travel from the
                    // last committed position before the cursor steps.
                    var allow = true;
                    if (_lastCommitX >= 0) {
                        var ddx  = px - _lastCommitX;
                        var ddy  = py - _lastCommitY;
                        var addx = (ddx < 0) ? -ddx : ddx;
                        var addy = (ddy < 0) ? -ddy : ddy;
                        if (addx < _CELL_RESIST_PX && addy < _CELL_RESIST_PX) {
                            allow = false;
                        }
                    }
                    if (allow) {
                        _v.setCursor(rc[0], rc[1]);
                        _lastCellR   = rc[0];
                        _lastCellC   = rc[1];
                        _lastCommitX = px;
                        _lastCommitY = py;
                        WatchUi.requestUpdate();
                    }
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

            if (!_dragMoved) {
                // No real movement → let onTap handle this as a regular tap.
                return true;
            }

            // Resolve the gesture: if displacement exceeds the swap threshold,
            // fire a swap in the dominant direction from wherever the cursor
            // currently sits.  Otherwise fall through without swapping (the
            // cursor already moved live, which is enough feedback).
            var adx = (dx < 0) ? -dx : dx;
            var ady = (dy < 0) ? -dy : dy;
            if (adx >= _SWIPE_MIN_PX || ady >= _SWIPE_MIN_PX) {
                _justSwiped = true;
                if (adx >= ady) {
                    _v.handleSwap(0, (dx > 0) ? 1 : -1);
                } else {
                    _v.handleSwap((dy > 0) ? 1 : -1, 0);
                }
                WatchUi.requestUpdate();
            }
            return true;
        }

        return true;
    }

    function onTap(evt) {
        _markGesture();
        // Swallow the ghost tap that fires right after a drag-swap is resolved.
        if (_justSwiped) { _justSwiped = false; return true; }
        var xy = evt.getCoordinates();
        if (xy == null) { return true; }
        _v.handleTap(xy[0], xy[1]);
        WatchUi.requestUpdate();
        return true;
    }
}
