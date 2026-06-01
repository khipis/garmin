// ═══════════════════════════════════════════════════════════════
// MainView.mc — Renderer + 60 ms game-loop timer.
//
// Each tick:
//   1. read the accelerometer (silent fallback if unavailable)
//   2. feed it to GameController.handleTilt(ax, ay)
//   3. ctrl.tickGame() advances all subsystems
//   4. request a redraw
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.Sensor;

class MainView extends WatchUi.View {

    var ctrl;
    hidden var _timer;

    function initialize() {
        View.initialize();
        ctrl = new GameController();
        _timer = null;
    }

    function onShow() {
        if (_timer == null) { _timer = new Timer.Timer(); }
        _timer.start(method(:onTick), SS_TICK_MS, true);
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); }
        ctrl.savePrefs();
    }

    function onTick() {
        try {
            var info = Sensor.getInfo();
            if (info != null && (info has :accel) && info.accel != null) {
                var a = info.accel;
                if (a != null && a.size() >= 2) {
                    ctrl.handleTilt(a[0], a[1]);
                }
            }
        } catch (e) {}
        // Auto-advance from SS_RESULT after its timer hits zero, so
        // the player can also just relax and let the round flow.
        if (ctrl.state == SS_RESULT && ctrl.resultT <= 0) {
            ctrl.nextRoundOrFinish();
        }
        ctrl.tickGame();
        WatchUi.requestUpdate();
    }

    function onUpdate(dc) {
        ctrl.syncDims(dc.getWidth(), dc.getHeight());
        UIManager.draw(dc, ctrl);
    }

    // ── Intents from InputHandler ────────────────────────────
    function navUp() {
        if (ctrl.state == SS_MENU) { ctrl.menuPrev(); return; }
        if (ctrl.state == SS_OVER) { ctrl.gotoMenu(); return; }
        ctrl.recalibrate();
    }
    function navDown() {
        if (ctrl.state == SS_MENU)   { ctrl.menuNext(); return; }
        if (ctrl.state == SS_OVER)   { ctrl.gotoMenu(); return; }
        if (ctrl.state == SS_RESULT) { ctrl.nextRoundOrFinish(); return; }
        ctrl.shoot();
    }
    function navSelect() {
        if (ctrl.state == SS_MENU)   { ctrl.menuActivate(); return; }
        if (ctrl.state == SS_OVER)   { ctrl.restart();      return; }
        if (ctrl.state == SS_RESULT) { ctrl.nextRoundOrFinish(); return; }
        ctrl.shoot();
    }
    function navBack() {
        if (ctrl.state != SS_MENU) { ctrl.gotoMenu(); return true; }
        return false;
    }

    function handleTap(x, y) {
        if (ctrl.state == SS_MENU) {
            var rg = UIManager.rowGeom(ctrl.sw, ctrl.sh);
            var rowH = rg[0]; var rowW = rg[1];
            var rowX = rg[2]; var rowY0 = rg[3]; var gap = rg[4];
            for (var i = 0; i < SS_MENU_ROWS; i++) {
                var ry = rowY0 + i * (rowH + gap);
                if (x >= rowX && x < rowX + rowW && y >= ry && y < ry + rowH) {
                    ctrl.setMenuRow(i); ctrl.menuActivate(); return;
                }
            }
            return;
        }
        if (ctrl.state == SS_OVER)   { ctrl.restart();        return; }
        if (ctrl.state == SS_RESULT) { ctrl.nextRoundOrFinish(); return; }
        ctrl.shoot();
    }
}
