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
// Touch (GS_PLAY) — grab-and-slide model (v4). The gem you TOUCH is the
// gem that moves — always, on every firmware. On touch-down the gem is
// grabbed (instant highlight); sliding the finger toward a neighbour
// slides the gem there.
//
//   touch-down on a gem   → grab it: cursor + highlight snap onto it now.
//   slide into a neighbour→ swap the grabbed gem into that neighbour the
//                           instant the finger crosses the cell border
//                           (also fires on lift-off past a small threshold).
//   quick flick           → onSwipe swaps the grabbed gem in the flick
//                           direction (covers firmwares that only report
//                           the gesture as a swipe, never as a drag).
//   tap (no slide)        → pick the gem; tapping an adjacent gem then
//                           swaps the two (button-free two-tap fallback).
//
// Robustness: the grabbed cell is captured at touch-down (_startR/_startC)
// and reused by every resolution path — cross-cell during drag, lift-off
// threshold, and onSwipe — so the touched gem is never confused with the
// cursor gem. _committed stops a single gesture swapping twice; _justSwiped
// suppresses the trailing onTap/onSwipe a firmware may tack on after a drag.
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
    hidden var _startR;         // board cell the gesture started on (grabbed gem)
    hidden var _startC;
    hidden var _downMs;         // timer at touch-down (guards stale grab reuse)
    hidden var _dragMoved;
    hidden var _committed;      // this gesture already fired a swap
    hidden var _justSwiped;     // true after a drag-swap; suppresses the trailing onTap/onSwipe

    // Phantom-back guard.
    hidden var _lastGestureMs;

    // Deadzone before a gesture counts as movement (px). Small = snappy.
    hidden const _DRAG_DEAD_PX  = 6;
    // Minimum finger travel to treat lift-off as a swipe (px). Kept small so
    // a "light" flick on a gem is enough even if the finger never fully
    // crosses into the neighbour cell.
    hidden const _SWIPE_MIN_PX  = 12;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _v             = view;
        _dragStartX    = -1;
        _dragStartY    = -1;
        _startR        = -1;
        _startC        = -1;
        _downMs        = 0;
        _dragMoved     = false;
        _committed     = false;
        _justSwiped    = false;
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

    // onSwipe: quick-flick path. Fires on firmwares that report a fast
    // gesture as a swipe rather than a full drag. Always acts on the gem the
    // finger started on (captured at touch-down), so the touched gem moves —
    // not the cursor gem. _justSwiped consumes the spurious onSwipe some
    // firmwares tack on right after an onDrag already resolved the gesture.
    function onSwipe(evt) {
        _markGesture();
        if (_justSwiped) { _justSwiped = false; return true; }
        var d  = evt.getDirection();
        var dr = 0;
        var dc = 0;
        if      (d == WatchUi.SWIPE_UP)    { dr = -1; }
        else if (d == WatchUi.SWIPE_DOWN)  { dr =  1; }
        else if (d == WatchUi.SWIPE_LEFT)  { dc = -1; }
        else if (d == WatchUi.SWIPE_RIGHT) { dc =  1; }
        else { return true; }

        // Use the grabbed gem only if the touch-down that set it belongs to
        // this same gesture (recent). Otherwise it'd be a stale cell from an
        // earlier gesture, so fall back to the picked/cursor gem.
        var fresh = (_startR >= 0) &&
                    ((System.getTimer() - _downMs) >= 0) &&
                    ((System.getTimer() - _downMs) < 700);
        if (fresh) {
            _v.swapFrom(_startR, _startC, dr, dc);   // grabbed gem
        } else {
            _v.handleSwipeSwap(dr, dc);              // no fresh touch-down
        }
        _startR = -1; _startC = -1;
        _v.cancelDrag();
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
            _dragMoved  = false;
            _committed  = false;
            _justSwiped = false;
            // Grab the gem under the finger immediately: cursor + highlight
            // snap onto it now, before any movement.
            _downMs = System.getTimer();
            var rc0 = _v.cellAt(px, py);
            if (rc0 != null) {
                _startR = rc0[0];
                _startC = rc0[1];
                _v.startDrag(rc0[0], rc0[1]);
                WatchUi.requestUpdate();
            } else {
                _startR = -1;
                _startC = -1;
            }
            return true;
        }

        if (t == WatchUi.DRAG_TYPE_CONTINUE) {
            if (_dragStartX < 0 || _committed || _startR < 0) { return true; }
            var cdx  = px - _dragStartX;
            var cdy  = py - _dragStartY;
            var acdx = (cdx < 0) ? -cdx : cdx;
            var acdy = (cdy < 0) ? -cdy : cdy;
            if (acdx >= _DRAG_DEAD_PX || acdy >= _DRAG_DEAD_PX) { _dragMoved = true; }
            if (!_dragMoved) { return true; }

            // Preview: highlight the neighbour the current slide points at.
            var pdr = 0;
            var pdc = 0;
            if (acdx >= acdy) { pdc = (cdx > 0) ? 1 : -1; }
            else              { pdr = (cdy > 0) ? 1 : -1; }
            _v.updateDragDir(pdr, pdc);

            // Commit the swap the moment the finger crosses fully into an
            // adjacent cell — one step toward the cell now under the finger.
            var rc = _v.cellAt(px, py);
            if (rc != null && (rc[0] != _startR || rc[1] != _startC)) {
                var ddr  = rc[0] - _startR;
                var ddc  = rc[1] - _startC;
                var addr = (ddr < 0) ? -ddr : ddr;
                var addc = (ddc < 0) ? -ddc : ddc;
                var sdr  = 0;
                var sdc  = 0;
                if (addc >= addr) { sdc = (ddc > 0) ? 1 : -1; }
                else              { sdr = (ddr > 0) ? 1 : -1; }
                _committed  = true;
                _justSwiped = true;
                _v.swapFrom(_startR, _startC, sdr, sdc);
            }
            WatchUi.requestUpdate();
            return true;
        }

        if (t == WatchUi.DRAG_TYPE_STOP) {
            if (_dragStartX < 0) { return true; }
            var dx = px - _dragStartX;
            var dy = py - _dragStartY;
            _dragStartX = -1;
            _dragStartY = -1;
            _markGesture();
            if (_committed) { return true; }   // already swapped mid-slide

            var adx = (dx < 0) ? -dx : dx;
            var ady = (dy < 0) ? -dy : dy;

            // Lift-off past the swipe threshold → swap the grabbed gem in the
            // dominant-axis direction, even if the finger never fully crossed
            // into the neighbour cell (covers short, light flicks).
            if ((adx >= _SWIPE_MIN_PX || ady >= _SWIPE_MIN_PX) && _startR >= 0) {
                _committed  = true;
                _justSwiped = true;
                if (adx >= ady) {
                    _v.swapFrom(_startR, _startC, 0, (dx > 0) ? 1 : -1);
                } else {
                    _v.swapFrom(_startR, _startC, (dy > 0) ? 1 : -1, 0);
                }
                WatchUi.requestUpdate();
                return true;
            }

            // Barely moved → a tap-pick on the grabbed gem. (Some firmwares
            // won't also emit onTap after a drag, so resolve it here;
            // _justSwiped guards a duplicate onTap.)
            _v.cancelDrag();
            if (_startR >= 0) {
                _justSwiped = true;
                _v.pickCell(_startR, _startC);
                WatchUi.requestUpdate();
            }
            return true;
        }

        return true;
    }

    function onTap(evt) {
        _markGesture();
        // Swallow the ghost tap that fires right after a drag resolved things.
        if (_justSwiped) { _justSwiped = false; return true; }
        var xy = evt.getCoordinates();
        if (xy == null) { return true; }
        _v.handleTap(xy[0], xy[1]);
        WatchUi.requestUpdate();
        return true;
    }
}
