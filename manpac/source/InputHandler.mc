// ═══════════════════════════════════════════════════════════════
// InputHandler.mc — BehaviorDelegate for Manpac.
//
// In PLAY:
//   • Swipes (onSwipe) set Pac-Man's direction.
//   • A long drag (≥25 px on the dominant axis) is also treated as
//     a swipe — fallback for firmwares without native onSwipe.
//   • Taps are ignored during play.
//
// In MENU/RESULT:
//   • UP / PreviousPage     → move row up
//   • DOWN / NextPage       → move row down
//   • SELECT                → activate row
//   • Tap                   → hit-test menu row (handled by view)
//   • ESC                   → leave the app
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.System;

class InputHandler extends WatchUi.BehaviorDelegate {
    hidden var _v;

    hidden var _dragStartX;
    hidden var _dragStartY;
    hidden var _dragActive;
    hidden var _dragHandledInput;
    hidden var _swipeHandled;
    hidden var _lastTapMs;

    // Phantom-back guard.  On Garmin touch panels a right-edge swipe
    // delivers BOTH an onSwipe/onDrag (which is real gameplay input)
    // AND an onBack (which the system reads as the back gesture).
    // Without this guard the user's in-game swipe causes the view to
    // pop, which from the player's perspective looks like the game
    // exited mid-play.  We stamp the time of every touch gesture and
    // swallow any onBack that arrives within _PHANTOM_BACK_MS of it.
    hidden var _lastGestureMs;
    hidden const _PHANTOM_BACK_MS = 500;

    // One-shot "swallow the next page event" flag, armed the instant a
    // swipe direction is applied.  A swipe on Garmin touch panels emits a
    // single onPreviousPage/onNextPage AFTER the gesture; we consume that
    // ONE event and immediately re-arm, so a physical button pressed even
    // a fraction of a second later still steers normally.  A timeout
    // makes a stale flag harmless if a swipe produced no page event.
    hidden var _swallowPageMs;
    hidden const _SWALLOW_PAGE_MS = 350;

    // De-dupe guard so one physical button press steers only once even on
    // devices that deliver it as BOTH onKey and onPreviousPage at once.
    hidden var _lastTurnMs;
    hidden const _TURN_DEDUP_MS = 90;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _v                = view;
        _dragStartX       = 0;
        _dragStartY       = 0;
        _dragActive       = false;
        _dragHandledInput = false;
        _swipeHandled     = false;
        _lastTapMs        = 0;
        _lastGestureMs    = 0;
        _swallowPageMs    = 0;
        _lastTurnMs       = 0;
    }

    hidden function _markGesture() { _lastGestureMs = System.getTimer(); }
    hidden function _isPhantomBack() {
        if (_lastGestureMs == 0) { return false; }
        var dt = System.getTimer() - _lastGestureMs;
        return (dt >= 0 && dt < _PHANTOM_BACK_MS);
    }

    // Arm the one-shot page-event swallow (called when a swipe applies).
    hidden function _armSwallowPage() { _swallowPageMs = System.getTimer(); }

    // Returns true exactly ONCE for the page event that immediately
    // follows a swipe; clears itself so later button presses get through.
    hidden function _consumeSwipePage() {
        if (_swallowPageMs == 0) { return false; }
        var dt = System.getTimer() - _swallowPageMs;
        _swallowPageMs = 0;                 // one-shot: re-arm for next swipe
        return (dt >= 0 && dt < _SWALLOW_PAGE_MS);
    }

    // Drive a perpendicular-axis steer, de-duped so a single button press
    // that arrives via two callbacks only acts once.
    //   middle = left-middle button, !middle = left-bottom button.
    hidden function _turn(middle) {
        var now = System.getTimer();
        if (_lastTurnMs != 0 && (now - _lastTurnMs) < _TURN_DEDUP_MS) { return; }
        _lastTurnMs = now;
        if (middle) { _v.steerMiddle(); } else { _v.steerBottom(); }
        WatchUi.requestUpdate();
    }

    // Physical UP/DOWN buttons reach the app as onKey on some devices and
    // as onPreviousPage / onNextPage on others — so BOTH pathways drive
    // the perpendicular-axis steering during play (the _turn de-dupe makes
    // a single press act only once if both fire).
    //   • In play  : left-middle (UP) → steerMiddle, left-bottom (DOWN)
    //                → steerBottom — perpendicular to current heading.
    //   • In menus : UP / DOWN move the selection.
    function onKey(evt) {
        var k = evt.getKey();
        if (k == WatchUi.KEY_ESC) { return onBack(); }
        if (_v.isPlaying()) {
            if      (k == WatchUi.KEY_UP)   { _turn(true);  }
            else if (k == WatchUi.KEY_DOWN) { _turn(false); }
            else                            { _v.navSelect(); WatchUi.requestUpdate(); }
        } else {
            if      (k == WatchUi.KEY_UP)   { _v.navUp();     }
            else if (k == WatchUi.KEY_DOWN) { _v.navDown();   }
            else                            { _v.navSelect(); }
            WatchUi.requestUpdate();
        }
        return true;
    }

    function onSelect() { _v.navSelect(); WatchUi.requestUpdate(); return true; }

    // onPreviousPage / onNextPage come from BOTH swipe gestures AND the
    // physical UP/DOWN buttons (device-dependent).  A swipe arms a
    // one-shot swallow, so the single page event it spawns is dropped and
    // every other page event is treated as a real button press → steer.
    function onPreviousPage() {
        if (_v.isPlaying()) {
            if (!_consumeSwipePage()) { _turn(true); }
            return true;
        }
        _v.navUp();   WatchUi.requestUpdate(); return true;
    }
    function onNextPage() {
        if (_v.isPlaying()) {
            if (!_consumeSwipePage()) { _turn(false); }
            return true;
        }
        _v.navDown(); WatchUi.requestUpdate(); return true;
    }

    function onBack() {
        if (_isPhantomBack()) { _lastGestureMs = 0; return true; }
        var consumed = _v.navBack();
        WatchUi.requestUpdate();
        if (consumed) { return true; }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    // ── Touch ────────────────────────────────────────────────────

    function onTap(evt) {
        _markGesture();
        if (_swipeHandled)     { _swipeHandled     = false; return true; }
        if (_dragHandledInput) { _dragHandledInput = false; return true; }
        var now = System.getTimer();
        if (_lastTapMs != 0 && (now - _lastTapMs) < 250) { return true; }

        var xy = evt.getCoordinates();
        _v.handleTap(xy[0], xy[1]);
        WatchUi.requestUpdate();
        return true;
    }

    function onSwipe(evt) {
        _markGesture();
        _armSwallowPage();
        _swipeHandled = true;
        var d = evt.getDirection();
        if      (d == WatchUi.SWIPE_UP)    { _v.handleSwipe(-1,  0); }
        else if (d == WatchUi.SWIPE_DOWN)  { _v.handleSwipe( 1,  0); }
        else if (d == WatchUi.SWIPE_LEFT)  { _v.handleSwipe( 0, -1); }
        else if (d == WatchUi.SWIPE_RIGHT) { _v.handleSwipe( 0,  1); }
        WatchUi.requestUpdate();
        return true;
    }

    function onDrag(evt) {
        var xy = evt.getCoordinates();
        var t  = evt.getType();

        if (t == WatchUi.DRAG_TYPE_START) {
            _markGesture();   // covers the whole gesture so a trailing
                              // page event is recognised as swipe-derived
            _dragStartX       = xy[0];
            _dragStartY       = xy[1];
            _dragActive       = true;
            _dragHandledInput = false;
            _swipeHandled     = false;
            return true;
        }

        if (t == WatchUi.DRAG_TYPE_STOP && _dragActive) {
            _dragActive = false;
            _markGesture();
            if (_swipeHandled) { _swipeHandled = false; return true; }

            var dx  = xy[0] - _dragStartX;
            var dy  = xy[1] - _dragStartY;
            var adx = (dx < 0) ? -dx : dx;
            var ady = (dy < 0) ? -dy : dy;

            if (adx < 18 && ady < 18) {
                // Short displacement → treat as tap.
                _dragHandledInput = true;
                _lastTapMs = System.getTimer();
                _v.handleTap(xy[0], xy[1]);
                WatchUi.requestUpdate();
            } else if (adx >= 25 || ady >= 25) {
                // Long displacement → swipe on dominant axis.
                _dragHandledInput = true;
                _armSwallowPage();
                if (adx >= ady) {
                    if (dx > 0) { _v.handleSwipe(0,  1); }
                    else        { _v.handleSwipe(0, -1); }
                } else {
                    if (dy > 0) { _v.handleSwipe( 1, 0); }
                    else        { _v.handleSwipe(-1, 0); }
                }
                WatchUi.requestUpdate();
            }
        }
        return true;
    }
}
