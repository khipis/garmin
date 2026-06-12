// ═══════════════════════════════════════════════════════════════
// MainView.mc — Renderer + input intent router.
// Turn-based: no game timer needed.
//
// Layout changes vs. the original Hologrid:
//   • Board area shrunk (larger top/bottom padding) so the
//     direction indicator and footer hint are comfortably visible.
//   • A large, high-contrast direction ring is drawn in the bottom
//     band; it always reflects the most recent move/swipe so the
//     player can tell what their next SELECT will do.
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
    // Last direction set by the player (swipe, tap-quadrant, or UP/DN).
    hidden var _curDir;

    function initialize() {
        View.initialize();
        ctrl = new GameController();
        _sw = 0; _sh = 0; _ox = 0; _oy = 0; _cell = 0;
        _curDir = HG_DIR_R;
    }

    function onShow() {}
    function onHide() {}

    function onUpdate(dc) {
        _sw = dc.getWidth(); _sh = dc.getHeight();
        dc.setColor(0x020610, 0x020610); dc.clear();
        if (ctrl.state == HG_S_MENU) {
            UIManager.drawMenu(dc, _sw, _sh, ctrl); return;
        }
        _layout();
        UIManager.drawHUD(dc, _sw, _sh, ctrl);
        UIManager.drawGrid    (dc, _ox, _oy, _cell, ctrl.grid);
        UIManager.drawBlockers(dc, _ox, _oy, _cell, ctrl.blockers);
        UIManager.drawPlayer  (dc, _ox, _oy, _cell, ctrl.player);
        // Big direction indicator goes in the bottom band so it
        // doesn't fight with the now-smaller board for attention.
        UIManager.drawDirIndicator(dc, _sw, _sh, _curDir, _oy + _cell * ctrl.grid.n);
        _drawFooter(dc);
        if (ctrl.state == HG_S_WIN)  { UIManager.drawResult(dc, _sw, _sh, true,  ctrl); }
        if (ctrl.state == HG_S_OVER) { UIManager.drawResult(dc, _sw, _sh, false, ctrl); }
    }

    // Board layout: top padding for HUD (already wider), generous
    // bottom padding for the big direction indicator + footer hint.
    hidden function _layout() {
        var topPad = (_sh * 14) / 100; if (topPad < 24) { topPad = 24; }
        var botPad = (_sh * 26) / 100; if (botPad < 56) { botPad = 56; }
        var inset  = (_sw == _sh) ? ((_sw * 8) / 100) : 6;
        var maxH   = _sh - topPad - botPad;
        var maxW   = _sw - inset * 2;
        var area   = (maxW < maxH) ? maxW : maxH;
        var cell   = area / ctrl.grid.n;
        if (cell < 4) { cell = 4; }
        _cell = cell;
        var bp = cell * ctrl.grid.n;
        _ox = (_sw - bp) / 2;
        _oy = topPad + (maxH - bp) / 2;
    }

    hidden function _drawFooter(dc) {
        dc.setColor(0x556677, Graphics.COLOR_TRANSPARENT);
        var hint;
        if (ctrl.state == HG_S_PLAY) {
            hint = "swipe = move";
        } else {
            hint = "Tap for menu";
        }
        dc.drawText(_sw / 2, _sh - 14, Graphics.FONT_XTINY,
                    hint, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Intents from InputHandler ────────────────────────────────
    function navUp() {
        if (ctrl.state == HG_S_MENU) { ctrl.menuPrev(); return; }
        if (ctrl.state == HG_S_WIN || ctrl.state == HG_S_OVER) { ctrl.gotoMenu(); return; }
        _curDir = (_curDir + 3) % 4;
    }
    function navDown() {
        if (ctrl.state == HG_S_MENU) { ctrl.menuNext(); return; }
        if (ctrl.state == HG_S_WIN || ctrl.state == HG_S_OVER) { ctrl.gotoMenu(); return; }
        _curDir = (_curDir + 1) % 4;
    }
    function navSelect() {
        if (ctrl.state == HG_S_MENU) {
            if (ctrl.menuRow == HG_ROW_LB) { openLeaderboard(); return; }
            ctrl.menuActivate(); return;
        }
        if (ctrl.state == HG_S_WIN || ctrl.state == HG_S_OVER) { ctrl.gotoMenu(); return; }
        ctrl.tryMove(_curDir);
    }

    // Open the shared global leaderboard (no difficulty variant).
    function openLeaderboard() {
        var v = new LbScoresView(HG_LB_GAME_ID, "", "HOLOGRID");
        WatchUi.pushView(v, new LbScoresDelegate(v), WatchUi.SLIDE_LEFT);
    }
    function navBack() {
        if (ctrl.state != HG_S_MENU) { ctrl.gotoMenu(); return true; }
        return false;
    }

    // Swipe — set direction AND move immediately.  dr/dc are unit
    // deltas (-1, 0, +1) from the swipe event.
    function handleSwipe(dr, dc) {
        if (ctrl.state == HG_S_WIN || ctrl.state == HG_S_OVER) { ctrl.gotoMenu(); return; }
        if (ctrl.state != HG_S_PLAY) { return; }
        var d = HG_DIR_R;
        if      (dr < 0) { d = HG_DIR_U; }
        else if (dr > 0) { d = HG_DIR_D; }
        else if (dc < 0) { d = HG_DIR_L; }
        else if (dc > 0) { d = HG_DIR_R; }
        _curDir = d;
        ctrl.tryMove(d);
    }

    // Tap — menu rows in MENU; "aim" in PLAY (sets direction but
    // doesn't move so the player can plan ahead and then SELECT).
    function handleTap(x, y) {
        if (ctrl.state == HG_S_MENU) {
            var rg = UIManager.rowGeom(_sw, _sh);
            var rowH = rg[0]; var rowW = rg[1];
            var rowX = rg[2]; var rowY0 = rg[3]; var gap = rg[4];
            for (var i = 0; i < HG_MENU_ROWS; i++) {
                var ry = rowY0 + i * (rowH + gap);
                if (x >= rowX && x < rowX + rowW && y >= ry && y < ry + rowH) {
                    ctrl.setMenuRow(i);
                    if (i == HG_ROW_LB) { openLeaderboard(); }
                    else { ctrl.menuActivate(); }
                    return;
                }
            }
            return;
        }
        if (ctrl.state == HG_S_WIN || ctrl.state == HG_S_OVER) { ctrl.gotoMenu(); return; }
        if (_cell <= 0) { return; }
        // Tap on play sets direction relative to player; doesn't move.
        var px = _ox + ctrl.player.c * _cell + _cell / 2;
        var py = _oy + ctrl.player.r * _cell + _cell / 2;
        var dx = x - px; var dy = y - py;
        var ax = dx < 0 ? -dx : dx;
        var ay = dy < 0 ? -dy : dy;
        if (ax > ay) { _curDir = (dx > 0) ? HG_DIR_R : HG_DIR_L; }
        else         { _curDir = (dy > 0) ? HG_DIR_D : HG_DIR_U; }
    }
}
