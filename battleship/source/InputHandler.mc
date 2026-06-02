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
//        cell sat under the finger.  Felt eager but a quick flick
//        crossed several cells, so any normal swipe could "land"
//        far from where the user expected.
//   v3 — discrete one-cell directional swipes resolved at lift-off.
//        Predictable but lost the live tracking feel, and a single
//        swipe = one cell felt undersized when the user wanted to
//        cross the grid.
//   v4 — THIS FILE.  Back to v2's live cell-under-finger tracking
//        — that responsiveness is what the user actually wants —
//        but ~12% less sensitive overall:
//          • Drag-engagement deadzone bumped 6 → 8 px (33 % more
//            finger travel required before the cursor starts to
//            move, so a tap that drifts slightly never accidentally
//            steers).
//          • Per-cell hysteresis: once the cursor has committed to
//            a cell, the finger must travel at least 5 px farther
//            from that commit point before the cursor steps again.
//            On a ~22 px cell that's roughly 22 % extra travel per
//            cell-step, so a fast flick that previously zipped
//            across 5 cells now lands at ~4.  Net "sensitivity"
//            sits in the user's requested 10-15 % softer band.
//
//   Phantom-back guard:
//     touch panels deliver an `onBack` alongside an `onSwipe/onDrag`
//     for right-edge gestures.  Any onBack within 500 ms of a
//     recent touch is treated as phantom and silently consumed.
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.System;

class InputHandler extends WatchUi.BehaviorDelegate {
    var view;

    // Touch tracking.
    hidden var _dragStartX;
    hidden var _dragStartY;
    hidden var _dragMoved;
    hidden var _justSwiped;
    hidden var _lastCellR;
    hidden var _lastCellC;
    hidden var _lastCommitX;       // finger px at the moment the cursor
    hidden var _lastCommitY;       // last committed to a new cell

    // Decisive-swipe threshold (used in SETUP at DRAG_TYPE_STOP to
    // toggle ship orientation).
    hidden const _SWIPE_THRESHOLD = 18;

    // Finger must travel at least this many pixels from touch-down
    // before live cell-tracking engages.  Slightly larger than v2's
    // 6 px so a sloppy tap doesn't get reclassified as a drag.
    hidden const _DRAG_DEAD_PX = 8;

    // Once the cursor has committed to a cell, the finger must travel
    // at least this many pixels from that commit point before the
    // cursor is allowed to step again.  Roughly 22 % of a typical
    // ~22 px grid cell on a 260 px round face → about 10-15 % softer
    // overall feel without breaking long deliberate drags.
    hidden const _CELL_RESIST_PX = 5;

    // Phantom-back guard.
    hidden var _lastGestureMs;
    hidden const _PHANTOM_BACK_MS = 500;

    function initialize(v) {
        BehaviorDelegate.initialize();
        view           = v;
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
            _dragStartX  = px;
            _dragStartY  = py;
            _dragMoved   = false;
            _justSwiped  = false;
            _lastCellR   = -1;
            _lastCellC   = -1;
            _lastCommitX = -1;
            _lastCommitY = -1;
            return true;
        }

        if (t == WatchUi.DRAG_TYPE_CONTINUE) {
            if (_dragStartX < 0) { return false; }
            var tdx = px - _dragStartX;
            var tdy = py - _dragStartY;
            var atdx = (tdx < 0) ? -tdx : tdx;
            var atdy = (tdy < 0) ? -tdy : tdy;

            // Engagement deadzone — until the finger has clearly left
            // its touch-down spot we don't drag-steer at all.  Stops a
            // wobbly tap from accidentally moving the cursor.
            if (atdx >= _DRAG_DEAD_PX || atdy >= _DRAG_DEAD_PX) {
                _dragMoved = true;
            }
            if (_dragMoved && (c.state == GS_AIM || c.state == GS_SETUP)) {
                var rc = view.cellAt(px, py);
                if (rc != null
                    && (rc[0] != _lastCellR || rc[1] != _lastCellC)) {
                    // Per-cell hysteresis: once the cursor has parked
                    // on a cell, the finger has to move a fixed
                    // pixel budget further before the next cell
                    // commits.  Means a slow drag still walks
                    // through every cell in sequence, but a fast
                    // smear that flies across the grid lands a tad
                    // shy of where the fingertip ended up.
                    var allow = true;
                    if (_lastCommitX >= 0) {
                        var ddx = px - _lastCommitX;
                        var ddy = py - _lastCommitY;
                        var addx = (ddx < 0) ? -ddx : ddx;
                        var addy = (ddy < 0) ? -ddy : ddy;
                        if (addx < _CELL_RESIST_PX
                            && addy < _CELL_RESIST_PX) {
                            allow = false;
                        }
                    }
                    if (allow) {
                        if (c.state == GS_AIM) {
                            c.aimSetCursor(rc[0], rc[1]);
                        } else {
                            c.setupSetCursor(rc[0], rc[1]);
                        }
                        _lastCellR   = rc[0];
                        _lastCellC   = rc[1];
                        _lastCommitX = px;
                        _lastCommitY = py;
                        _refresh();
                    }
                }
            }
            return true;
        }

        if (t == WatchUi.DRAG_TYPE_STOP) {
            if (_dragStartX < 0) { return false; }
            var dx = px - _dragStartX;
            var dy = py - _dragStartY;
            _dragStartX = -1;
            _dragStartY = -1;
            _markGesture();

            // No real movement → onTap will pick it up as a tap.
            if (!_dragMoved) { return false; }

            // We DID drag — swallow the lift-off tap so the player
            // can't accidentally fire/place on release.
            _justSwiped = true;

            // SETUP also accepts the lift-off direction as an
            // orientation toggle (touchscreen-only users have no
            // other way to flip the ship without using HOLD-select).
            // AIM does not — drag-to-aim already moved the cursor.
            if (c.state == GS_SETUP) {
                var adx = (dx < 0) ? -dx : dx;
                var ady = (dy < 0) ? -dy : dy;
                if (adx >= _SWIPE_THRESHOLD || ady >= _SWIPE_THRESHOLD) {
                    if (adx * 10 >= ady * 14) {
                        c.setupOrientHoriz(); _refresh(); return true;
                    }
                    if (ady * 10 >= adx * 14) {
                        c.setupOrientVert();  _refresh(); return true;
                    }
                }
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
