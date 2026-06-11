using Toybox.WatchUi;
using Toybox.Sensor;

// ─────────────────────────────────────────────────────────────────────────────
//  BitochiMoonDelegate — input + accelerometer routing
//
//  Any button press / tap  → main thruster (upward boost)
//  Tilt left / right       → side thrusters via accelerometer X-axis
//  BACK                    → exit (stops sensor)
// ─────────────────────────────────────────────────────────────────────────────

class BitochiMoonDelegate extends WatchUi.BehaviorDelegate {

    hidden var _view;
    hidden var _sensorEnabled;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
        _sensorEnabled = false;
        enableAccel();
    }

    hidden function enableAccel() {
        if (Toybox has :Sensor) {
            if (Sensor has :enableSensorEvents) {
                try {
                    Sensor.enableSensorEvents(method(:onSensor));
                    _sensorEnabled = true;
                } catch (e) {
                    _sensorEnabled = false;
                }
            }
        }
    }

    function onSensor(sensorInfo as Sensor.Info) as Void {
        if (sensorInfo == null) { return; }
        var accel = sensorInfo.accel;
        if (accel == null) { return; }
        _view.accelX = accel[0];
        _view.accelY = accel[1];
        _view.accelZ = accel[2];
    }

    // In the menu, SELECT activates the highlighted row; in play it fires the
    // main thruster (or advances win/crash result screens).
    function onSelect() {
        _view.doAction();
        WatchUi.requestUpdate();
        return true;
    }

    // Physical MENU button → open the leaderboard directly from the menu.
    function onMenu() {
        if (_view.isMenu()) {
            _view.openLeaderboard();
        } else {
            _view.doAction();
        }
        WatchUi.requestUpdate();
        return true;
    }

    // UP/DOWN move the menu selection; in play they also fire the thruster.
    function onPreviousPage() {
        if (_view.isMenu()) {
            _view.menuMove(-1);
        } else {
            _view.doAction();
        }
        WatchUi.requestUpdate();
        return true;
    }

    function onNextPage() {
        if (_view.isMenu()) {
            _view.menuMove(1);
        } else {
            _view.doAction();
        }
        WatchUi.requestUpdate();
        return true;
    }

    // Touch: in the menu, route taps to the LEADERBOARD row or launch the game;
    // in play, any tap fires the main thruster.
    function onTap(evt) {
        if (_view.isMenu()) {
            var c = evt.getCoordinates();
            _view.handleMenuTap(c[0], c[1]);
        } else {
            _view.doAction();
        }
        WatchUi.requestUpdate();
        return true;
    }

    function onBack() {
        if (_sensorEnabled) {
            Sensor.enableSensorEvents(null);
        }
        return false;
    }
}
