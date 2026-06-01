// ═══════════════════════════════════════════════════════════════
// MainView.mc — Timer-driven game loop + DC owner.
//
//   • 50 ms tick reads accelerometer, calls ctrl.tick().
//   • onUpdate composes the frame via UIManager.draw().
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
        ctrl   = new GameController();
        _timer = new Timer.Timer();
    }

    function onLayout(dc) {
        ctrl.setScreen(dc.getWidth(), dc.getHeight());
    }

    function onShow() {
        try { Sensor.enableSensorEvents(method(:_onSensor)); }
        catch (e) {}
        _timer.start(method(:onTick), SR_TICK_MS, true);
    }

    function onHide() {
        _timer.stop();
        try { Sensor.enableSensorEvents(null); } catch (e) {}
    }

    hidden var _lastAx;
    hidden var _lastAy;
    function _onSensor(info) {
        if (info != null && info.accel != null && info.accel.size() >= 2) {
            _lastAx = info.accel[0];
            _lastAy = info.accel[1];
        }
    }

    function onTick() {
        // If sensor events haven't started yet (or are unsupported)
        // fall back to a one-shot read.
        var ax = _lastAx;
        var ay = _lastAy;
        if (ax == null || ay == null) {
            try {
                var info = Sensor.getInfo();
                if (info != null && info.accel != null
                    && info.accel.size() >= 2) {
                    ax = info.accel[0];
                    ay = info.accel[1];
                }
            } catch (e) {}
        }
        if (ax == null) { ax = 0; }
        if (ay == null) { ay = 0; }
        ctrl.tick(ax, ay);
        WatchUi.requestUpdate();
    }

    function onUpdate(dc) {
        UIManager.draw(dc, ctrl);
    }

    // ── Bridge methods called by InputHandler. ───────────────
    function navUp()      { ctrl.handleNav(-1); }
    function navDown()    { ctrl.handleNav(+1); }
    function navSelect()  { ctrl.handleNav(0); }
    function navBack()    { return ctrl.handleBack(); }
    function handleTap(x, y) { ctrl.handleTap(x, y); }
}
