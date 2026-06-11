// ═══════════════════════════════════════════════════════════════
// MainView.mc — Renderer + 80 ms game-loop timer for PixelInvaders.
//
// The board fits PI_BOARD_COLS × PI_BOARD_ROWS cells.  Cell size
// is the smaller of (maxW/cols, maxH/rows) so the whole formation
// is always visible without scrolling.
//
// Tick fires every 80 ms; controller's `tick()` no-ops outside of
// PI_PLAY.
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
        _timer.start(method(:onTick), 80, true);
    }
    function onHide() { if (_timer != null) { _timer.stop(); } }
    function onTick() {
        ctrl.tick();
        WatchUi.requestUpdate();
    }

    function onUpdate(dc) {
        _sw = dc.getWidth(); _sh = dc.getHeight();
        dc.setColor(0x000308, 0x000308); dc.clear();

        if (ctrl.state == PI_MENU) {
            UIManager.drawMenu(dc, _sw, _sh, ctrl); return;
        }
        _layout();
        UIManager.drawStars(dc, _sw, _sh);
        UIManager.drawHUD(dc, _sw, _sh, ctrl);
        UIManager.drawEnemies(dc, _ox, _oy, _cell, ctrl.swarm.enemies,
                              ctrl.swarm.walkPhase);
        UIManager.drawBullets(dc, _ox, _oy, _cell,
                              ctrl.bullets.pShots,
                              ctrl.bullets.eShots);
        UIManager.drawPlayer(dc, _ox, _oy, _cell, ctrl.player);
        UIManager.drawGroundLine(dc, _ox, _oy, _cell, _sw);
        _drawFooter(dc);
        if (ctrl.state == PI_OVER) {
            UIManager.drawResult(dc, _sw, _sh, ctrl);
        }
    }

    hidden function _layout() {
        var topPad = (_sh * 14) / 100; if (topPad < 22) { topPad = 22; }
        var botPad = (_sh * 8)  / 100; if (botPad < 14) { botPad = 14; }
        var inset  = (_sw == _sh) ? ((_sw * 5) / 100) : 4;
        var maxH   = _sh - topPad - botPad;
        var maxW   = _sw - inset * 2;
        var cellW = maxW / PI_BOARD_COLS;
        var cellH = maxH / PI_BOARD_ROWS;
        var cell  = (cellW < cellH) ? cellW : cellH;
        if (cell < 4) { cell = 4; }
        _cell = cell;
        var bpw = cell * PI_BOARD_COLS;
        var bph = cell * PI_BOARD_ROWS;
        _ox = (_sw - bpw) / 2;
        _oy = topPad + (maxH - bph) / 2;
    }

    hidden function _drawFooter(dc) {
        dc.setColor(0x668090, Graphics.COLOR_TRANSPARENT);
        var hint;
        if (ctrl.state == PI_PLAY) { hint = "tap/btn fire  swipe = move"; }
        else                        { hint = "tap = menu"; }
        dc.drawText(_sw / 2, _sh - 14, Graphics.FONT_XTINY,
                    hint, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Intents from InputHandler ────────────────────────────────
    // PLAY: every button fires.  Movement is gesture-only now —
    // the user explicitly asked for "ruchy statku tylko gestami,
    // lewy dolny przycisk też strzela jako backup".
    function navUp() {
        if (ctrl.state == PI_MENU) { ctrl.menuPrev(); return; }
        if (ctrl.state == PI_OVER) { ctrl.gotoMenu(); return; }
        ctrl.fire();
    }
    function navDown() {
        if (ctrl.state == PI_MENU) { ctrl.menuNext(); return; }
        if (ctrl.state == PI_OVER) { ctrl.gotoMenu(); return; }
        ctrl.fire();
    }
    function navSelect() {
        if (ctrl.state == PI_MENU) {
            if (ctrl.menuRow == PI_ROW_LB) { openLeaderboard(); return; }
            ctrl.menuActivate(); return;
        }
        if (ctrl.state == PI_OVER) { ctrl.gotoMenu(); return; }
        ctrl.fire();
    }

    // Open the shared global leaderboard for the current difficulty.
    function openLeaderboard() {
        var v = new LbScoresView(PI_LB_GAME_ID, ctrl.difficultyName(), "PIXEL INVADERS");
        WatchUi.pushView(v, new LbScoresDelegate(), WatchUi.SLIDE_LEFT);
    }
    function navBack() {
        if (ctrl.state != PI_MENU) { ctrl.gotoMenu(); return true; }
        return false;
    }

    // Swipe routed in screen-space deltas (dr, dc).  PixelInvaders
    // only uses horizontal swipes — left/right move the cannon
    // (with wrap-around handled by Player.nudge).  Vertical swipes
    // in play are intentionally ignored so a stray drag doesn't
    // accidentally fire or pop the menu.
    function handleSwipe(dr, dc) {
        if (ctrl.state == PI_OVER) { ctrl.gotoMenu(); return; }
        if (ctrl.state != PI_PLAY) { return; }
        if      (dc < 0) { ctrl.moveLeft();  }
        else if (dc > 0) { ctrl.moveRight(); }
        // vertical swipe: no-op in play
    }

    function handleTap(x, y) {
        if (ctrl.state == PI_MENU) {
            var rg = UIManager.rowGeom(_sw, _sh);
            var rowH = rg[0]; var rowW = rg[1];
            var rowX = rg[2]; var rowY0 = rg[3]; var gap = rg[4];
            for (var i = 0; i < PI_MENU_ROWS; i++) {
                var ry = rowY0 + i * (rowH + gap);
                if (x >= rowX && x < rowX + rowW && y >= ry && y < ry + rowH) {
                    ctrl.setMenuRow(i);
                    if (i == PI_ROW_LB) { openLeaderboard(); }
                    else { ctrl.menuActivate(); }
                    return;
                }
            }
            return;
        }
        if (ctrl.state == PI_OVER) { ctrl.gotoMenu(); return; }
        ctrl.fire();
    }
}
