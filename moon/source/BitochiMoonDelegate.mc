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

    // All buttons fire main thruster (or menu action)
    function onSelect() {
        _view.doAction();
        WatchUi.requestUpdate();
        return true;
    }

    function onMenu() {
        _view.doAction();
        WatchUi.requestUpdate();
        return true;
    }

    function onPreviousPage() {
        _view.doAction();
        WatchUi.requestUpdate();
        return true;
    }

    function onNextPage() {
        _view.doAction();
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
