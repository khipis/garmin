// ═══════════════════════════════════════════════════════════════
// MainView.mc — Renderer and intent router (turn-based, no timer).
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.Graphics;

class MainView extends WatchUi.View {

    var ctrl;
    hidden var _sw;
    hidden var _sh;
    hidden var _ox;
    hidden var _oy;
    hidden var _cell;
    hidden var _curDir;

    function initialize() {
        View.initialize();
        ctrl = new GameController();
        _sw = 0; _sh = 0; _ox = 0; _oy = 0; _cell = 0;
        _curDir = GM_DIR_D;
    }

    function onShow() {}
    function onHide() {}

    function onUpdate(dc) {
        _sw = dc.getWidth(); _sh = dc.getHeight();
        dc.setColor(0x040408, 0x040408); dc.clear();
        if (ctrl.state == GM_S_MENU) {
            UIManager.drawMenu(dc, _sw, _sh, ctrl); return;
        }
        _layout();
        UIManager.drawHUD   (dc, _sw, _sh, ctrl);
        UIManager.drawGrid  (dc, _ox, _oy, _cell, ctrl.grid);
        UIManager.drawPlayer(dc, _ox, _oy, _cell, ctrl.player);
        UIManager.drawDirIndicator(dc, _sw, _sh, _curDir);
        _drawFooter(dc);
        if (ctrl.state == GM_S_WIN)  { UIManager.drawResult(dc, _sw, _sh, true,  ctrl); }
        if (ctrl.state == GM_S_OVER) { UIManager.drawResult(dc, _sw, _sh, false, ctrl); }
    }

    hidden function _layout() {
        var topPad = (_sh * 12) / 100; if (topPad < 20) { topPad = 20; }
        var botPad = (_sh * 10) / 100; if (botPad < 16) { botPad = 16; }
        var inset  = (_sw == _sh) ? ((_sw * 5) / 100) : 4;
        var maxH   = _sh - topPad - botPad;
        var maxW   = _sw - inset * 2;
        // Width-fit and height-fit; pick the smaller cell so both fit.
        var fitW = maxW / ctrl.grid.w;
        var fitH = maxH / ctrl.grid.h;
        var cell = (fitW < fitH) ? fitW : fitH;
        if (cell < 4) { cell = 4; }
        _cell = cell;
        var bw = cell * ctrl.grid.w;
        var bh = cell * ctrl.grid.h;
        _ox = (_sw - bw) / 2;
        _oy = topPad + (maxH - bh) / 2;
    }

    hidden function _drawFooter(dc) {
        dc.setColor(0x556677, Graphics.COLOR_TRANSPARENT);
        var hint;
        if (ctrl.state == GM_S_PLAY) {
            hint = "UP/DN dir   SEL act   tap dir";
        } else {
            hint = "Tap for menu";
        }
        dc.drawText(_sw / 2, _sh - 14, Graphics.FONT_XTINY,
                    hint, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Intents from InputHandler ────────────────────────────────
    // UP/DOWN cycle through three options: L → D → R → L ...
    function navHoriz() {
        if (ctrl.state == GM_S_MENU) { ctrl.menuNext(); return; }
        if (ctrl.state == GM_S_WIN || ctrl.state == GM_S_OVER) { ctrl.gotoMenu(); return; }
        if      (_curDir == GM_DIR_L) { _curDir = GM_DIR_D; }
        else if (_curDir == GM_DIR_D) { _curDir = GM_DIR_R; }
        else                          { _curDir = GM_DIR_L; }
    }
    function navVert() {
        if (ctrl.state == GM_S_MENU) { ctrl.menuPrev(); return; }
        if (ctrl.state == GM_S_WIN || ctrl.state == GM_S_OVER) { ctrl.gotoMenu(); return; }
        if      (_curDir == GM_DIR_L) { _curDir = GM_DIR_R; }
        else if (_curDir == GM_DIR_R) { _curDir = GM_DIR_D; }
        else                          { _curDir = GM_DIR_L; }
    }
    function navSelect() {
        if (ctrl.state == GM_S_MENU) { ctrl.menuActivate(); return; }
        if (ctrl.state == GM_S_WIN || ctrl.state == GM_S_OVER) { ctrl.gotoMenu(); return; }
        ctrl.actMove(_curDir);
    }
    function navBack() {
        if (ctrl.state != GM_S_MENU) { ctrl.gotoMenu(); return true; }
        return false;
    }
    function handleTap(x, y) {
        if (ctrl.state == GM_S_MENU) {
            var rg = UIManager.rowGeom(_sw, _sh);
            var rowH = rg[0]; var rowW = rg[1];
            var rowX = rg[2]; var rowY0 = rg[3]; var gap = rg[4];
            for (var i = 0; i < GM_MENU_ROWS; i++) {
                var ry = rowY0 + i * (rowH + gap);
                if (x >= rowX && x < rowX + rowW && y >= ry && y < ry + rowH) {
                    ctrl.setMenuRow(i); ctrl.menuActivate(); return;
                }
            }
            return;
        }
        if (ctrl.state == GM_S_WIN || ctrl.state == GM_S_OVER) { ctrl.gotoMenu(); return; }
        if (_cell <= 0) { return; }
        // Tap the cell directly left/right of the player, or below.
        var px = _ox + ctrl.player.c * _cell + _cell / 2;
        var py = _oy + ctrl.player.r * _cell + _cell / 2;
        var dx = x - px; var dy = y - py;
        var ax = dx < 0 ? -dx : dx;
        var d;
        if (dy > ax)      { d = GM_DIR_D; }
        else if (dx > 0)  { d = GM_DIR_R; }
        else              { d = GM_DIR_L; }
        _curDir = d;
        ctrl.actMove(d);
    }
}
