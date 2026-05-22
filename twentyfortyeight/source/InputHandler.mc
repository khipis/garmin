// ═══════════════════════════════════════════════════════════════
// InputHandler.mc — Routes button & touch input to the controller.
//
// Touch (primary control on watches that have a screen)
//   • onSwipe — system-detected swipe (fast, decisive flicks).
//   • onDrag  — RAW touch positions; we run our own swipe detector
//               on DRAG_TYPE_STOP so any finger motion ≥ a small
//               threshold counts as a swipe. This is the workaround
//               for Fenix devices where the system-level onSwipe
//               threshold is too strict for the small screen.
//   • onTap   — used only to dismiss menus / overlays. Returns false
//               in GS_PLAY so it never competes with the swipe
//               detector.
//
// Buttons (5-button Garmin layout)
//   KEY_UP         → tiles UP                  (menu: prev row)
//   KEY_DOWN       → tiles DOWN                (menu: next row)
//   KEY_ENTER      → tiles RIGHT               (menu: activate)
//   KEY_ESC        → return to menu / exit
//   onHold SELECT  → tiles LEFT                (long press fallback)
//   onMenu         → tiles LEFT                (long-press UP, fires
//                                               on Fenix / Forerunner)
//   KEY_MENU       → tiles LEFT                (dedicated MENU key)
//
// So with buttons alone the player has 4 full directions: U / D via
// the obvious keys, RIGHT via SELECT, LEFT via either onHold SELECT
// **or** the menu hot-key (long-press UP).
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;

// Minimum finger travel (in pixels) for our manual swipe detector
// to register a swipe. Anything smaller is treated as a tap.
const SWIPE_THRESHOLD = 20;

class InputHandler extends WatchUi.BehaviorDelegate {
    var view;

    // Manual swipe tracking — set on DRAG_TYPE_START, evaluated on
    // DRAG_TYPE_STOP. -1 = no drag in progress.
    hidden var _dragStartX;
    hidden var _dragStartY;

    function initialize(v) {
        BehaviorDelegate.initialize();
        view = v;
        _dragStartX = -1;
        _dragStartY = -1;
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
        } else if (c.state == GS_PLAY) {
            if (k == WatchUi.KEY_UP)    { c.tryMove(DIR_UP);    _refresh(); return true; }
            if (k == WatchUi.KEY_DOWN)  { c.tryMove(DIR_DOWN);  _refresh(); return true; }
            if (k == WatchUi.KEY_ENTER) { c.tryMove(DIR_RIGHT); _refresh(); return true; }
            if (k == WatchUi.KEY_MENU)  { c.tryMove(DIR_LEFT);  _refresh(); return true; }
            if (k == WatchUi.KEY_ESC)   { c.gotoMenu();         _refresh(); return true; }
        } else if (c.state == GS_WIN) {
            if (k == WatchUi.KEY_ENTER) { c.continueAfterWin(); _refresh(); return true; }
            if (k == WatchUi.KEY_ESC)   { c.gotoMenu();         _refresh(); return true; }
            if (k == WatchUi.KEY_UP || k == WatchUi.KEY_DOWN) {
                c.continueAfterWin();
                _refresh();
                return true;
            }
        } else { // GS_OVER
            c.gotoMenu();
            _refresh();
            return true;
        }
        return false;
    }

    // Long-press SELECT — tiles LEFT in play, no-op elsewhere.
    function onHold(evt) {
        var c = _ctrl();
        if (c.state == GS_PLAY) {
            c.tryMove(DIR_LEFT);
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

    // onMenu fires on long-press UP (Fenix, Forerunner) or the
    // dedicated MENU button (Edge). Map it to LEFT so the player
    // always has a discrete button for LEFT without needing onHold.
    function onMenu() {
        var c = _ctrl();
        if (c.state == GS_PLAY) {
            c.tryMove(DIR_LEFT);
            _refresh();
            return true;
        }
        return false;
    }

    // ── Touch — system-detected swipe ───────────────────────────────
    function onSwipe(evt) {
        var d = evt.getDirection();
        return _applySwipe(d);
    }

    // ── Touch — manual swipe detector via raw drag positions ────────
    // Some Garmin watches (notably the Fenix 8 Solar 51 mm) only fire
    // onSwipe for very long, fast flicks. We track drag start/stop
    // ourselves and synthesize a direction on STOP so any decisive
    // finger motion of ≥ SWIPE_THRESHOLD pixels in either axis turns
    // into a tile move.
    function onDrag(evt) {
        var t = evt.getType();
        var coords = evt.getCoordinates();
        if (coords == null) { return false; }
        var px = coords[0];
        var py = coords[1];

        if (t == WatchUi.DRAG_TYPE_START) {
            _dragStartX = px;
            _dragStartY = py;
            return true;
        }
        if (t == WatchUi.DRAG_TYPE_STOP) {
            if (_dragStartX < 0) { return false; }
            var dx = px - _dragStartX;
            var dy = py - _dragStartY;
            _dragStartX = -1; _dragStartY = -1;
            var adx = dx < 0 ? -dx : dx;
            var ady = dy < 0 ? -dy : dy;
            if (adx < SWIPE_THRESHOLD && ady < SWIPE_THRESHOLD) {
                return false;
            }
            // Pick the dominant axis.
            var dir;
            if (adx >= ady) {
                dir = (dx > 0) ? WatchUi.SWIPE_RIGHT : WatchUi.SWIPE_LEFT;
            } else {
                dir = (dy > 0) ? WatchUi.SWIPE_DOWN  : WatchUi.SWIPE_UP;
            }
            return _applySwipe(dir);
        }
        return false;
    }

    // Common dispatch shared by onSwipe + onDrag synthesised swipes.
    hidden function _applySwipe(d) {
        var c = _ctrl();
        if (c.state == GS_PLAY) {
            if (d == WatchUi.SWIPE_UP)    { c.tryMove(DIR_UP);    _refresh(); return true; }
            if (d == WatchUi.SWIPE_DOWN)  { c.tryMove(DIR_DOWN);  _refresh(); return true; }
            if (d == WatchUi.SWIPE_LEFT)  { c.tryMove(DIR_LEFT);  _refresh(); return true; }
            if (d == WatchUi.SWIPE_RIGHT) { c.tryMove(DIR_RIGHT); _refresh(); return true; }
        } else if (c.state == GS_MENU) {
            if (d == WatchUi.SWIPE_UP)    { c.menuPrev(); _refresh(); return true; }
            if (d == WatchUi.SWIPE_DOWN)  { c.menuNext(); _refresh(); return true; }
        } else if (c.state == GS_WIN) {
            c.continueAfterWin(); _refresh(); return true;
        } else if (c.state == GS_OVER) {
            c.gotoMenu(); _refresh(); return true;
        }
        return false;
    }

    // Tap is only used outside of GS_PLAY — returning false during
    // play lets the drag detector own all in-game touch input.
    function onTap(evt) {
        var c = _ctrl();
        if (c.state == GS_MENU) { c.menuActivate();     _refresh(); return true; }
        if (c.state == GS_WIN)  { c.continueAfterWin(); _refresh(); return true; }
        if (c.state == GS_OVER) { c.gotoMenu();         _refresh(); return true; }
        return false;
    }
}
