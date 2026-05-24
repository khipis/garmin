// ═══════════════════════════════════════════════════════════════
// MainView.mc — Renderer + 100 ms game-loop timer for Dig Core.
//
// Unlike the original turn-based DigCore, the Boulder-Dash physics
// runs continuously so gravity and fireflies tick even when the
// player isn't moving.  The timer fires every 100 ms.
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

    // ── Render ───────────────────────────────────────────────────
    function onUpdate(dc) {
        _sw = dc.getWidth(); _sh = dc.getHeight();
        dc.setColor(0x080404, 0x080404); dc.clear();

        if (ctrl.state == DC_MENU) {
            UIManager.drawMenu(dc, _sw, _sh, ctrl); return;
        }
        _layout();
        UIManager.drawHUD(dc, _sw, _sh, ctrl);
        UIManager.drawGrid(dc, _ox, _oy, _cell, ctrl.grid);
        UIManager.drawFireflies(dc, _ox, _oy, _cell, ctrl.fireflies);
        UIManager.drawPlayer(dc, _ox, _oy, _cell, ctrl.player);
        _drawFooter(dc);
        if (ctrl.state == DC_WIN)  { UIManager.drawResult(dc, _sw, _sh, true,  ctrl); }
        if (ctrl.state == DC_LOSE) { UIManager.drawResult(dc, _sw, _sh, false, ctrl); }
    }

    hidden function _layout() {
        var topPad = (_sh * 14) / 100; if (topPad < 22) { topPad = 22; }
        var botPad = (_sh * 8)  / 100; if (botPad < 14) { botPad = 14; }
        var inset  = (_sw == _sh) ? ((_sw * 5) / 100) : 4;
        var maxH   = _sh - topPad - botPad;
        var maxW   = _sw - inset * 2;
        var area   = (maxW < maxH) ? maxW : maxH;
        var n      = ctrl.grid.w;
        var cell   = area / n;
        if (cell < 4) { cell = 4; }
        _cell = cell;
        var bp = cell * n;
        _ox = (_sw - bp) / 2;
        _oy = topPad + (maxH - bp) / 2;
    }

    hidden function _drawFooter(dc) {
        dc.setColor(0x886655, Graphics.COLOR_TRANSPARENT);
        var hint = (ctrl.state == DC_PLAY) ? "swipe = move" : "tap = menu";
        dc.drawText(_sw / 2, _sh - 14, Graphics.FONT_XTINY,
                    hint, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Input intents called by InputHandler ─────────────────────
    function navUp() {
        if (ctrl.state == DC_MENU) { ctrl.menuPrev(); return; }
        if (ctrl.state == DC_WIN || ctrl.state == DC_LOSE) { ctrl.gotoMenu(); return; }
    }
    function navDown() {
        if (ctrl.state == DC_MENU) { ctrl.menuNext(); return; }
        if (ctrl.state == DC_WIN || ctrl.state == DC_LOSE) { ctrl.gotoMenu(); return; }
    }
    function navSelect() {
        if (ctrl.state == DC_MENU) { ctrl.menuActivate(); return; }
        if (ctrl.state == DC_WIN || ctrl.state == DC_LOSE) { ctrl.gotoMenu(); return; }
    }
    function navBack() {
        if (ctrl.state != DC_MENU) { ctrl.gotoMenu(); return true; }
        return false;
    }

    // Swipe handler — queue the move on the controller.  dr/dc is
    // the unit delta from the swipe event.
    function handleSwipe(dr, dc) {
        if (ctrl.state == DC_WIN || ctrl.state == DC_LOSE) { ctrl.gotoMenu(); return; }
        if (ctrl.state != DC_PLAY) { return; }
        var d = DC_DIR_R;
        if      (dr < 0) { d = DC_DIR_U; }
        else if (dr > 0) { d = DC_DIR_D; }
        else if (dc < 0) { d = DC_DIR_L; }
        else if (dc > 0) { d = DC_DIR_R; }
        ctrl.queueMove(d);
    }

    function handleTap(x, y) {
        if (ctrl.state == DC_MENU) {
            var rg = UIManager.rowGeom(_sw, _sh);
            var rowH = rg[0]; var rowW = rg[1];
            var rowX = rg[2]; var rowY0 = rg[3]; var gap = rg[4];
            for (var i = 0; i < DC_MENU_ROWS; i++) {
                var ry = rowY0 + i * (rowH + gap);
                if (x >= rowX && x < rowX + rowW && y >= ry && y < ry + rowH) {
                    ctrl.setMenuRow(i); ctrl.menuActivate(); return;
                }
            }
            return;
        }
        if (ctrl.state == DC_WIN || ctrl.state == DC_LOSE) { ctrl.gotoMenu(); return; }
        // In play: tap is intentionally inert (use swipe).
    }
}
