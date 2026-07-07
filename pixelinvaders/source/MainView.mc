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
    hidden var _started;   // auto-start the run on first layout

    function initialize() {
        View.initialize();
        ctrl = new GameController();
        _timer = null;
        _sw = 0; _sh = 0; _ox = 0; _oy = 0; _cell = 0;
        _started = false;
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

        // Menu lives in the shared root view — drop straight into a run and
        // never render an in-game menu here.
        if (!_started || ctrl.state == PI_MENU) {
            ctrl.startGame();
            _started = true;
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
        else                        { hint = "tap = restart"; }
        dc.drawText(_sw / 2, _sh - 14, Graphics.FONT_XTINY,
                    hint, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Intents from InputHandler ────────────────────────────────
    // PLAY: every button fires.  Movement is gesture-only now —
    // the user explicitly asked for "ruchy statku tylko gestami,
    // lewy dolny przycisk też strzela jako backup".
    function navUp() {
        if (ctrl.state == PI_OVER) { ctrl.startGame(); return; }
        ctrl.fire();
    }
    function navDown() {
        if (ctrl.state == PI_OVER) { ctrl.startGame(); return; }
        ctrl.fire();
    }
    function navSelect() {
        if (ctrl.state == PI_OVER) { ctrl.startGame(); return; }
        ctrl.fire();
    }

    // BACK always pops to the shared menu.
    function navBack() {
        return false;
    }

    // Swipe routed in screen-space deltas (dr, dc).  PixelInvaders
    // only uses horizontal swipes — left/right move the cannon
    // (with wrap-around handled by Player.nudge).  Vertical swipes
    // in play are intentionally ignored so a stray drag doesn't
    // accidentally fire or pop the menu.
    function handleSwipe(dr, dc) {
        if (ctrl.state == PI_OVER) { ctrl.startGame(); return; }
        if (ctrl.state != PI_PLAY) { return; }
        if      (dc < 0) { ctrl.moveLeft();  }
        else if (dc > 0) { ctrl.moveRight(); }
        // vertical swipe: no-op in play
    }

    function handleTap(x, y) {
        if (ctrl.state == PI_OVER) { ctrl.startGame(); return; }
        ctrl.fire();
    }
}
