// ═══════════════════════════════════════════════════════════════
// InputHandler.mc — Button + touch mappings for StarSwarm.
//
// Control scheme:
//
//   MENU:
//     UP / onPreviousPage   → previous row
//     DOWN / onNextPage     → next row
//     SELECT / onEnter      → activate row
//     Tap on a row          → hit-test (view-side)
//
//   PLAY:
//     UP key                → FIRE
//     DOWN key              → FIRE  (left-bottom backup button)
//     SELECT / onEnter      → FIRE
//     Tap (anywhere)        → FIRE
//     Swipe LEFT / RIGHT    → move ship
//     Swipe UP / DOWN       → no-op
//     ESC                   → menu
//
//   WIN / OVER:
//     any key / tap         → back to menu
//
// IMPORTANT — why we ignore native `onSwipe`:
//
// Garmin's gesture engine fires `onSwipe` very aggressively — even
// a 25 px drift during a quick tap becomes a swipe.  That made
// taps unreliable as FIRE and accidentally moved the ship.  Here
// we ignore `onSwipe` entirely and resolve every touch ourselves
// in `onDrag`:
//
//   displacement < 40 px → TAP   → FIRE
//   horizontal dominant  → SWIPE → move ship
//   vertical dominant    → no-op (no stray fires)
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

    function onPreviousPage() {
        if (_v.ctrl.state == SS_PLAY) { return true; }
        _v.navUp(); WatchUi.requestUpdate(); return true;
    }
    function onNextPage() {
        if (_v.ctrl.state == SS_PLAY) { return true; }
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
            _dragActive  = false;
            _handled     = true;
            _lastTouchMs = System.getTimer();

            var dx  = xy[0] - _dx0;
            var dy  = xy[1] - _dy0;
            var adx = (dx < 0) ? -dx : dx;
            var ady = (dy < 0) ? -dy : dy;

            if (adx < 40 && ady < 40) {
                _v.handleTap(xy[0], xy[1]);
            } else if (adx >= ady) {
                if (dx > 0) { _v.handleSwipe(0,  1); }
                else        { _v.handleSwipe(0, -1); }
            }
            // Vertical-dominant swipe in PLAY → no-op.
            WatchUi.requestUpdate();
        }
        return true;
    }
}
