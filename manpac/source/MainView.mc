// ═══════════════════════════════════════════════════════════════
// MainView.mc — Renderer + timer-driven game loop.
//
// Timer cadence comes from GameController.tickMs() and refreshes
// every time a level is built (so later levels feel faster).
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;

class MainView extends WatchUi.View {

    var ctrl;
    hidden var _timer;
    hidden var _sw;
    hidden var _sh;
    hidden var _curMs;
    hidden var _started;   // auto-start the run on first layout

    function initialize() {
        View.initialize();
        ctrl = new GameController();
        _timer = null;
        _sw = 0; _sh = 0; _curMs = 210;
        _started = false;
    }

    function onShow() {
        if (_timer == null) { _timer = new Timer.Timer(); }
        _curMs = ctrl.tickMs();
        _timer.start(method(:onTick), _curMs, true);
    }
    function onHide() { if (_timer != null) { _timer.stop(); } }
    function onTick() {
        ctrl.tick();
        // Refresh timer if the level changed its tick interval.
        var want = ctrl.tickMs();
        if (want != _curMs && _timer != null) {
            _timer.stop();
            _curMs = want;
            _timer.start(method(:onTick), _curMs, true);
        }
        WatchUi.requestUpdate();
    }

    // ── Render ───────────────────────────────────────────────────
    function onUpdate(dc) {
        _sw = dc.getWidth(); _sh = dc.getHeight();
        dc.setColor(0x000000, 0x000000); dc.clear();

        // Menu lives in the shared root view — drop straight into a run and
        // never render an in-game menu here.
        if (!_started || ctrl.state == GS_MENU) {
            ctrl.startGame();
            _started = true;
        }

        var lay = _layoutBoard();
        var ox = lay[0]; var oy = lay[1]; var cell = lay[2];
        UIManager.drawHUD(dc, _sw, _sh, ctrl);
        UIManager.drawMaze(dc, ox, oy, cell, ctrl.grid, ctrl.n);
        UIManager.drawGhosts(dc, ox, oy, cell, ctrl.ghosts, ctrl.frightTicks);
        UIManager.drawPlayer(dc, ox, oy, cell, ctrl.player);
        _drawFooter(dc);
        if (ctrl.state == GS_WIN)  { UIManager.drawResult(dc, _sw, _sh, true,  ctrl); }
        if (ctrl.state == GS_OVER) { UIManager.drawResult(dc, _sw, _sh, false, ctrl); }
    }

    // Compute (origin_x, origin_y, cell_px) so the maze always fits.
    hidden function _layoutBoard() {
        var topPad = (_sh * 14) / 100; if (topPad < 22) { topPad = 22; }
        var botPad = (_sh * 8)  / 100; if (botPad < 14) { botPad = 14; }
        var inset  = (_sw == _sh) ? ((_sw * 5) / 100) : 4;
        var maxH   = _sh - topPad - botPad;
        var maxW   = _sw - inset * 2;
        var area   = (maxW < maxH) ? maxW : maxH;
        var cell   = area / ctrl.n;
        if (cell < 4) { cell = 4; }
        var bp = cell * ctrl.n;
        var ox = (_sw - bp) / 2;
        var oy = topPad + (maxH - bp) / 2;
        return [ox, oy, cell];
    }

    hidden function _drawFooter(dc) {
        dc.setColor(0x666688, Graphics.COLOR_TRANSPARENT);
        var hint = (ctrl.state == GS_PLAY) ? "swipe / btns turn" : "tap = replay";
        dc.drawText(_sw / 2, _sh - 14, Graphics.FONT_XTINY,
                    hint, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Input intents called by InputHandler ─────────────────────
    function navUp() {
        if (ctrl.state == GS_WIN || ctrl.state == GS_OVER) { ctrl.startGame(); return; }
    }
    function navDown() {
        if (ctrl.state == GS_WIN || ctrl.state == GS_OVER) { ctrl.startGame(); return; }
    }
    function navSelect() {
        if (ctrl.state == GS_WIN || ctrl.state == GS_OVER) { ctrl.startGame(); return; }
    }

    // Open the shared global leaderboard (pushed from the view layer
    // because the controller can't manipulate the view stack).
    function openLeaderboard() {
        var v = new LbScoresView("manpac", "", "MANPAC");
        WatchUi.pushView(v, new LbScoresDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // True while a live game is running (used by the input handler to
    // separate in-game button turns from menu navigation).
    function isPlaying() { return ctrl.state == GS_PLAY; }

    // Context-aware steering for the two left buttons.  Each button
    // always drives the axis PERPENDICULAR to Pac-Man's current heading,
    // so the controls feel natural relative to what's on screen:
    //
    //   heading UP / DOWN   →  middle = LEFT,  bottom = RIGHT
    //   heading LEFT / RIGHT →  middle = UP,    bottom = DOWN
    //
    // (middle = left-middle button, bottom = left-bottom button.)
    function steerMiddle() {
        if (ctrl.state != GS_PLAY) { return; }
        var d = ctrl.player.dir;
        if (d == DIR_U || d == DIR_D) { ctrl.setDir(DIR_L); }
        else                          { ctrl.setDir(DIR_U); }
    }
    function steerBottom() {
        if (ctrl.state != GS_PLAY) { return; }
        var d = ctrl.player.dir;
        if (d == DIR_U || d == DIR_D) { ctrl.setDir(DIR_R); }
        else                          { ctrl.setDir(DIR_D); }
    }
    function navBack() {
        // Let InputHandler pop back to the shared menu.
        return false;
    }

    // Swipe handler — sets Pac-Man's direction.
    // dr/dc is the unit delta from a SWIPE_* event or a manual drag.
    function handleSwipe(dr, dc) {
        if (ctrl.state == GS_WIN || ctrl.state == GS_OVER) { ctrl.startGame(); return; }
        if (ctrl.state != GS_PLAY) { return; }
        var d = DIR_R;
        if      (dr < 0) { d = DIR_U; }
        else if (dr > 0) { d = DIR_D; }
        else if (dc < 0) { d = DIR_L; }
        else if (dc > 0) { d = DIR_R; }
        ctrl.setDir(d);
    }

    // Tap: in menu, activate the row under the tap; on result
    // screen, return to menu.  In play, ignored (we use swipes).
    function handleTap(x, y) {
        if (ctrl.state == GS_WIN || ctrl.state == GS_OVER) { ctrl.startGame(); return; }
        // In play: tap is intentionally a no-op so a fingertip rest
        // doesn't trigger an accidental direction change.
    }
}
