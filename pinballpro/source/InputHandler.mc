// ═══════════════════════════════════════════════════════════════
// InputHandler.mc — Maps Garmin inputs to flippers + launch.
//
// Buttons (5-button Garmin layout)
//   In GS_MENU:
//     KEY_UP / KEY_DOWN        → walk menu rows
//     KEY_ENTER / SELECT       → activate row (pick table / start)
//     KEY_ESC                  → exit
//
//   In GS_PLAY / GS_LAUNCH:
//     KEY_UP   pressed/released  → BOTH flippers hold
//     KEY_DOWN pressed/released  → BOTH flippers hold
//     KEY_ENTER / SELECT         → launch / dismiss
//     KEY_ESC                    → return to menu
//
// Touch — the touch experience now mirrors the button experience:
//   * Quick tap  (onDrag-START + STOP, small displacement, ≤ 300 ms)
//                → BOTH flippers PULSE for ~400 ms  (full swing, then down)
//   * Hold        (onDrag-START + STOP, ≥ 300 ms hold or large drag)
//                → press on START, release immediately on STOP
//   * Plain onTap (on firmware where onDrag doesn't fire first)
//                → BOTH flippers PULSE for ~400 ms  (fallback)
//
// Why not just "press on START, release on STOP"?
//   On all tested Garmin firmwares, when the user does a quick tap:
//     1. onDrag(DRAG_TYPE_START) fires → press() called
//     2. onDrag(DRAG_TYPE_STOP)  fires → release() called (0–1 tick later)
//     3. onTap never fires (onDrag returned true, event consumed)
//   Net effect: flipper activates for ≈0 frames → player sees no movement.
//   The fix: on DRAG_TYPE_STOP, if the touch was short (≤ TAP_FRAMES),
//   call pulse() instead of release() so the flipper completes a full swing.
//
// Why not just always pulse on STOP?
//   A deliberate "hold flipper up while aiming" hold should drop the flipper
//   immediately when the finger lifts. Tracking duration (TAP_FRAMES threshold)
//   lets us distinguish quick-tap from deliberate hold.
//
// Belt-and-braces safety net:
//   For the "touch held but onDrag-STOP never fires" case (battery
//   saver killing the touch session, etc.), MainView runs a safety
//   counter that force-releases the flippers after ~1 s of unbroken
//   touch hold. So even a totally broken touch session can't park
//   the flippers in the air.
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.System;

class InputHandler extends WatchUi.BehaviorDelegate {
    hidden var _v;
    // Phantom-back guard — see onBack.
    hidden var _lastGestureMs;

    // Drag state — tracks one in-progress touch.
    hidden var _dragStartX;
    hidden var _dragStartY;
    hidden var _dragActive;
    // True while we are HOLDING the flippers because of a touch press.
    // We only release them when WE pressed them — never trample a
    // button-hold release on accident.
    hidden var _touchHoldingFlippers;
    // Counts game-tick frames since the current touch started.
    // Incremented by tickTouch() (called once per frame from MainView).
    // Used to distinguish a quick tap (<= TAP_FRAMES) from a deliberate
    // hold so we can decide whether to pulse or immediately release the
    // flippers when the finger lifts.
    hidden var _touchFrameCount;
    static var TAP_FRAMES = 12;   // 12 frames × 25 ms ≈ 300 ms

    function initialize(view) {
        BehaviorDelegate.initialize();
        _v = view;
        _dragStartX = -1;
        _dragStartY = -1;
        _dragActive = false;
        _touchHoldingFlippers = false;
        _touchFrameCount = 0;
        _lastGestureMs = 0;
    }

    hidden function _markGesture() { _lastGestureMs = System.getTimer(); }
    hidden function _isPhantomBack() {
        if (_lastGestureMs == 0) { return false; }
        var dt = System.getTimer() - _lastGestureMs;
        return (dt >= 0 && dt < 500);
    }

    // Called once per game tick by MainView while a touch hold is active.
    function tickTouch() { _touchFrameCount++; }

    function onKeyPressed(evt) {
        var k = evt.getKey();
        if (_v._ctrl.state == GS_MENU) {
            if      (k == WatchUi.KEY_UP)   { _v.menuPrev(); WatchUi.requestUpdate(); }
            else if (k == WatchUi.KEY_DOWN) { _v.menuNext(); WatchUi.requestUpdate(); }
            return true;
        }
        if (k == WatchUi.KEY_UP || k == WatchUi.KEY_DOWN) {
            _v.flipBothPress();
        }
        return true;
    }
    function onKeyReleased(evt) {
        if (_v._ctrl.state == GS_MENU) { return true; }
        var k = evt.getKey();
        if (k == WatchUi.KEY_UP || k == WatchUi.KEY_DOWN) {
            _v.flipBothRelease();
        }
        return true;
    }

    function onKey(evt) {
        var k = evt.getKey();
        if (k == WatchUi.KEY_ESC) { return onBack(); }
        _v.confirm();
        WatchUi.requestUpdate();
        return true;
    }

    function onSelect()       { _v.confirm(); WatchUi.requestUpdate(); return true; }

    // Pure-`onTap` fallback. Pulses the flippers for ~400 ms because
    // we don't get a touch-up signal — see Flipper.pulse.
    function onTap(evt) {
        _markGesture();
        var xy = evt.getCoordinates();
        var ctrl = _v._ctrl;
        if (ctrl.state == GS_MENU)   { _v.confirm();                       WatchUi.requestUpdate(); return true; }
        if (ctrl.state == GS_OVER)   { _v.gotoMenu();                      WatchUi.requestUpdate(); return true; }
        if (ctrl.state == GS_LAUNCH) { _v.launchBall();                    WatchUi.requestUpdate(); return true; }
        // GS_PLAY — pulse both flippers.
        _v.tapPulseFlippers();
        WatchUi.requestUpdate();
        return true;
    }

    function onSwipe(evt) {
        _markGesture();
        // A real swipe means the finger moved a lot — not a tap.
        // Clean up any in-progress touch state and treat as confirm.
        if (_touchHoldingFlippers) {
            _v.flipBothRelease();
            _touchHoldingFlippers = false;
        }
        _dragActive = false;
        _v.confirm();
        WatchUi.requestUpdate();
        return true;
    }

    // Touch-as-button. Press flippers on touch-down (immediate, no
    // latency), release on touch-up.
    function onDrag(evt) {
        var xy = evt.getCoordinates();
        var t  = evt.getType();
        var ctrl = _v._ctrl;

        if (t == WatchUi.DRAG_TYPE_START) {
            _dragStartX = xy[0];
            _dragStartY = xy[1];
            _dragActive = true;
            _touchFrameCount = 0;
            // Fire flippers IMMEDIATELY on touch-down during play —
            // this is the latency win vs the old onTap path.
            if (ctrl.state == GS_PLAY) {
                _v.flipBothPress();
                _touchHoldingFlippers = true;
            }
        } else if (t == WatchUi.DRAG_TYPE_STOP) {
            _markGesture();
            var wasTouchHolding = _touchHoldingFlippers;
            _touchHoldingFlippers = false;

            if (_dragActive) {
                _dragActive = false;
                var dx = xy[0] - _dragStartX;
                var dy = xy[1] - _dragStartY;
                if (dx < 0) { dx = -dx; }
                if (dy < 0) { dy = -dy; }
                var isTap = (dx < 14 && dy < 14);

                if (ctrl.state == GS_PLAY) {
                    if (wasTouchHolding) {
                        if (isTap && _touchFrameCount <= TAP_FRAMES) {
                            // Quick tap: onTap will NOT fire after onDrag on
                            // most Garmin firmwares (event is consumed), so we
                            // replicate it here — pulse the flippers so they
                            // complete a full swing instead of immediately
                            // releasing.
                            _v.tapPulseFlippers();
                        } else {
                            // Long deliberate hold released: drop immediately.
                            _v.flipBothRelease();
                        }
                    }
                } else {
                    if (isTap) {
                        // Small displacement on a non-play state → tap.
                        if (ctrl.state == GS_MENU)   { _v.confirm();    WatchUi.requestUpdate(); }
                        if (ctrl.state == GS_OVER)   { _v.gotoMenu();   WatchUi.requestUpdate(); }
                        if (ctrl.state == GS_LAUNCH) { _v.launchBall(); WatchUi.requestUpdate(); }
                    }
                }
            }
        }
        return true;
    }

    function onBack() {
        if (_isPhantomBack()) { _lastGestureMs = 0; return true; }
        if (_v.handleBack()) {
            WatchUi.requestUpdate();
            return true;
        }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    // Called by MainView once per frame to enforce the safety
    // auto-release on a touch hold that never produced a STOP event.
    // Returns the current "touch is holding flippers" flag so the
    // view can decide whether to safety-release.
    function isTouchHoldingFlippers() { return _touchHoldingFlippers; }
    function clearTouchHoldingFlippers() {
        _touchHoldingFlippers = false;
        _dragActive = false;
    }
}
