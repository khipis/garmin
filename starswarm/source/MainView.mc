// ═══════════════════════════════════════════════════════════════
// MainView.mc — Renderer + 80 ms game-loop timer.
//
// We pick 80 ms for the tick rate.  At BULLET_SPEED 0.85 r/tick
// a fired bullet clears the screen in ~13 ticks (~1 s); diver
// dives last roughly 1.5 s.  Both feel snappy on every Garmin
// watch model.
//
// MENU / WIN / OVER skip `tick()` work — the timer fires every
// 80 ms but `ctrl.tick()` simply returns.
//
// Button intents are routed through small nav* methods so the
// InputHandler doesn't have to know the game state.
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
    hidden var _started;   // auto-start the run on first frame

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
        // Deep space background.
        dc.setColor(0x000510, 0x000510); dc.clear();

        // Menu lives in the shared root view — drop straight into a run and
        // never render an in-game menu here.
        if (!_started || ctrl.state == SS_MENU) {
            ctrl.startGame();
            _started = true;
        }

        _layout();
        UIManager.drawStars(dc, _sw, _sh);
        UIManager.drawHUD(dc, _sw, _sh, ctrl);
        UIManager.drawEnemies(dc, _ox, _oy, _cell, ctrl.swarm.enemies);
        UIManager.drawBullets(dc, _ox, _oy, _cell, ctrl.bullets.bullets);
        UIManager.drawPlayer(dc, _ox, _oy, _cell, ctrl.player);
        _drawFooter(dc);

        if (ctrl.state == SS_WIN)  { UIManager.drawResult(dc, _sw, _sh, true,  ctrl); }
        if (ctrl.state == SS_OVER) { UIManager.drawResult(dc, _sw, _sh, false, ctrl); }
    }

    hidden function _layout() {
        var topPad = (_sh * 14) / 100; if (topPad < 22) { topPad = 22; }
        var botPad = (_sh * 8)  / 100; if (botPad < 14) { botPad = 14; }
        var inset  = (_sw == _sh) ? ((_sw * 5) / 100) : 4;
        var maxH   = _sh - topPad - botPad;
        var maxW   = _sw - inset * 2;
        var cellW = maxW / SS_BOARD_COLS;
        var cellH = maxH / SS_BOARD_ROWS;
        var cell  = (cellW < cellH) ? cellW : cellH;
        if (cell < 4) { cell = 4; }
        _cell = cell;
        var bpw = cell * SS_BOARD_COLS;
        var bph = cell * SS_BOARD_ROWS;
        _ox = (_sw - bpw) / 2;
        _oy = topPad + (maxH - bph) / 2;
    }

    hidden function _drawFooter(dc) {
        dc.setColor(0x668090, Graphics.COLOR_TRANSPARENT);
        var hint;
        if (ctrl.state == SS_PLAY) { hint = "tap/btn fire  swipe = move"; }
        else                        { hint = "tap = restart"; }
        dc.drawText(_sw / 2, _sh - 14, Graphics.FONT_XTINY,
                    hint, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Intents from InputHandler ────────────────────────────────
    // PLAY: every button fires.  Movement is gesture-only — the
    // user explicitly asked for "ruchy statku tylko gestami,
    // lewy dolny przycisk też strzela jako backup".
    function navUp() {
        if (ctrl.state == SS_WIN || ctrl.state == SS_OVER) { ctrl.startGame(); return; }
        ctrl.fire();
    }
    function navDown() {
        if (ctrl.state == SS_WIN || ctrl.state == SS_OVER) { ctrl.startGame(); return; }
        ctrl.fire();
    }
    function navSelect() {
        if (ctrl.state == SS_WIN || ctrl.state == SS_OVER) { ctrl.startGame(); return; }
        ctrl.fire();
    }

    // BACK always pops to the shared menu.
    function navBack() {
        return false;
    }

    // Swipe in screen-space deltas (dr, dc).  StarSwarm uses only
    // the horizontal axis — left/right swipe moves the ship.
    // Vertical swipes are ignored in PLAY so a stray drag doesn't
    // accidentally fire or pop the menu.
    function handleSwipe(dr, dc) {
        if (ctrl.state == SS_WIN || ctrl.state == SS_OVER) { ctrl.startGame(); return; }
        if (ctrl.state != SS_PLAY) { return; }
        if      (dc < 0) { ctrl.moveLeft();  }
        else if (dc > 0) { ctrl.moveRight(); }
    }

    function handleTap(x, y) {
        if (ctrl.state == SS_WIN || ctrl.state == SS_OVER) { ctrl.startGame(); return; }
        // PLAY: tap = FIRE.
        ctrl.fire();
    }
}
