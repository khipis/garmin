// ═══════════════════════════════════════════════════════════════
// MainView.mc — GyroMaze view + 80 ms game-loop timer.
//
// The view dispatches input events to the GameController and
// renders via UIManager.  The 80 ms tick drives the physics loop
// at a constant ~12.5 Hz which is well within watchdog limits
// even on the slowest Garmin VMs.
//
// navUp / navDown:
//   MENU  → cursor navigation
//   PLAY  → bump btnAy / btnAx for button-based ball steering
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;

const _GM_BTN_FORCE = 0.003;    // cell-units/tick² per button press

class MainView extends WatchUi.View {
    var ctrl;
    hidden var _timer;
    hidden var _sw;
    hidden var _sh;
    hidden var _started;   // auto-start the run on first layout

    function initialize() {
        View.initialize();
        ctrl     = new GameController();
        _timer   = null;
        _sw      = 0;
        _sh      = 0;
        _started = false;
    }

    function onShow() {
        if (_timer == null) { _timer = new Timer.Timer(); }
        _timer.start(method(:onTick), 80, true);
    }
    function onHide() {
        if (_timer != null) { _timer.stop(); }
    }

    function onTick() {
        ctrl.tick();
        if (ctrl.dirty) {
            ctrl.dirty = false;
            WatchUi.requestUpdate();
        }
    }

    function onUpdate(dc) {
        _sw = dc.getWidth(); _sh = dc.getHeight();
        // Menu lives in the shared root view — drop straight into a run and
        // never render an in-game menu here.
        if (!_started || ctrl.state == GM_MENU) {
            ctrl.startGame();
            _started = true;
        }
        if (ctrl.state == GM_WIN || ctrl.state == GM_OVER) {
            UIManager.drawEnd(dc, _sw, _sh, ctrl);
        } else {
            UIManager.drawPlay(dc, _sw, _sh, ctrl);
        }
    }

    // ── Input intents ──────────────────────────────────────────
    function navUp() {
        if (ctrl.state == GM_MENU) {
            ctrl.menuPrev(); return;
        }
        if (ctrl.state == GM_WIN)  { ctrl.nextLevel(); return; }
        if (ctrl.state == GM_OVER) { ctrl.restart();   return; }
        if (ctrl.state == GM_PLAY || ctrl.state == GM_PAUSE) {
            // Button tilt fallback: push ball up.
            ctrl.btnAy = -1;
        }
    }
    function navDown() {
        if (ctrl.state == GM_MENU) {
            ctrl.menuNext(); return;
        }
        if (ctrl.state == GM_WIN)  { ctrl.nextLevel(); return; }
        if (ctrl.state == GM_OVER) { ctrl.restart();   return; }
        if (ctrl.state == GM_PLAY || ctrl.state == GM_PAUSE) {
            ctrl.btnAy = 1;
        }
    }
    function navSelect() {
        if (ctrl.state == GM_MENU) {
            if (ctrl.menuRow == GM_ROW_LB) { openLeaderboard(); return; }
            ctrl.menuActivate(); return;
        }
        if (ctrl.state == GM_WIN)  { ctrl.nextLevel(); return; }
        if (ctrl.state == GM_OVER) { ctrl.restart();   return; }
        if (ctrl.state == GM_PAUSE) {
            ctrl.togglePause(); return;
        }
        // PLAY: restart current level.
        ctrl.restart();
    }
    function navBack() {
        if (ctrl.state == GM_PAUSE) { ctrl.togglePause(); return true; }
        // Back to the shared menu.
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
    function handleTap(x, y) {
        if (ctrl.state == GM_MENU) { _menuTap(x, y); return; }
        if (ctrl.state == GM_WIN)  { ctrl.nextLevel(); return; }
        if (ctrl.state == GM_OVER) { ctrl.restart();   return; }
        if (ctrl.state == GM_PAUSE) { ctrl.togglePause(); return; }
        ctrl.restart();
    }
    function handleHold() {
        if (ctrl.state == GM_MENU) { return; }
        ctrl.recalibrate();
    }
    function handleSwipeDir(dr, dc) {
        if (ctrl.state != GM_PLAY) { return; }
        // Swipe gives a single-tick acceleration impulse.
        var f = _GM_BTN_FORCE * 8;
        ctrl.physics.vx = ctrl.physics.vx + dc * f;
        ctrl.physics.vy = ctrl.physics.vy + dr * f;
    }

    hidden function _menuTap(x, y) {
        var rg = UIManager.rowGeom(_sw, _sh);
        var rowH = rg[0]; var rowW = rg[1];
        var rowX = rg[2]; var rowY0 = rg[3]; var gap = rg[4];
        for (var i = 0; i < GM_MENU_ROWS; i++) {
            var ry = rowY0 + i * (rowH + gap);
            if (x >= rowX && x < rowX + rowW && y >= ry && y < ry + rowH) {
                ctrl.setMenuRow(i);
                if (i == GM_ROW_LB) { openLeaderboard(); }
                else { ctrl.menuActivate(); }
                return;
            }
        }
    }

    // Open the shared global leaderboard for the current difficulty.
    function openLeaderboard() {
        var v = new LbScoresView(GM_LB_GAME_ID, ctrl.lbVariant(), "GYRO MAZE");
        WatchUi.pushView(v, new LbScoresDelegate(v), WatchUi.SLIDE_LEFT);
    }
}
