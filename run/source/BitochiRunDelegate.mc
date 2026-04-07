using Toybox.WatchUi;
using Toybox.Sensor;

class BitochiRunDelegate extends WatchUi.BehaviorDelegate {

    hidden var _view;
    hidden var _sensorEnabled;
    hidden var _lastMag;
    hidden var _lastAx;
    hidden var _lastAy;
    hidden var _lastAz;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
        _sensorEnabled = false;
        _lastMag = 0;
        _lastAx = 0; _lastAy = 0; _lastAz = 0;
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

        var dax = ax - _lastAx;
        var day = ay - _lastAy;
        var daz = az - _lastAz;
        if (dax < 0) { dax = -dax; }
        if (day < 0) { day = -day; }
        if (daz < 0) { daz = -daz; }
        var diff = dax + day + daz;
        _view.shakeMag = diff;
        _lastAx = ax; _lastAy = ay; _lastAz = az;
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
