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
// Touch — swipe (primary):
//   Any direction → direct gem swap from cursor toward that direction.
//   At board edge, cursor wraps instead (no swap).
//
// Touch — tap (secondary):
//   On a menu row → activate that row (same as navSelect).
//   On the board  → move cursor to the tapped cell (no implicit pick).
//                   If a gem was already selected via SELECT and the
//                   tapped cell is adjacent, the swap is executed
//                   immediately.
//
// onDrag fallback (some firmware skips onSwipe):
//   Small displacement → treated as tap.
//   Large displacement along dominant axis → treated as swipe.
//   _swipeHandled / _dragHandledInput / _lastTapMs guard against
//   double-processing the same physical gesture.
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.System;

class InputHandler extends WatchUi.BehaviorDelegate {
    hidden var _v;

    hidden var _dragStartX;
    hidden var _dragStartY;
    hidden var _dragActive;
    hidden var _dragHandledInput;
    hidden var _swipeHandled;
    hidden var _lastTapMs;
    // Phantom-back guard — see onBack.
    hidden var _lastGestureMs;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _v                = view;
        _dragStartX       = 0;
        _dragStartY       = 0;
        _dragActive       = false;
        _dragHandledInput = false;
        _swipeHandled     = false;
        _lastTapMs        = 0;
        _lastGestureMs    = 0;
    }

    hidden function _markGesture() { _lastGestureMs = System.getTimer(); }
    hidden function _isPhantomBack() {
        if (_lastGestureMs == 0) { return false; }
        var dt = System.getTimer() - _lastGestureMs;
        return (dt >= 0 && dt < 500);
    }

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

    function onTap(evt) {
        _markGesture();
        if (_swipeHandled)     { _swipeHandled     = false; return true; }
        if (_dragHandledInput) { _dragHandledInput = false; return true; }
        var now = System.getTimer();
        if (_lastTapMs != 0 && (now - _lastTapMs) < 250) { return true; }

        var xy = evt.getCoordinates();
        _v.handleTap(xy[0], xy[1]);
        WatchUi.requestUpdate();
        return true;
    }

    function onSwipe(evt) {
        _markGesture();
        _swipeHandled = true;
        var d = evt.getDirection();
        if      (d == WatchUi.SWIPE_UP)    { _v.handleSwap(-1,  0); }
        else if (d == WatchUi.SWIPE_DOWN)  { _v.handleSwap( 1,  0); }
        else if (d == WatchUi.SWIPE_LEFT)  { _v.handleSwap( 0, -1); }
        else if (d == WatchUi.SWIPE_RIGHT) { _v.handleSwap( 0,  1); }
        WatchUi.requestUpdate();
        return true;
    }

    function onDrag(evt) {
        var xy = evt.getCoordinates();
        var t  = evt.getType();

        if (t == WatchUi.DRAG_TYPE_START) {
            _dragStartX       = xy[0];
            _dragStartY       = xy[1];
            _dragActive       = true;
            _dragHandledInput = false;
            _swipeHandled     = false;
            return true;
        }

        if (t == WatchUi.DRAG_TYPE_STOP && _dragActive) {
            _dragActive = false;
            _markGesture();
            if (_swipeHandled) { _swipeHandled = false; return true; }

            var dx  = xy[0] - _dragStartX;
            var dy  = xy[1] - _dragStartY;
            var adx = (dx < 0) ? -dx : dx;
            var ady = (dy < 0) ? -dy : dy;

            if (adx < 18 && ady < 18) {
                // Short displacement → tap
                _dragHandledInput = true;
                _lastTapMs = System.getTimer();
                _v.handleTap(xy[0], xy[1]);
                WatchUi.requestUpdate();
            } else if (adx >= 25 || ady >= 25) {
                // Long displacement → swipe on dominant axis
                _dragHandledInput = true;
                if (adx >= ady * 2) {
                    if (dx > 0) { _v.handleSwap(0,  1); }
                    else        { _v.handleSwap(0, -1); }
                } else if (ady >= adx * 2) {
                    if (dy > 0) { _v.handleSwap( 1, 0); }
                    else        { _v.handleSwap(-1, 0); }
                }
                WatchUi.requestUpdate();
            }
        }
        return true;
    }
}
