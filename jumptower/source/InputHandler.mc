// ═══════════════════════════════════════════════════════════════
// InputHandler.mc — Maps Garmin inputs to player intent.
//
// Buttons (5-button watch layout)
//   KEY_UP press/release   → hold "left"  (continuous)
//   KEY_DOWN press/release → hold "right" (continuous)
//   KEY_ENTER / SELECT     → start round (when on menu) or harmless
//   KEY_ESC                → BACK (menu / exit; never during PLAY)
//
// Touch (PLAY / READY) — drag-based steering
//   Press & hold ANYWHERE on the touch panel — once the finger has
//   travelled past a small deadzone (8 px) the character starts
//   moving toward whichever screen half the finger currently sits
//   on.  Move the finger across the midline → the character flips
//   direction live.  Lift the finger → character stops accelerating.
//
//   Old behaviour issued a SHORT impulse from onSwipe + onTap that
//   sometimes collided (final tap coordinate fired an opposing
//   impulse on top of the swipe, which on some devices made
//   "swipe right" perceptibly move LEFT first).  Drag steering
//   sidesteps both the impulse-collision and the device-specific
//   SWIPE_LEFT vs SWIPE_RIGHT direction convention entirely.
//
//   Trailing-event guards we have to defend against on Fenix-class
//   touch panels:
//     • A swipe-LEFT often ends with an onTap fired AT THE TOUCH-DOWN
//       coordinate (i.e. on the right half of the screen).  Without
//       a guard, that tap's "right half" was being interpreted as
//       tap(+1) → tapImpulse(+1) → +vx → the character lurched back
//       to the right just after the swipe finished.
//     • Some firmwares route horizontal swipes through
//       onPreviousPage / onNextPage with no consistent direction
//       convention; routing those to tap impulses during PLAY can
//       fire the wrong direction.
//   Fix: a `_justDragged` flag (set on any drag-with-motion) gates
//   onTap / onPreviousPage / onNextPage for 300 ms after the drag.
//
// Touch (MENU / OVER)
//   Tap          → confirm / continue (start / back-to-menu)
//   Swipe        → confirm (any direction)
//
// onKeyPressed / onKeyReleased give us "hold" behaviour without
// polling the key state every tick.
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.System;

class InputHandler extends WatchUi.BehaviorDelegate {
    hidden var _v;
    // Phantom-back guard — see onBack.
    hidden var _lastGestureMs;
    // Trailing-event guard.  Set to the timestamp at which the most
    // recent drag-with-motion ended.  Any onTap / onPreviousPage /
    // onNextPage that arrives within _DRAG_GUARD_MS of that mark is
    // ignored — it's the lift-off ghost event, not a new gesture.
    hidden var _lastDragMs;
    hidden const _DRAG_GUARD_MS = 300;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _v             = view;
        _lastGestureMs = 0;
        _lastDragMs    = 0;
        _touchActive   = false;
        _touchSide     = 0;
        _dragStartX    = -1;
        _dragStartY    = -1;
        _dragMoved     = false;
    }

    hidden function _markGesture() { _lastGestureMs = System.getTimer(); }
    hidden function _isPhantomBack() {
        if (_lastGestureMs == 0) { return false; }
        var dt = System.getTimer() - _lastGestureMs;
        return (dt >= 0 && dt < 500);
    }
    hidden function _inDragGuard() {
        if (_lastDragMs == 0) { return false; }
        var dt = System.getTimer() - _lastDragMs;
        return (dt >= 0 && dt < _DRAG_GUARD_MS);
    }

    function onKeyPressed(evt) {
        var k = evt.getKey();
        // On the menu, UP/DOWN move the row cursor instead of steering.
        if (_v.inMenu()) {
            if      (k == WatchUi.KEY_UP)   { _v.navUp();   WatchUi.requestUpdate(); }
            else if (k == WatchUi.KEY_DOWN) { _v.navDown(); WatchUi.requestUpdate(); }
            return true;
        }
        if      (k == WatchUi.KEY_UP)    { _v.holdLeft(true);  }
        else if (k == WatchUi.KEY_DOWN)  { _v.holdRight(true); }
        return true;
    }
    function onKeyReleased(evt) {
        var k = evt.getKey();
        if (_v.inMenu()) { return true; }
        if      (k == WatchUi.KEY_UP)    { _v.holdLeft(false);  }
        else if (k == WatchUi.KEY_DOWN)  { _v.holdRight(false); }
        return true;
    }

    function onKey(evt) {
        var k = evt.getKey();
        if (k == WatchUi.KEY_ESC) {
            // PHYSICAL ESC — dedicated path so it works even while we
            // are swallowing every touch-back during PLAY (see
            // onBack() below).  Goes through handleBack() so the
            // controller does the proper state transition for the
            // current screen (PLAY/READY/OVER → menu;  MENU → fall
            // through and let the system exit the app).
            if (_v.handleBack()) {
                WatchUi.requestUpdate();
                return true;
            }
            return false;
        }
        // UP/DOWN are handled by onKeyPressed (menu nav / in-play steering);
        // never let them fall through to "confirm" on the menu.
        if (k == WatchUi.KEY_UP || k == WatchUi.KEY_DOWN) { return true; }
        // For ENTER and others — treat as "confirm" on menu/over screens.
        if (_v.isPassiveState()) {
            _v.confirm();
            WatchUi.requestUpdate();
        }
        return true;
    }

    function onSelect()       { _v.confirm(); WatchUi.requestUpdate(); return true; }

    // Some Fenix firmwares route horizontal swipes through these page
    // handlers with no consistent left/right direction convention.
    // During PLAY/READY that produced a contradictory tap-impulse
    // right after the drag-steering had already moved the character
    // in the OTHER direction (the visible bug: swipe-left ran the
    // character left, then *yanked* it right).  Restrict the page
    // impulse to passive states (where it harmlessly maps to
    // confirm) and ignore it while a drag is in flight.
    function onPreviousPage() {
        _markGesture();
        if (_inDragGuard()) { return true; }
        if (_v.isPassiveState()) {
            _v.confirm();
            WatchUi.requestUpdate();
            return true;
        }
        // In PLAY/READY we deliberately do NOT issue an impulse — drag
        // steering already handled the gesture.
        return true;
    }
    function onNextPage() {
        _markGesture();
        if (_inDragGuard()) { return true; }
        if (_v.isPassiveState()) {
            _v.confirm();
            WatchUi.requestUpdate();
            return true;
        }
        return true;
    }

    function onTap(evt) {
        _markGesture();
        // Suppress lift-off ghost taps.  On Fenix touch panels the
        // tap delivered at the END of a drag often reports the
        // TOUCH-DOWN coordinate, not the lift-off coordinate — which
        // for a swipe-left lands on the right half of the screen
        // and would otherwise issue a right-impulse against the
        // character that just finished moving left.
        if (_inDragGuard()) { return true; }
        // In MENU / OVER any tap means "continue".  In PLAY / READY
        // we route through handleTap which currently also issues a
        // one-shot impulse based on the screen half — that stays as
        // a fallback for very-short touches that don't generate an
        // onDrag sequence.
        var xy = evt.getCoordinates();
        _v.handleTap(xy[0], xy[1]);
        WatchUi.requestUpdate();
        return true;
    }

    function onSwipe(evt) {
        _markGesture();
        // Drag-based steering does the in-play work; onSwipe is only
        // useful in passive states (MENU, OVER) where it means
        // "any swipe = confirm / continue".
        if (_v.isPassiveState()) {
            _v.confirm();
            WatchUi.requestUpdate();
        }
        return true;
    }

    // ── Drag-based steering ────────────────────────────────────
    // We track the finger's current screen-half during PLAY / READY
    // and tell MainView.touchSteer which way to push the character.
    // _touchActive is set when the gesture started in an in-play
    // state — that prevents a drag that began in MENU from leaking
    // a hold-down into the game after the menu activates.
    //
    // CRITICAL: we do NOT commit a side at DRAG_TYPE_START.  Earlier
    // versions did, which meant the very first frame of a swipe-LEFT
    // (finger touching down on the right half of the screen) snapped
    // holdRight=true for a brief moment before CONTINUE flipped it
    // to holdLeft.  Now we only commit once the finger has cleared
    // _DRAG_DEAD_PX from the touch-down point — at which time the
    // current half is the *intended* direction.
    hidden var _touchActive;
    hidden var _touchSide;
    hidden var _dragStartX;
    hidden var _dragStartY;
    hidden var _dragMoved;
    hidden const _DRAG_DEAD_PX = 8;

    function onDrag(evt) {
        _markGesture();
        var t  = evt.getType();
        var xy = evt.getCoordinates();
        if (xy == null) { return true; }

        if (t == WatchUi.DRAG_TYPE_START) {
            _touchActive = !_v.isPassiveState();
            _touchSide   = 0;
            _dragStartX  = xy[0];
            _dragStartY  = xy[1];
            _dragMoved   = false;
            // No commit yet — wait for the finger to move past the
            // deadzone so we don't lurch toward the touch-down half.
            return true;
        }
        if (t == WatchUi.DRAG_TYPE_CONTINUE) {
            if (!_touchActive) { return true; }
            if (!_dragMoved) {
                var dx = xy[0] - _dragStartX;
                var dy = xy[1] - _dragStartY;
                var adx = (dx < 0) ? -dx : dx;
                var ady = (dy < 0) ? -dy : dy;
                if (adx < _DRAG_DEAD_PX && ady < _DRAG_DEAD_PX) {
                    return true;
                }
                _dragMoved = true;
            }
            _applyTouchSide(xy[0]);
            return true;
        }
        if (t == WatchUi.DRAG_TYPE_STOP) {
            if (_touchActive) {
                _v.touchSteer(0);
                _touchActive = false;
            }
            // Mark the trailing-event guard ONLY when the user
            // actually moved.  A pure stationary press (no motion)
            // should fall through to the onTap fallback.
            if (_dragMoved) {
                _lastDragMs = System.getTimer();
            }
            _dragStartX = -1;
            _dragStartY = -1;
            _dragMoved  = false;
            return true;
        }
        return true;
    }

    hidden function _applyTouchSide(px) {
        var midW = _v.screenW() / 2;
        var newSide = (px < midW) ? -1 : 1;
        if (newSide != _touchSide) {
            _touchSide = newSide;
            _v.touchSteer(newSide);
            WatchUi.requestUpdate();
        }
    }

    function onBack() {
        // During PLAY / READY we must block touch-triggered back events
        // (right-edge swipe on Fenix-class produces a spurious onBack that
        // would dump the player out mid-run).  We do this by checking the
        // phantom-back guard: if a touch/drag just happened the event is a
        // ghost and we swallow it; if not, it came from the physical button
        // and we honour it.
        if (!_v.isPassiveState()) {
            if (_isPhantomBack()) { _lastGestureMs = 0; return true; }
            if (_v.handleBack()) { WatchUi.requestUpdate(); return true; }
            return true;
        }
        // Passive states (MENU, OVER) — same phantom guard, then normal flow.
        if (_isPhantomBack()) { _lastGestureMs = 0; return true; }
        if (_v.handleBack()) {
            WatchUi.requestUpdate();
            return true;
        }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
