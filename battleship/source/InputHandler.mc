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
//   GS_SETUP — buttons walk the cursor, swipes set orientation
//     DOWN (bottom button)   cursor.r += 1 with wrap inside the valid
//                            range for the current orientation
//     UP   (middle-left)     cursor.c += 1 with wrap inside the valid
//                            range for the current orientation
//     SWIPE LEFT or RIGHT    orient ship HORIZONTALLY (cursor clamped
//                            so the ship still fits on the board)
//     SWIPE UP or DOWN       orient ship VERTICALLY (cursor clamped)
//     SELECT                 place the ship at the cursor
//     TAP   (touch)          jump cursor to the tapped cell, snap so
//                            the ship fits + place permanently
//     BACK                   auto-place remaining ships
//
//   GS_AIM — buttons + swipes move the crosshair, SELECT/TAP fires
//     DOWN              cursor.r = (r + 1) % 8
//     UP                cursor.c = (c + 1) % 8
//     SWIPE ↑↓←→        move crosshair one cell in that direction
//                       (clamped to the board edges).  Resolved
//                       inside onDrag with a 30 px threshold so a
//                       finger flick never fires a shot.
//     SELECT            fire at cursor
//     TAP               fire at tapped cell (single, stationary tap)
//     BACK              return to menu
//
//   GS_INFO / GS_WIN / GS_LOSE
//     any input → continue
//
// Rationale: with just two directional buttons we'd otherwise need
// the buttons to handle both axis movement AND orientation, which
// either locks the user out of some valid cells or makes the cursor
// "jump" between modes. Splitting "movement" onto buttons and
// "orientation" onto swipes gives full coverage with no surprises:
// every legal placement is reachable with two presses + an optional
// swipe. Touch users can simply tap.
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;

class InputHandler extends WatchUi.BehaviorDelegate {
    var view;

    // Manual swipe detector — some Fenix models don't reliably fire
    // onSwipe for short flicks, and even when they do the subsequent
    // onTap can still fire and trigger a shot.  We resolve every
    // touch ourselves in onDrag and use `_justSwiped` to swallow the
    // follow-up onTap so a finger flick during AIM never accidentally
    // fires at whichever cell the gesture started on.
    hidden var _dragStartX;
    hidden var _dragStartY;
    hidden var _justSwiped;
    hidden const _SWIPE_THRESHOLD = 30;

    function initialize(v) {
        BehaviorDelegate.initialize();
        view = v;
        _dragStartX = -1;
        _dragStartY = -1;
        _justSwiped = false;
    }

    hidden function _refresh() { WatchUi.requestUpdate(); }
    hidden function _ctrl()    { return view.ctrl; }

    // ── Button events ───────────────────────────────────────────────
    function onKey(evt) {
        return _handleKeyCode(evt.getKey());
    }

    hidden function _handleKeyCode(k) {
        var c = _ctrl();

        if (c.state == GS_MENU) {
            if (k == WatchUi.KEY_UP)    { c.menuPrev();     _refresh(); return true; }
            if (k == WatchUi.KEY_DOWN)  { c.menuNext();     _refresh(); return true; }
            if (k == WatchUi.KEY_ENTER) { c.menuActivate(); _refresh(); return true; }
            if (k == WatchUi.KEY_ESC)   { return false; }   // let system exit
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
            // GS_WIN / GS_LOSE
            c.gotoMenu(); _refresh(); return true;
        }
        return false;
    }

    // Long-press SELECT — handy fallback shortcuts:
    //   SETUP → toggle orientation (alias for swipe)
    //   AIM   → cycle cursor one column right
    function onHold(evt) {
        var c = _ctrl();
        if (c.state == GS_SETUP) {
            c.setupRotate();
            _refresh();
            return true;
        }
        if (c.state == GS_AIM) {
            c.aimStepRight();
            _refresh();
            return true;
        }
        return false;
    }

    // ── BehaviorDelegate convenience overrides ──────────────────────
    function onSelect()       { return _handleKeyCode(WatchUi.KEY_ENTER); }
    function onBack()         { return _handleKeyCode(WatchUi.KEY_ESC);   }
    function onNextPage()     { return _handleKeyCode(WatchUi.KEY_DOWN);  }
    function onPreviousPage() { return _handleKeyCode(WatchUi.KEY_UP);    }

    // ── Touch / swipe ───────────────────────────────────────────────
    // During AIM/SETUP we ignore the native onSwipe entirely and
    // resolve everything inside onDrag so we can also swallow the
    // post-swipe onTap.  In MENU the legacy native handler is fine.
    function onSwipe(evt) {
        var c = _ctrl();
        if (c.state == GS_AIM || c.state == GS_SETUP) { return true; }
        return _applySwipe(evt.getDirection());
    }

    function onDrag(evt) {
        var t = evt.getType();
        var coords = evt.getCoordinates();
        if (coords == null) { return false; }
        var px = coords[0];
        var py = coords[1];
        if (t == WatchUi.DRAG_TYPE_START) {
            _dragStartX = px; _dragStartY = py;
            _justSwiped = false;
            return true;
        }
        if (t == WatchUi.DRAG_TYPE_STOP) {
            if (_dragStartX < 0) { return false; }
            var dx = px - _dragStartX;
            var dy = py - _dragStartY;
            _dragStartX = -1; _dragStartY = -1;
            var adx = dx < 0 ? -dx : dx;
            var ady = dy < 0 ? -dy : dy;
            if (adx < _SWIPE_THRESHOLD && ady < _SWIPE_THRESHOLD) {
                // Treat as a stationary press → let onTap handle it.
                return false;
            }
            var dir;
            if (adx >= ady) {
                dir = (dx > 0) ? WatchUi.SWIPE_RIGHT : WatchUi.SWIPE_LEFT;
            } else {
                dir = (dy > 0) ? WatchUi.SWIPE_DOWN  : WatchUi.SWIPE_UP;
            }
            _justSwiped = true;
            return _applySwipe(dir);
        }
        return false;
    }

    hidden function _applySwipe(d) {
        var c = _ctrl();
        if (c.state == GS_SETUP) {
            // Horizontal swipe → lay ship flat. Vertical swipe → stand
            // the ship up. Cursor is auto-clamped so the ship fits.
            if (d == WatchUi.SWIPE_LEFT || d == WatchUi.SWIPE_RIGHT) {
                c.setupOrientHoriz(); _refresh(); return true;
            }
            if (d == WatchUi.SWIPE_UP || d == WatchUi.SWIPE_DOWN) {
                c.setupOrientVert();  _refresh(); return true;
            }
        } else if (c.state == GS_AIM) {
            if (d == WatchUi.SWIPE_UP)    { c.aimMoveCursor(-1, 0); _refresh(); return true; }
            if (d == WatchUi.SWIPE_DOWN)  { c.aimMoveCursor( 1, 0); _refresh(); return true; }
            if (d == WatchUi.SWIPE_LEFT)  { c.aimMoveCursor( 0,-1); _refresh(); return true; }
            if (d == WatchUi.SWIPE_RIGHT) { c.aimMoveCursor( 0, 1); _refresh(); return true; }
        } else if (c.state == GS_MENU) {
            if (d == WatchUi.SWIPE_UP)    { c.menuPrev(); _refresh(); return true; }
            if (d == WatchUi.SWIPE_DOWN)  { c.menuNext(); _refresh(); return true; }
        }
        return false;
    }

    function onTap(evt) {
        // Swallow the tap that always fires after onDrag resolved a
        // swipe — otherwise a finger flick on the aim grid would also
        // fire a shot at whichever cell the gesture started on.
        if (_justSwiped) { _justSwiped = false; return true; }
        var c = _ctrl();
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
