using Toybox.WatchUi;
using Toybox.Sensor;

class BallDelegate extends WatchUi.BehaviorDelegate {

    hidden var _view;
    hidden var _shakeThreshold;
    hidden var _lastMag;
    hidden var _sensorEnabled;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
        _shakeThreshold = 2500;
        _lastMag = 0;
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
        if (!(sensorInfo has :accel) || sensorInfo.accel == null) { return; }
        var accel = sensorInfo.accel;
        if (accel.size() < 3) { return; }

        var x = accel[0];
        var y = accel[1];
        var z = accel[2];
        var mag = x * x + y * y + z * z;

        if (_lastMag > 0) {
            var diff = mag - _lastMag;
            if (diff < 0) { diff = -diff; }
            if (diff > _shakeThreshold * _shakeThreshold) {
                _view.shake();
                WatchUi.requestUpdate();
            }
        }
        _lastMag = mag;
    }

    function onSelect() {
        _view.shake();
        WatchUi.requestUpdate();
        return true;
    }

    function onMenu() {
        _view.shake();
        WatchUi.requestUpdate();
        return true;
    }

    function onPreviousPage() {
        _view.shake();
        WatchUi.requestUpdate();
        return true;
    }

    function onNextPage() {
        _view.shake();
        WatchUi.requestUpdate();
        return true;
    }

    function onBack() {
        if (_sensorEnabled && Toybox has :Sensor) {
            Sensor.enableSensorEvents(null);
        }
        return false;
    }
}
