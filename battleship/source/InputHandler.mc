// ═══════════════════════════════════════════════════════════════
// InputHandler.mc — Routes every user input to GameController.
//
// Buttons (Garmin 5-button layout)
//
//   GS_MENU
//     UP/DOWN  → menu cursor
//     SELECT   → activate (cycle difficulty / start)
//     BACK     → exit app
//
//   GS_SETUP
//     DOWN (bottom button)   cursor.r += 1
//     UP   (middle-left)     cursor.c += 1
//     SWIPE LEFT / RIGHT     orient ship HORIZONTALLY
//     SWIPE UP / DOWN        orient ship VERTICALLY
//     TAP                    move cursor to tapped cell AND place ship
//     HOLD SELECT            toggle orientation (touch-only fallback)
//     SELECT                 place ship at current cursor
//     BACK                   auto-place remaining ships
//
//   GS_AIM
//     DOWN              cursor.r = (r + 1) % 8
//     UP                cursor.c = (c + 1) % 8
//     SWIPE LEFT/RIGHT  move crosshair ±1 cell horizontally
//     SWIPE UP/DOWN     move crosshair ±1 cell vertically
//     TAP               fire at the tapped cell (jump + fire in one)
//     SELECT            fire at the current crosshair
//     HOLD SELECT       fire at the current crosshair
//     BACK              return to menu
//
//   GS_INFO / GS_WIN / GS_LOSE
//     any input → continue
//
// Touch design notes
// ──────────────────
// History of this file:
//   v1 — discrete swipes via onSwipe only.  Garmin's panel often
//        misclassified slow horizontal swipes as diagonals, so the
//        user perceived swipes as "not responding".
//   v2 — finger-tracking ("drag-to-aim"): cursor glued to whatever
//        cell sat under the finger.  Fixed responsiveness but the
//        cursor jumped wildly during any normal swipe gesture
//        (the finger crosses many cells in a flick); the user
//        called this "way too sensitive, every swipe moves
//        almost randomly".
//   v3 — THIS FILE.  Discrete one-cell directional swipes derived
//        from the dx/dy at DRAG_TYPE_STOP.  Generous thresholds
//        (14 px) and strict 1.5×-dominant axis to kill diagonals.
//        Tap = precise jump + commit.  No finger-tracking.
//
//   Rules:
//     • Below 14 px in BOTH axes → treat as a stationary tap.
//     • Above threshold + dominant axis ≥ 1.5× the other →
//       one-cell step in the dominant direction.
//     • Above threshold but axes within 1.5× of each other →
//       ambiguous diagonal, ignored (so the cursor never lurches
//       sideways when the user meant to swipe vertically).
//     • `_justSwiped` is set whenever a real swipe was resolved
//       so the lift-off onTap is swallowed.
//
// Phantom-back guard:
//   touch panels deliver an `onBack` alongside an `onSwipe/onDrag`
//   for right-edge gestures.  Any onBack within 500 ms of a
//   recent touch is treated as phantom and silently consumed.
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.System;

class InputHandler extends WatchUi.BehaviorDelegate {
    var view;

    // Touch tracking.
    hidden var _dragStartX;
    hidden var _dragStartY;
    hidden var _justSwiped;

    // Generous threshold — short flicks on small round Fenix watches
    // routinely come in under 18 px.  14 px is still well above the
    // typical "jitter while tapping" envelope (~3-5 px).
    hidden const _SWIPE_THRESHOLD = 14;

    // Phantom-back guard.
    hidden var _lastGestureMs;
    hidden const _PHANTOM_BACK_MS = 500;

    function initialize(v) {
        BehaviorDelegate.initialize();
        view           = v;
        _dragStartX    = -1;
        _dragStartY    = -1;
        _justSwiped    = false;
        _lastGestureMs = 0;
    }

    hidden function _markGesture() { _lastGestureMs = System.getTimer(); }
    hidden function _isPhantomBack() {
        if (_lastGestureMs == 0) { return false; }
        var dt = System.getTimer() - _lastGestureMs;
        return (dt >= 0 && dt < _PHANTOM_BACK_MS);
    }

    hidden function _refresh() { WatchUi.requestUpdate(); }
    hidden function _ctrl()    { return view.ctrl; }

    // ── Button events ───────────────────────────────────────────────
    function onKey(evt) {
        return _handleKeyCode(evt.getKey());
    }

    hidden function _handleKeyCode(k) {
        var c = _ctrl();

        // Ignore all input while a fire animation is playing.
        if (c.isFiring()) { return true; }

        if (c.state == GS_MENU) {
            if (k == WatchUi.KEY_UP)    { c.menuPrev();     _refresh(); return true; }
            if (k == WatchUi.KEY_DOWN)  { c.menuNext();     _refresh(); return true; }
            if (k == WatchUi.KEY_ENTER) { c.menuActivate(); _refresh(); return true; }
            if (k == WatchUi.KEY_ESC)   { return false; }
        } else if (c.state == GS_SETUP) {
            if (k == WatchUi.KEY_UP)    { c.setupStepRight(); _refresh(); return true; }
            if (k == WatchUi.KEY_DOWN)  { c.setupStepDown();  _refresh(); return true; }
            if (k == WatchUi.KEY_ENTER) { c.setupConfirm();   _refresh(); return true; }
            if (k == WatchUi.KEY_ESC)   { c.setupAuto();      _refresh(); return true; }
        } else if (c.state == GS_AIM) {
            if (k == WatchUi.KEY_UP)    { c.aimStepRight(); _refresh(); return true; }
            if (k == WatchUi.KEY_DOWN)  { c.aimStepDown();  _refresh(); return true; }
            if (k == WatchUi.KEY_ENTER) { c.playerFire();   _refresh(); return true; }
            if (k == WatchUi.KEY_ESC)   { c.gotoMenu();     _refresh(); return true; }
        } else if (c.state == GS_INFO) {
            c.infoContinue(); _refresh(); return true;
        } else {
            c.gotoMenu(); _refresh(); return true;
        }
        return false;
    }

    // Long-press SELECT fallback — touchscreen-only users can hold
    // to rotate ship in SETUP or fire in AIM if a tap misregisters.
    function onHold(evt) {
        var c = _ctrl();
        if (c.isFiring()) { return true; }
        if (c.state == GS_SETUP) { c.setupRotate(); _refresh(); return true; }
        if (c.state == GS_AIM)   { c.playerFire();  _refresh(); return true; }
        return false;
    }

    // ── BehaviorDelegate convenience overrides ──────────────────────
    function onSelect()       { return _handleKeyCode(WatchUi.KEY_ENTER); }
    function onBack() {
        if (_isPhantomBack()) { _lastGestureMs = 0; return true; }
        return _handleKeyCode(WatchUi.KEY_ESC);
    }
    function onNextPage()     { return _handleKeyCode(WatchUi.KEY_DOWN);  }
    function onPreviousPage() { return _handleKeyCode(WatchUi.KEY_UP);    }

    // ── Touch ───────────────────────────────────────────────────────

    // The native onSwipe is reliable for MENU paging.  Inside the
    // grid states we route through onDrag so we can apply our own
    // axis-dominance gate and avoid the panel's false diagonals.
    function onSwipe(evt) {
        _markGesture();
        var c = _ctrl();
        if (c.isFiring()) { return true; }
        if (c.state == GS_MENU) {
            var d = evt.getDirection();
            if (d == WatchUi.SWIPE_UP)   { c.menuPrev(); _refresh(); return true; }
            if (d == WatchUi.SWIPE_DOWN) { c.menuNext(); _refresh(); return true; }
        }
        // SETUP / AIM handled in onDrag for predictable thresholding.
        return true;
    }

    function onDrag(evt) {
        var t = evt.getType();
        var coords = evt.getCoordinates();
        if (coords == null) { return false; }
        var px = coords[0];
        var py = coords[1];
        var c  = _ctrl();

        if (c.isFiring()) { return true; }

        if (t == WatchUi.DRAG_TYPE_START) {
            _dragStartX = px;
            _dragStartY = py;
            _justSwiped = false;
            return true;
        }

        if (t == WatchUi.DRAG_TYPE_CONTINUE) {
            // We DELIBERATELY do not move the cursor mid-drag.  Old
            // versions did, which made any natural flick feel like
            // the cursor was being yanked across the grid.
            return true;
        }

        if (t == WatchUi.DRAG_TYPE_STOP) {
            if (_dragStartX < 0) { return false; }
            var dx = px - _dragStartX;
            var dy = py - _dragStartY;
            var adx = (dx < 0) ? -dx : dx;
            var ady = (dy < 0) ? -dy : dy;

            _dragStartX = -1;
            _dragStartY = -1;
            _markGesture();

            // Below threshold in BOTH axes → not a swipe, let the
            // subsequent onTap handle it as a stationary press.
            if (adx < _SWIPE_THRESHOLD && ady < _SWIPE_THRESHOLD) {
                return false;
            }

            // We're going to resolve this as a swipe (or reject it
            // as ambiguous).  Either way, suppress the trailing tap.
            _justSwiped = true;

            // Dominant axis must beat the other axis by ≥ 1.5×.
            // Anything within that band is a diagonal; ignore it
            // so a slightly tilted swipe never flips orientation /
            // moves the cursor sideways.
            var hDom = (adx >= ady) && (adx * 10 >= ady * 15);
            var vDom = (ady >  adx) && (ady * 10 >= adx * 15);

            if (c.state == GS_AIM) {
                if      (hDom && dx > 0) { c.aimMoveCursor( 0,  1); _refresh(); }
                else if (hDom && dx < 0) { c.aimMoveCursor( 0, -1); _refresh(); }
                else if (vDom && dy > 0) { c.aimMoveCursor( 1,  0); _refresh(); }
                else if (vDom && dy < 0) { c.aimMoveCursor(-1,  0); _refresh(); }
                return true;
            }
            if (c.state == GS_SETUP) {
                if      (hDom) { c.setupOrientHoriz(); _refresh(); return true; }
                else if (vDom) { c.setupOrientVert();  _refresh(); return true; }
                return true;
            }
            return true;
        }
        return false;
    }

    function onTap(evt) {
        _markGesture();
        // Swallow the tap that fires immediately after a swipe is
        // resolved at DRAG_TYPE_STOP.
        if (_justSwiped) { _justSwiped = false; return true; }
        var c = _ctrl();
        if (c.isFiring()) { return true; }
        var coords = evt.getCoordinates();
        if (coords == null) { return false; }
        var px = coords[0];
        var py = coords[1];

        if (c.state == GS_MENU) {
            c.menuActivate();
            _refresh();
            return true;
        }
        if (c.state == GS_SETUP) {
            var rc = view.cellAt(px, py);
            if (rc != null) {
                c.setupSetCursor(rc[0], rc[1]);
                c.setupConfirm();
                _refresh();
                return true;
            }
        } else if (c.state == GS_AIM) {
            var rc2 = view.cellAt(px, py);
            if (rc2 != null) {
                c.aimSetCursor(rc2[0], rc2[1]);
                c.playerFire();
                _refresh();
                return true;
            }
        } else if (c.state == GS_INFO) {
            c.infoContinue();
            _refresh();
            return true;
        } else {
            c.gotoMenu();
            _refresh();
            return true;
        }
        return false;
    }
}
