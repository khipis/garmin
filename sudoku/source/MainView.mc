// ═══════════════════════════════════════════════════════════════
// MainView.mc — WatchUi.View glue.
//
// Owns the GameController and UIManager. Receives high-level input
// intents from InputHandler and dispatches them based on the active
// game state. A 500 ms timer ticks the play-clock; redraws are only
// requested when the controller marks itself dirty (or on input).
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.System;

class MainView extends WatchUi.View {

    hidden var _ctrl;
    hidden var _ui;
    hidden var _timer;

    function initialize() {
        View.initialize();
        _ctrl  = new GameController();
        _ui    = new UIManager();
        _timer = null;
    }

    function onLayout(dc) {
        _ui.layout(dc, _ctrl.grid.n, _ctrl.state);
    }

    function onShow() {
        if (_timer == null) { _timer = new Timer.Timer(); }
        _timer.start(method(:onTick), 500, true);
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); }
    }

    function onTick() {
        // While playing, update the elapsed clock and ask for a redraw
        // so the HUD time stays accurate.
        if (_ctrl.state == GS_PLAY) {
            _ctrl.tickTimer();
            _ctrl.dirty = true;
        }
        if (_ctrl.dirty) {
            _ctrl.dirty = false;
            WatchUi.requestUpdate();
        }
    }

    // ── Drawing ──────────────────────────────────────────────────────
    function onUpdate(dc) {
        if (_ctrl.state == GS_MENU) {
            _ui.drawMenu(dc, _ctrl);
            return;
        }
        _ui.drawBoard(dc, _ctrl);
        _ui.drawHUD(dc, _ctrl);
        _ui.drawFooter(dc, _ctrl);
        if (_ctrl.state == GS_PAUSED)   { _ui.drawPaused(dc);          }
        if (_ctrl.state == GS_COMPLETE) { _ui.drawComplete(dc, _ctrl); }
        if (_ctrl.state == GS_FAILED)   { _ui.drawFailed(dc, _ctrl);   }
    }

    // ── Public intents (called from InputHandler) ────────────────────
    function navUp() {
        if (_ctrl.state == GS_MENU) {
            _ctrl.menuSel = (_ctrl.menuSel + 3) % 4;
            _ctrl.dirty = true;
            return;
        }
        if (_ctrl.state == GS_PLAY)    { _ctrl.cycleCell(true); return; }
        if (_ctrl.state == GS_PAUSED)  { _ctrl.resume();        return; }
        if (_ctrl.state == GS_COMPLETE || _ctrl.state == GS_FAILED) {
            _ctrl.gotoMenu();
        }
    }

    function navDown() {
        if (_ctrl.state == GS_MENU) {
            _ctrl.menuSel = (_ctrl.menuSel + 1) % 4;
            _ctrl.dirty = true;
            return;
        }
        if (_ctrl.state == GS_PLAY)    { _ctrl.cycleCell(false); return; }
        if (_ctrl.state == GS_PAUSED)  { _ctrl.resume();         return; }
        if (_ctrl.state == GS_COMPLETE || _ctrl.state == GS_FAILED) {
            _ctrl.gotoMenu();
        }
    }

    function navSelect() {
        if (_ctrl.state == GS_MENU) {
            _menuActivate();
            return;
        }
        if (_ctrl.state == GS_PLAY) {
            // Move cursor right → next row when wrapping. Quick way to
            // step through cells with a single button on non-touch
            // watches.
            var n = _ctrl.grid.n;
            var nc = _ctrl.curC + 1;
            var nr = _ctrl.curR;
            if (nc >= n) { nc = 0; nr = (nr + 1) % n; }
            _ctrl.curR = nr; _ctrl.curC = nc;
            _ctrl.dirty = true;
            return;
        }
        if (_ctrl.state == GS_PAUSED) { _ctrl.resume();   return; }
        if (_ctrl.state == GS_COMPLETE || _ctrl.state == GS_FAILED) {
            _ctrl.gotoMenu();
        }
    }

    // BACK semantics depend on state:
    //   menu      → unhandled (delegate pops view → exit app)
    //   play      → strict: submit board; relaxed: go to menu
    //   paused    → menu
    //   complete  → menu
    //   failed    → resume to play (so user can fix)
    function navBack() {
        if (_ctrl.state == GS_MENU) { return false; }
        if (_ctrl.state == GS_PLAY) {
            if (_ctrl.valMode == VAL_STRICT) {
                _ctrl.submit();
            } else {
                _ctrl.gotoMenu();
            }
            return true;
        }
        if (_ctrl.state == GS_PAUSED)   { _ctrl.gotoMenu(); return true; }
        if (_ctrl.state == GS_COMPLETE) { _ctrl.gotoMenu(); return true; }
        if (_ctrl.state == GS_FAILED) {
            // Drop back into play so the player can fix mistakes.
            _ctrl.resumeFromFailed();
            return true;
        }
        return false;
    }

    hidden function _menuActivate() {
        var s = _ctrl.menuSel;
        if (s == 0) {
            _ctrl.mode = (_ctrl.mode + 1) % 2;
        } else if (s == 1) {
            _ctrl.diff = (_ctrl.diff + 1) % 3;
        } else if (s == 2) {
            _ctrl.valMode = (_ctrl.valMode + 1) % 2;
        } else {
            _ctrl.startGame();
        }
        if (s < 3) { _ctrl.saveMenuSettings(); }
        _ctrl.dirty = true;
    }

    function handleTap(x, y) {
        if (_ctrl.state == GS_MENU) {
            _menuTap(x, y);
            return;
        }
        if (_ctrl.state == GS_PAUSED) { _ctrl.resume(); return; }
        if (_ctrl.state == GS_COMPLETE || _ctrl.state == GS_FAILED) {
            _ctrl.gotoMenu(); return;
        }
        if (_ctrl.state != GS_PLAY) { return; }
        // Pick the cell under the tap.
        var rc = _ui.tapToCell(x, y, _ctrl.grid.n);
        if (rc[0] < 0) {
            // Tap outside the board cycles the current cell's digit
            // (handy on tiny screens where it's tricky to hit a cell).
            _ctrl.cycleCell(true);
            return;
        }
        if (_ctrl.curR == rc[0] && _ctrl.curC == rc[1]) {
            // Tapping the already-selected cell cycles its digit.
            _ctrl.cycleCell(true);
        } else {
            _ctrl.curR = rc[0]; _ctrl.curC = rc[1];
            _ctrl.dirty = true;
        }
    }

    function handleHold(x, y) {
        if (_ctrl.state != GS_PLAY) { return; }
        var rc = _ui.tapToCell(x, y, _ctrl.grid.n);
        if (rc[0] < 0) { return; }
        _ctrl.curR = rc[0]; _ctrl.curC = rc[1];
        _ctrl.clearCell();
    }

    function handleSwipe(dir) {
        if (_ctrl.state != GS_PLAY) { return; }
        if      (dir == WatchUi.SWIPE_UP)    { _ctrl.moveCursor(-1, 0); }
        else if (dir == WatchUi.SWIPE_DOWN)  { _ctrl.moveCursor( 1, 0); }
        else if (dir == WatchUi.SWIPE_LEFT)  { _ctrl.moveCursor( 0,-1); }
        else if (dir == WatchUi.SWIPE_RIGHT) { _ctrl.moveCursor( 0, 1); }
    }

    // Map a tap on the menu screen to the nearest menu row.
    hidden function _menuTap(x, y) {
        // Recompute the same geometry the menu renderer uses.
        // (h, rowH, gap, startY) — mirror UIManager.drawMenu.
        // We can ask the system for screen dims via System.getDeviceSettings.
        var ds = System.getDeviceSettings();
        var h  = ds.screenHeight;
        var rowH = h * 11 / 100; if (rowH < 22) { rowH = 22; }
        var gap  = h * 2  / 100; if (gap  < 3)  { gap  = 3;  }
        var startY = h * 24 / 100;
        for (var i = 0; i < 4; i++) {
            var ry = startY + i * (rowH + gap);
            if (y >= ry && y < ry + rowH) {
                _ctrl.menuSel = i;
                _menuActivate();
                return;
            }
        }
    }
}
