// ═══════════════════════════════════════════════════════════════
// InputHandler.mc — Routes all device input to the controller.
//
// PLAY button scheme:
//   KEY_UP   (middle-left)  → move cursor UP one row (vertical, wraps)
//   KEY_DOWN (bottom-left)  → move cursor to NEXT letter (A→Z→A, horizontal)
//   SELECT / ENTER          → guess current letter
//   onHold (long-press)     → guess current letter
//   BACK / ESC              → return to menu
//
// PLAY touch scheme:
//   Tap anywhere on screen  → guess the letter currently under the cursor
//                             (cursor does NOT move on tap — move it first
//                             with buttons or swipes, then confirm with tap)
//   Swipe UP                → move cursor up one row
//   Swipe DOWN              → move cursor down one row
//   Swipe LEFT              → move cursor left one letter (prev in A…Z)
//   Swipe RIGHT             → move cursor right one letter (next in A…Z)
//
// Swipe / tap separation:
//   A _swipeHandled flag is set whenever onSwipe fires. onDrag-STOP and
//   onTap both check this flag and skip the guess if it is set. This
//   guarantees that a recognised swipe can never also fire a guess —
//   no matter what order the firmware delivers the events in.
//
// MENU:
//   KEY_UP / KEY_DOWN / swipe ↑↓ → walk rows (prev / next)
//   SELECT / ENTER / tap          → activate focused row
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.System;

class InputHandler extends WatchUi.BehaviorDelegate {
    var view;

    // Drag state for the small-displacement tap fallback.
    hidden var _dragStartX;
    hidden var _dragStartY;
    hidden var _dragActive;

    // Set to true by onSwipe so neither onDrag-STOP nor onTap will
    // also fire a guess for the same touch gesture.
    hidden var _swipeHandled;

    // Dedup guard — prevents a double-guess when both onTap and the
    // onDrag-STOP fallback fire for the same physical tap (which
    // happens on some Garmin firmware).
    hidden var _tapGuard;     // ms timestamp of last routed tap

    // Phantom-back guard — see onBack.
    hidden var _lastGestureMs;

    function initialize(v) {
        BehaviorDelegate.initialize();
        view           = v;
        _dragStartX    = -1;
        _dragStartY    = -1;
        _dragActive    = false;
        _swipeHandled  = false;
        _tapGuard      = 0;
        _lastGestureMs = 0;
    }

    hidden function _markGesture() { _lastGestureMs = System.getTimer(); }
    hidden function _isPhantomBack() {
        if (_lastGestureMs == 0) { return false; }
        var dt = System.getTimer() - _lastGestureMs;
        return (dt >= 0 && dt < 500);
    }

    hidden function _refresh() { WatchUi.requestUpdate(); }

    // ── Button events ───────────────────────────────────────────────
    function onKey(evt) {
        var k    = evt.getKey();
        var ctrl = view.ctrl;

        if (ctrl.state == GS_PLAY) {
            // KEY_UP   = vertical   cursor (up one row, wrap)
            // KEY_DOWN = horizontal cursor (right one letter A→Z→A)
            if (k == WatchUi.KEY_UP)    { ctrl.moveCursorVert(-1); _refresh(); return true; }
            if (k == WatchUi.KEY_DOWN)  { ctrl.moveCursorHoriz(1); _refresh(); return true; }
            if (k == WatchUi.KEY_ENTER) { ctrl.guessCurrent();     _refresh(); return true; }
            if (k == WatchUi.KEY_ESC)   { return _goBack(); }
        } else {
            // GS_WIN / GS_LOSE — BACK pops to the shared menu; any other key
            // starts a fresh round in place.
            if (k == WatchUi.KEY_ESC) { return _goBack(); }
            ctrl.startGame(); _refresh(); return true;
        }
        return false;
    }

    // Long-press SELECT → guess (always available regardless of mode)
    function onHold(evt) {
        var ctrl = view.ctrl;
        if (ctrl.state == GS_PLAY) {
            ctrl.guessCurrent();
            _refresh();
            return true;
        }
        return false;
    }

    // ── BehaviorDelegate convenience overrides ──────────────────────
    function onSelect()        { return onKey(_synthKey(WatchUi.KEY_ENTER)); }
    function onBack() {
        if (_isPhantomBack()) { _lastGestureMs = 0; return true; }
        return _goBack();
    }
    function onNextPage()      { return onKey(_synthKey(WatchUi.KEY_DOWN));  }
    function onPreviousPage()  { return onKey(_synthKey(WatchUi.KEY_UP));    }

    // Return to the shared menu.
    hidden function _goBack() {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    // ── Swipe ───────────────────────────────────────────────────────
    // All swipes move the cursor and raise _swipeHandled so the
    // subsequent onDrag-STOP (and onTap on some devices) won't also
    // fire a guess for the same touch.
    function onSwipe(evt) {
        _markGesture();
        var ctrl = view.ctrl;
        _swipeHandled = true;

        if (ctrl.state == GS_PLAY) {
            var d = evt.getDirection();
            if (d == WatchUi.SWIPE_UP)    { ctrl.moveCursorVert(-1);  }
            if (d == WatchUi.SWIPE_DOWN)  { ctrl.moveCursorVert(1);   }
            if (d == WatchUi.SWIPE_LEFT)  { ctrl.moveCursorHoriz(-1); }
            if (d == WatchUi.SWIPE_RIGHT) { ctrl.moveCursorHoriz(1);  }
            _refresh();
            return true;
        }
        return false;
    }

    // ── Tap (native onTap) ──────────────────────────────────────────
    // If a swipe was already handled for this touch, discard the tap
    // silently so we don't also fire a guess.
    function onTap(evt) {
        if (evt == null) { return false; }
        _markGesture();
        if (_swipeHandled) { _swipeHandled = false; return true; }
        var xy = evt.getCoordinates();
        return _routeTap(xy[0], xy[1]);
    }

    // ── onDrag — small-displacement tap fallback ────────────────────
    // Many Garmin watches (round MIP models) deliver onDrag events
    // for every touch but never fire onTap. We watch for a
    // START→STOP pair with barely any movement and treat it as a tap.
    // The _swipeHandled guard ensures a real swipe never leaks through.
    function onDrag(evt) {
        if (evt == null) { return false; }
        var xy = evt.getCoordinates();
        var t  = evt.getType();

        if (t == WatchUi.DRAG_TYPE_START) {
            _dragStartX   = xy[0];
            _dragStartY   = xy[1];
            _dragActive   = true;
            _swipeHandled = false;   // fresh touch — reset guard
        } else if (t == WatchUi.DRAG_TYPE_STOP) {
            _markGesture();
            if (_dragActive) {
                _dragActive = false;
                if (!_swipeHandled) {
                    var dx = xy[0] - _dragStartX;
                    var dy = xy[1] - _dragStartY;
                    if (dx < 0) { dx = -dx; }
                    if (dy < 0) { dy = -dy; }
                    if (dx < 18 && dy < 18) {
                        return _routeTap(xy[0], xy[1]);
                    }
                }
            }
            _swipeHandled = false;
        }
        return true;
    }

    // ── Common tap routing ──────────────────────────────────────────
    // In PLAY: guess the letter currently under the cursor.
    //          Does NOT move the cursor to the tapped pixel — the
    //          player positions the cursor first with buttons/swipes,
    //          then confirms with a tap.
    // In MENU: activate the focused row.
    // In WIN/LOSE: go to menu.
    hidden function _routeTap(px, py) {
        var now = System.getTimer();
        if (_tapGuard != 0 && now - _tapGuard < 200) { return true; }
        _tapGuard = now;

        var ctrl = view.ctrl;
        if (ctrl.state == GS_PLAY) {
            ctrl.guessCurrent();
            _refresh();
            return true;
        }
        // GS_WIN / GS_LOSE — tap starts a fresh round in place.
        ctrl.startGame();
        _refresh();
        return true;
    }

    // ── Helpers ─────────────────────────────────────────────────────
    hidden function _synthKey(code) { return new SyntheticKey(code); }
}

// Lightweight stand-in for KeyEvent — exposes getKey().
class SyntheticKey {
    var _k;
    function initialize(k) { _k = k; }
    function getKey()      { return _k; }
}
