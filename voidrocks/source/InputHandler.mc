// ═══════════════════════════════════════════════════════════════
// InputHandler.mc — Button + touch mappings for VoidRocks.
//
// Control scheme (user request):
//
//   MENU:
//     UP / onPreviousPage  → previous row
//     DOWN / onNextPage    → next row
//     SELECT / onEnter     → activate row
//     tap on a row         → activate that row
//
//   PLAY:
//     wrist tilt           → ship rotation (in MainView.onTick)
//     DOWN key (l-bottom)  → THRUST (engine)
//     UP key (middle-left) → rotate LEFT (backup for tilt)
//     SELECT / onEnter     → FIRE (backup)
//     tap (anywhere)       → FIRE
//     ESC                  → menu
//
//   OVER:
//     any key / tap        → menu
//
// IMPORTANT — page events & touch:
//
// On modern Garmin firmware, the physical DOWN button often fires
// `onNextPage` instead of `onKey(KEY_DOWN)`.  The vertical swipe
// gesture ALSO fires `onNextPage`.  We need to allow the button
// through (for THRUST) but block the swipe-induced one (so a tap
// with finger drift doesn't sneak through).
//
// We track touch state: if `onNextPage` fires while a drag is in
// progress, or within 350 ms of `onDrag(STOP)`, it's swipe-induced
// and we swallow it.  Otherwise it's a real button press.
//
// Touch handling: ignore native `onSwipe`; resolve every touch in
// `onDrag(STOP)` with a 40 px tap window so a sloppy tap still
// reliably becomes FIRE.
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.System;

const VR_PAGE_GUARD_MS = 350;   // ms after drag-stop in which onPage
                                 // events are assumed swipe-induced.

class InputHandler extends WatchUi.BehaviorDelegate {
    hidden var _v;

    hidden var _dx0;
    hidden var _dy0;
    hidden var _dragActive;
    hidden var _handled;
    hidden var _lastTouchMs;
    hidden var _lastDragEndMs;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _v             = view;
        _dx0           = 0;
        _dy0           = 0;
        _dragActive    = false;
        _handled       = false;
        _lastTouchMs   = 0;
        _lastDragEndMs = 0;
    }

    hidden function _pageFromTouch() {
        if (_dragActive) { return true; }
        if (_lastDragEndMs == 0) { return false; }
        var dt = System.getTimer() - _lastDragEndMs;
        return (dt >= 0 && dt < VR_PAGE_GUARD_MS);
    }

    function onKey(evt) {
        var k = evt.getKey();
        if      (k == WatchUi.KEY_ESC)  { return onBack(); }
        else if (k == WatchUi.KEY_UP)   { _v.navUp();    }
        else if (k == WatchUi.KEY_DOWN) { _v.navDown();  }
        else                            { _v.navSelect(); }
        WatchUi.requestUpdate();
        return true;
    }

    function onSelect() { _v.navSelect(); WatchUi.requestUpdate(); return true; }

    // Page events: in PLAY allow physical button presses through
    // but swallow swipe-induced ones (detected by the touch-state
    // guard).
    function onPreviousPage() {
        if (_v.ctrl.state == VR_PLAY && _pageFromTouch()) { return true; }
        _v.navUp(); WatchUi.requestUpdate(); return true;
    }
    function onNextPage() {
        if (_v.ctrl.state == VR_PLAY && _pageFromTouch()) { return true; }
        _v.navDown(); WatchUi.requestUpdate(); return true;
    }

    function onBack() {
        var consumed = _v.navBack();
        WatchUi.requestUpdate();
        if (consumed) { return true; }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    // ── Touch ────────────────────────────────────────────────────

    // Firmware swipe — fully ignored; we resolve in onDrag.
    function onSwipe(evt) { return true; }

    function onTap(evt) {
        if (_handled) { _handled = false; return true; }
        var now = System.getTimer();
        if (_lastTouchMs != 0 && (now - _lastTouchMs) < 120) { return true; }
        _lastTouchMs = now;
        var xy = evt.getCoordinates();
        _v.handleTap(xy[0], xy[1]);
        WatchUi.requestUpdate();
        return true;
    }

    function onDrag(evt) {
        var xy = evt.getCoordinates();
        var t  = evt.getType();

        if (t == WatchUi.DRAG_TYPE_START) {
            _dx0        = xy[0];
            _dy0        = xy[1];
            _dragActive = true;
            _handled    = false;
            return true;
        }

        if (t == WatchUi.DRAG_TYPE_STOP && _dragActive) {
            _dragActive    = false;
            _handled       = true;
            _lastTouchMs   = System.getTimer();
            _lastDragEndMs = _lastTouchMs;

            var dx  = xy[0] - _dx0;
            var dy  = xy[1] - _dy0;
            var adx = (dx < 0) ? -dx : dx;
            var ady = (dy < 0) ? -dy : dy;

            // Liberal tap window — anything under 40 px = FIRE.
            if (adx < 40 && ady < 40) {
                _v.handleTap(xy[0], xy[1]);
                WatchUi.requestUpdate();
            }
            // Larger displacements: VoidRocks has no swipe controls.
        }
        return true;
    }
}
