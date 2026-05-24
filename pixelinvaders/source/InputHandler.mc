// ═══════════════════════════════════════════════════════════════
// InputHandler.mc — Button + touch mappings for PixelInvaders.
//
// New control scheme (after user complaint about taps unreliably
// triggering FIRE or accidentally moving the cannon):
//
//   MENU:
//     UP / onPreviousPage  → previous row
//     DOWN / onNextPage    → next row
//     SELECT / onEnter     → activate row
//     tap on a row         → activate that row
//
//   PLAY:
//     UP key               → FIRE
//     DOWN key             → FIRE  (left-bottom backup button)
//     SELECT / onEnter     → FIRE
//     tap (anywhere)       → FIRE
//     swipe LEFT / RIGHT   → move cannon (with wrap-around)
//     swipe UP / DOWN      → no-op in PLAY
//     ESC                  → menu
//
//   OVER:
//     any key / tap        → menu
//
// IMPORTANT — why we ignore native `onSwipe`:
//
// Garmin's gesture engine fires `onSwipe` aggressively, often after
// just ~25 px of finger drift.  That meant a quick tap with even a
// tiny drift was interpreted as a left/right swipe and moved the
// cannon instead of firing.  We now ignore `onSwipe` entirely and
// resolve every touch ourselves in `onDrag`:
//
//   displacement < 40 px → TAP   → FIRE
//   horizontal dominant  → SWIPE → move cannon
//   vertical dominant    → no-op (keeps user safe from accidents)
//
// The big 40 px tap window means even sloppy tapping is reliably
// resolved to FIRE.
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.System;

class InputHandler extends WatchUi.BehaviorDelegate {
    hidden var _v;

    hidden var _dx0;
    hidden var _dy0;
    hidden var _dragActive;
    hidden var _handled;
    hidden var _lastTouchMs;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _v           = view;
        _dx0         = 0;
        _dy0         = 0;
        _dragActive  = false;
        _handled     = false;
        _lastTouchMs = 0;
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

    // Page events only navigate in MENU.  In PLAY they would
    // otherwise be triggered by vertical swipes and cause noise.
    function onPreviousPage() {
        if (_v.ctrl.state == PI_PLAY) { return true; }
        _v.navUp(); WatchUi.requestUpdate(); return true;
    }
    function onNextPage() {
        if (_v.ctrl.state == PI_PLAY) { return true; }
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

    // Firmware swipe event — fully ignored.  We resolve swipes
    // ourselves in onDrag using a much higher threshold.
    function onSwipe(evt) { return true; }

    // Pure tap (no drag-start fired) — happens on some firmwares.
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
            _dragActive = false;
            _handled    = true;
            _lastTouchMs = System.getTimer();

            var dx  = xy[0] - _dx0;
            var dy  = xy[1] - _dy0;
            var adx = (dx < 0) ? -dx : dx;
            var ady = (dy < 0) ? -dy : dy;

            // Big tap window → reliable FIRE even with sloppy taps.
            if (adx < 40 && ady < 40) {
                _v.handleTap(xy[0], xy[1]);
            } else if (adx >= ady) {
                // Horizontal swipe → move cannon (with wrap-around).
                if (dx > 0) { _v.handleSwipe(0,  1); }
                else        { _v.handleSwipe(0, -1); }
            }
            // Vertical-dominant swipe in PLAY → no-op (avoid stray fires).
            WatchUi.requestUpdate();
        }
        return true;
    }
}
