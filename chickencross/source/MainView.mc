// ═══════════════════════════════════════════════════════════════
// MainView.mc — Renderer + 100 ms game-loop timer.
//
// During PLAY the controller's `tick()` is called every 100 ms so
// obstacles glide smoothly across the screen.  When the chicken is
// in MENU / WIN / OVER the timer is still running but `tick()`
// no-ops, so we don't waste CPU.
//
// Controls (swipe-based):
//   PLAY:    swipe UP/DOWN/LEFT/RIGHT  → step chicken in that direction
//            buttons in PLAY are inert (so a stray press won't move her)
//   MENU:    UP/DOWN navigate rows, SELECT activates
//   WIN/OVER: any input → back to menu
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;

class MainView extends WatchUi.View {

    var ctrl;
    hidden var _timer;
    hidden var _sw;
    hidden var _sh;
    hidden var _ox;
    hidden var _oy;
    hidden var _cell;

    function initialize() {
        View.initialize();
        ctrl = new GameController();
        _timer = null;
        _sw = 0; _sh = 0; _ox = 0; _oy = 0; _cell = 0;
    }

    function onShow() {
        if (_timer == null) { _timer = new Timer.Timer(); }
        _timer.start(method(:onTick), 100, true);
    }
    function onHide() { if (_timer != null) { _timer.stop(); } }
    function onTick() {
        ctrl.tick();
        WatchUi.requestUpdate();
    }

    function onUpdate(dc) {
        _sw = dc.getWidth(); _sh = dc.getHeight();
        dc.setColor(0x081020, 0x081020); dc.clear();

        if (ctrl.state == CS_MENU) {
            UIManager.drawMenu(dc, _sw, _sh, ctrl); return;
        }
        _layout();
        UIManager.drawHUD(dc, _sw, _sh, ctrl);
        UIManager.drawBoard(dc, _ox, _oy, _cell, ctrl.lanes);
        UIManager.drawObstacles(dc, _ox, _oy, _cell, ctrl.obstacles, ctrl.lanes);
        UIManager.drawChicken(dc, _ox, _oy, _cell, ctrl.player);
        _drawFooter(dc);
        if (ctrl.state == CS_WIN)  { UIManager.drawResult(dc, _sw, _sh, true,  ctrl); }
        if (ctrl.state == CS_OVER) { UIManager.drawResult(dc, _sw, _sh, false, ctrl); }
    }

    hidden function _layout() {
        var topPad = (_sh * 14) / 100; if (topPad < 22) { topPad = 22; }
        var botPad = (_sh * 8)  / 100; if (botPad < 14) { botPad = 14; }
        var inset  = (_sw == _sh) ? ((_sw * 5) / 100) : 4;
        var maxH   = _sh - topPad - botPad;
        var maxW   = _sw - inset * 2;
        // Board is BOARD_COLS wide × BOARD_ROWS tall; cell must fit
        // both axes.
        var cellW = maxW / BOARD_COLS;
        var cellH = maxH / BOARD_ROWS;
        var cell  = (cellW < cellH) ? cellW : cellH;
        if (cell < 4) { cell = 4; }
        _cell = cell;
        var bpw = cell * BOARD_COLS;
        var bph = cell * BOARD_ROWS;
        _ox = (_sw - bpw) / 2;
        _oy = topPad + (maxH - bph) / 2;
    }

    hidden function _drawFooter(dc) {
        dc.setColor(0x778899, Graphics.COLOR_TRANSPARENT);
        var hint;
        if (ctrl.state == CS_PLAY) {
            hint = "swipe = move";
        } else {
            hint = "tap = menu";
        }
        dc.drawText(_sw / 2, _sh - 14, Graphics.FONT_XTINY,
                    hint, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Intents from InputHandler ────────────────────────────────
    // Buttons are reserved for menu / result navigation only.
    // Movement during play happens via handleSwipe() below.
    function navUp() {
        if (ctrl.state == CS_MENU) { ctrl.menuPrev(); return; }
        if (ctrl.state == CS_WIN || ctrl.state == CS_OVER) { ctrl.gotoMenu(); return; }
    }
    function navDown() {
        if (ctrl.state == CS_MENU) { ctrl.menuNext(); return; }
        if (ctrl.state == CS_WIN || ctrl.state == CS_OVER) { ctrl.gotoMenu(); return; }
    }
    function navSelect() {
        if (ctrl.state == CS_MENU) { ctrl.menuActivate(); return; }
        if (ctrl.state == CS_WIN || ctrl.state == CS_OVER) { ctrl.gotoMenu(); return; }
    }
    function navBack() {
        if (ctrl.state != CS_MENU) { ctrl.gotoMenu(); return true; }
        return false;
    }

    // Swipe routed in screen-space deltas (dr,dc).  Translate to
    // game-row deltas — note ChickenCross's "row 0 = bottom" axis,
    // so a swipe UP visually = forward (toward the goal).
    function handleSwipe(dr, dc) {
        if (ctrl.state == CS_WIN || ctrl.state == CS_OVER) { ctrl.gotoMenu(); return; }
        if (ctrl.state != CS_PLAY) { return; }
        if      (dr < 0)         { ctrl.moveUp();    }
        else if (dr > 0)         { ctrl.moveDown();  }
        else if (dc < 0)         { ctrl.moveLeft();  }
        else if (dc > 0)         { ctrl.moveRight(); }
    }

    function handleTap(x, y) {
        if (ctrl.state == CS_MENU) {
            var rg = UIManager.rowGeom(_sw, _sh);
            var rowH = rg[0]; var rowW = rg[1];
            var rowX = rg[2]; var rowY0 = rg[3]; var gap = rg[4];
            for (var i = 0; i < CC_MENU_ROWS; i++) {
                var ry = rowY0 + i * (rowH + gap);
                if (x >= rowX && x < rowX + rowW && y >= ry && y < ry + rowH) {
                    ctrl.setMenuRow(i); ctrl.menuActivate(); return;
                }
            }
            return;
        }
        if (ctrl.state == CS_WIN || ctrl.state == CS_OVER) { ctrl.gotoMenu(); return; }
        // PLAY: tap is intentionally a no-op so a fingertip rest
        // doesn't accidentally re-trigger movement.
    }
}
