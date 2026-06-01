// ═══════════════════════════════════════════════════════════════
// InputHandler.mc — Button + touch mappings.
//
// MENU / OVER / WIN  (single-shot navigation)
//   UP    → previous row    (also via onPreviousPage)
//   DOWN  → next row        (also via onNextPage)
//   SELECT/ENTER/START → activate / restart
//   ESC   → back out
//   tap on a row → activate that row
//
// PLAY  (DRAW-then-RELEASE is the core mechanic)
//   UP                              → recalibrate gyro
//   ENTER / DOWN / START  pressed   → start drawing the bow
//   same key released                → fire arrow with the
//                                      built-up draw power
//   touch press-and-hold             → draw the bow
//   touch release                    → fire
//   ESC                              → menu
//
// IMPORTANT: menu nav is handled ONLY via `onPreviousPage`,
// `onNextPage`, `onSelect` and tap.  We deliberately do NOT
// duplicate nav in `onKey`/`onKeyReleased` because the system
// fires those callbacks too — duplicating would advance the
// selection 2-3 times per press, which is exactly what made
// only the START row reachable in the previous build.
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.System;

const AR_PAGE_GUARD_MS = 350;

class InputHandler extends WatchUi.BehaviorDelegate {
    hidden var _v;
    hidden var _dragActive;
    hidden var _lastDragEndMs;
    // Phantom-back guard — see comment in onBack.
    hidden var _lastGestureMs;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _v             = view;
        _dragActive    = false;
        _lastDragEndMs = 0;
        _lastGestureMs = 0;
    }

    hidden function _markGesture() { _lastGestureMs = System.getTimer(); }
    hidden function _isPhantomBack() {
        if (_lastGestureMs == 0) { return false; }
        var dt = System.getTimer() - _lastGestureMs;
        return (dt >= 0 && dt < 500);
    }

    hidden function _pageFromTouch() {
        if (_dragActive) { return true; }
        if (_lastDragEndMs == 0) { return false; }
        var dt = System.getTimer() - _lastDragEndMs;
        return (dt >= 0 && dt < AR_PAGE_GUARD_MS);
    }

    hidden function _isDrawKey(k) {
        return (k == WatchUi.KEY_ENTER ||
                k == WatchUi.KEY_DOWN  ||
                k == WatchUi.KEY_START);
    }

    // ── Raw key — only ESC + recalibrate in play ─────────────
    function onKey(evt) {
        var k = evt.getKey();
        if (k == WatchUi.KEY_ESC) { return onBack(); }
        // Demo mode: ANY key exits to the menu.
        if (_v.ctrl.state == AR_DEMO) {
            _v.ctrl.gotoMenu();
            WatchUi.requestUpdate();
            return true;
        }
        if (_v.ctrl.state == AR_PLAY && k == WatchUi.KEY_UP) {
            _v.navUp();   // recalibrate
            WatchUi.requestUpdate();
            return true;
        }
        // All other keys handled via onKeyPressed/Released and the
        // higher-level page/select callbacks.  Returning false lets
        // those follow-up callbacks fire.
        return false;
    }

    // ── Press / release for the DRAW mechanic (PLAY only) ────
    function onKeyPressed(evt) {
        var k = evt.getKey();
        if (_v.ctrl.state == AR_PLAY && _isDrawKey(k)) {
            _v.startDraw();
            WatchUi.requestUpdate();
            return true;
        }
        return false;
    }
    function onKeyReleased(evt) {
        var k = evt.getKey();
        if (_v.ctrl.state == AR_PLAY && _isDrawKey(k)) {
            _v.releaseDraw();
            WatchUi.requestUpdate();
            return true;
        }
        return false;
    }

    // ── High-level navigation (single source of truth) ───────
    function onPreviousPage() {
        // Swipe-induced page event during play? swallow it.
        if (_v.ctrl.state == AR_PLAY && _pageFromTouch()) { return true; }
        if (_v.ctrl.state == AR_PLAY) {
            // Not really used in play, but keep UP as recalibrate.
            _v.navUp(); WatchUi.requestUpdate();
            return true;
        }
        _v.navUp(); WatchUi.requestUpdate(); return true;
    }
    function onNextPage() {
        if (_v.ctrl.state == AR_PLAY && _pageFromTouch()) { return true; }
        if (_v.ctrl.state == AR_PLAY) { return true; }
        _v.navDown(); WatchUi.requestUpdate(); return true;
    }

    function onSelect() {
        if (_v.ctrl.state == AR_PLAY) {
            // SELECT in PLAY is the draw key — handled by Pressed/
            // Released.  Don't navigate.
            return true;
        }
        _v.navSelect();
        WatchUi.requestUpdate();
        return true;
    }

    function onBack() {
        // Touch panels deliver a phantom onBack right after a right-
        // edge swipe / drag.  If we just processed any touch gesture,
        // swallow this back so the player's in-game gesture doesn't
        // also bounce them out of PLAY.
        if (_isPhantomBack()) { _lastGestureMs = 0; return true; }
        var consumed = _v.navBack();
        WatchUi.requestUpdate();
        if (consumed) { return true; }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    // ── Touch ─────────────────────────────────────────────
    function onSwipe(evt) { _markGesture(); return true; }

    function onTap(evt) {
        _markGesture();
        if (_v.ctrl.state == AR_MENU ||
            _v.ctrl.state == AR_OVER ||
            _v.ctrl.state == AR_WIN) {
            var xy = evt.getCoordinates();
            _v.handleTap(xy[0], xy[1]);
            WatchUi.requestUpdate();
        }
        return true;
    }

    function onDrag(evt) {
        var t = evt.getType();
        if (t == WatchUi.DRAG_TYPE_START) {
            _dragActive = true;
            if (_v.ctrl.state == AR_PLAY) {
                _v.startDraw();
                WatchUi.requestUpdate();
            }
            return true;
        }
        if (t == WatchUi.DRAG_TYPE_STOP && _dragActive) {
            _dragActive    = false;
            _lastDragEndMs = System.getTimer();
            _markGesture();
            if (_v.ctrl.state == AR_PLAY) {
                _v.releaseDraw();
                WatchUi.requestUpdate();
            }
        }
        return true;
    }
}
