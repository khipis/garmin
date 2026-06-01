// ═══════════════════════════════════════════════════════════════
// MainView.mc — Renderer + 80 ms game-loop timer.
//
// Each tick we read the accelerometer (if available) and feed
// `ctrl.handleTilt(ax, ay)`.  Then `ctrl.tickGame()` advances
// the simulation.  Finally we request a redraw.
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
        _timer.start(method(:onTick), SC_TICK_MS, true);
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); }
        ctrl.savePrefs();
    }

    function onTick() {
        // Accel read (silent fallback if not exposed).
        try {
            var info = Sensor.getInfo();
            if (info != null && (info has :accel) && info.accel != null) {
                var a = info.accel;
                if (a != null && a.size() >= 2) {
                    ctrl.handleTilt(a[0], a[1]);
                }
            }
        } catch (e) {}
        ctrl.tickGame();
        WatchUi.requestUpdate();
    }

    function onUpdate(dc) {
        ctrl.syncDims(dc.getWidth(), dc.getHeight());
        UIManager.draw(dc, ctrl);
    }

    // ── Intents from InputHandler ───────────────────────────
    function navUp() {
        if (ctrl.state == SC_MENU) { ctrl.menuPrev(); return; }
        if (ctrl.state == SC_OVER) { ctrl.gotoMenu(); return; }
        ctrl.recalibrate();
    }
    function navDown() {
        if (ctrl.state == SC_MENU) { ctrl.menuNext(); return; }
        if (ctrl.state == SC_OVER) { ctrl.gotoMenu(); return; }
        ctrl.shoot();
    }
    function navSelect() {
        if (ctrl.state == SC_MENU) { ctrl.menuActivate(); return; }
        if (ctrl.state == SC_OVER) { ctrl.restart();      return; }
        ctrl.shoot();
    }
    function navBack() {
        if (ctrl.state != SC_MENU) { ctrl.gotoMenu(); return true; }
        return false;
    }

    function handleTap(x, y) {
        if (ctrl.state == SC_MENU) {
            var rg = UIManager.rowGeom(ctrl.sw, ctrl.sh);
            var rowH = rg[0]; var rowW = rg[1];
            var rowX = rg[2]; var rowY0 = rg[3]; var gap = rg[4];
            for (var i = 0; i < SC_MENU_ROWS; i++) {
                var ry = rowY0 + i * (rowH + gap);
                if (x >= rowX && x < rowX + rowW && y >= ry && y < ry + rowH) {
                    ctrl.setMenuRow(i); ctrl.menuActivate(); return;
                }
            }
            return;
        }
        if (ctrl.state == SC_OVER) { ctrl.restart(); return; }
        ctrl.shoot();
    }
}
