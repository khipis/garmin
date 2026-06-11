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
using Toybox.System;

// Minimum finger travel (in pixels) for our manual swipe detector
// to register a swipe. Anything smaller is treated as a tap.
const SWIPE_THRESHOLD = 20;

class InputHandler extends WatchUi.BehaviorDelegate {
    var view;

    // Manual swipe tracking — set on DRAG_TYPE_START, evaluated on
    // DRAG_TYPE_STOP. -1 = no drag in progress.
    hidden var _dragStartX;
    hidden var _dragStartY;
    // Phantom-back guard — Garmin touch panels deliver an onBack
    // alongside an onSwipe/onDrag for a single right-edge gesture;
    // without this guard a right-swipe to merge tiles also pops the
    // view back to menu (or out of the app entirely).
    hidden var _lastGestureMs;

    function initialize(v) {
        BehaviorDelegate.initialize();
        view = v;
        _dragStartX = -1;
        _dragStartY = -1;
        _lastGestureMs = 0;
    }

    hidden function _markGesture() { _lastGestureMs = System.getTimer(); }
    hidden function _isPhantomBack() {
        if (_lastGestureMs == 0) { return false; }
        var dt = System.getTimer() - _lastGestureMs;
        return (dt >= 0 && dt < 500);
    }

    hidden function _refresh() { WatchUi.requestUpdate(); }
    hidden function _ctrl()    { return view.ctrl; }

    // Activate the focused menu row. The LEADERBOARD row opens the shared
    // leaderboard view; everything else is a normal controller action.
    hidden function _activateMenu() {
        var c = _ctrl();
        if (c.menuCursor == MI_LEADERBOARD) {
            view.openLeaderboard();
        } else {
            c.menuActivate();
            _refresh();
        }
    }

    // ── Button events ───────────────────────────────────────────────
    function onKey(evt) {
        return _handleKeyCode(evt.getKey());
    }

    hidden function _handleKeyCode(k) {
        var c = _ctrl();

        if (c.state == GS_MENU) {
            if (k == WatchUi.KEY_UP)    { c.menuPrev();   _refresh(); return true; }
            if (k == WatchUi.KEY_DOWN)  { c.menuNext();   _refresh(); return true; }
            if (k == WatchUi.KEY_ENTER) { _activateMenu();            return true; }
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
    function onBack() {
        if (_isPhantomBack()) { _lastGestureMs = 0; return true; }
        return _handleKeyCode(WatchUi.KEY_ESC);
    }
    // onNextPage / onPreviousPage are produced by SWIPE gestures (and
    // dedicated page buttons) — physical UP/DOWN keys are consumed by
    // onKey and never reach here. During play the swipe is already
    // handled by onDrag (raw pixel deltas, always correct), so acting on
    // these page events too would fire a SECOND, oppositely-mapped
    // vertical move — that double-trigger is what made "swipe down" move
    // the tiles up. We therefore only use them for menu navigation.
    function onNextPage() {
        var c = _ctrl();
        if (c.state == GS_MENU) { c.menuNext(); _refresh(); return true; }
        return true;
    }
    function onPreviousPage() {
        var c = _ctrl();
        if (c.state == GS_MENU) { c.menuPrev(); _refresh(); return true; }
        return true;
    }

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

    // ── Touch ───────────────────────────────────────────────────────
    //
    // We deliberately do NOT override onSwipe. The system-level SWIPE_UP /
    // SWIPE_DOWN constants are reported inverted (relative to finger travel)
    // on some Garmin firmware versions, making vertical swipes move tiles in
    // the wrong direction. onDrag tracks raw pixel deltas so dy > 0 always
    // means the finger moved DOWN, guaranteeing correct behaviour on every
    // device regardless of firmware quirks.
    //
    // Menu navigation (swipe up/down outside GS_PLAY) is also driven from
    // the same raw-coordinate path for the same reason.

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
            _markGesture();
            var adx = dx < 0 ? -dx : dx;
            var ady = dy < 0 ? -dy : dy;
            if (adx < SWIPE_THRESHOLD && ady < SWIPE_THRESHOLD) {
                return false;
            }
            var c = _ctrl();
            if (c.state == GS_PLAY) {
                // Use raw deltas — never touches SWIPE_* constants.
                if (adx >= ady) {
                    c.tryMove(dx > 0 ? DIR_RIGHT : DIR_LEFT);
                } else {
                    c.tryMove(dy > 0 ? DIR_DOWN : DIR_UP);
                }
                _refresh();
                return true;
            } else if (c.state == GS_MENU) {
                if (ady >= adx) {
                    if (dy < 0) { c.menuPrev(); } else { c.menuNext(); }
                    _refresh();
                }
                return true;
            } else if (c.state == GS_WIN) {
                c.continueAfterWin(); _refresh(); return true;
            } else if (c.state == GS_OVER) {
                c.gotoMenu(); _refresh(); return true;
            }
        }
        return false;
    }

    // Tap is only used outside GS_PLAY — returning false during
    // play lets the drag detector own all in-game touch input.
    function onTap(evt) {
        _markGesture();
        var c = _ctrl();
        if (c.state == GS_MENU) { _activateMenu();                  return true; }
        if (c.state == GS_WIN)  { c.continueAfterWin(); _refresh(); return true; }
        if (c.state == GS_OVER) { c.gotoMenu();         _refresh(); return true; }
        return false;
    }
}
