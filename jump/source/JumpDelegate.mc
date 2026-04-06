using Toybox.WatchUi;
using Toybox.Sensor;

class JumpDelegate extends WatchUi.BehaviorDelegate {

    hidden var _view;
    hidden var _sensorEnabled;
    hidden var _lastMag;
    hidden var _shakeThreshold;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
        _sensorEnabled = false;
        _lastMag = 0;
        _shakeThreshold = 2500;
        enableAccel();
    }

    hidden function enableAccel() {
        if (Toybox has :Sensor) {
            if (Sensor has :enableSensorEvents) {
                try {
                    var opts = {};
                    if (Sensor has :SENSOR_ACCELEROMETER) {
                        opts.put(:enableAccelerometer, true);
                    }
                    Sensor.enableSensorEvents(method(:onSensor));
                    _sensorEnabled = true;
                } catch (e) {
                    _sensorEnabled = false;
                }
            }
        }
    }

    function onSensor(sensorInfo) {
        if (sensorInfo == null) { return; }
        var accel = sensorInfo.accel;
        if (accel == null) { return; }

        var ax = accel[0];
        var ay = accel[1];
        var az = accel[2];
        var mag = ax * ax + ay * ay + az * az;

        if (_lastMag > 0) {
            var diff = mag - _lastMag;
            if (diff < 0) { diff = -diff; }
            _view.accelMag = diff;

            if (_view.gameState == JS_TAKEOFF && diff > _shakeThreshold) {
                _view.executeTakeoff(true);
                WatchUi.requestUpdate();
            }

            if (_view.gameState == JS_FLIGHT) {
                if (az < -200) {
                    _view.setLean(1);
                } else if (az > 200) {
                    _view.setLean(-1);
                } else {
                    _view.setLean(0);
                }
            }
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
        if (_view.gameState == JS_SELECT) {
            _view.cycleJumper(-1);
        } else if (_view.gameState == JS_FLIGHT) {
            _view.setLean(1);
        } else {
            _view.doAction();
        }
        WatchUi.requestUpdate();
        return true;
    }

    function onNextPage() {
        if (_view.gameState == JS_SELECT) {
            _view.cycleJumper(1);
        } else if (_view.gameState == JS_FLIGHT) {
            _view.setLean(-1);
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
