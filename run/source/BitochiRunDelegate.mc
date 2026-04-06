using Toybox.WatchUi;
using Toybox.Sensor;

class BitochiRunDelegate extends WatchUi.BehaviorDelegate {

    hidden var _view;
    hidden var _sensorEnabled;
    hidden var _lastMag;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
        _sensorEnabled = false;
        _lastMag = 0;
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

        var ax = accel[0];
        var ay = accel[1];
        var az = accel[2];

        _view.accelX = ax;
        _view.accelY = ay;
        _view.accelZ = az;

        var mag = ax * ax + ay * ay + az * az;
        if (_lastMag > 0) {
            var diff = mag - _lastMag;
            if (diff < 0) { diff = -diff; }
            _view.shakeMag = diff;
        }
        _lastMag = mag;
    }

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
        if (_view.inRunPhase()) {
            _view.nudgeDodge(-1);
        } else {
            _view.doAction();
        }
        WatchUi.requestUpdate();
        return true;
    }

    function onNextPage() {
        if (_view.inRunPhase()) {
            _view.nudgeDodge(1);
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
