using Toybox.WatchUi;
using Toybox.Sensor;

class BitochiSkywalkerDelegate extends WatchUi.BehaviorDelegate {

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
    }

    function onSelect() {
        _view.doShoot();
        WatchUi.requestUpdate();
        return true;
    }

    function onMenu() {
        _view.doShoot();
        WatchUi.requestUpdate();
        return true;
    }

    function onPreviousPage() {
        _view.doShoot();
        WatchUi.requestUpdate();
        return true;
    }

    function onNextPage() {
        _view.doShoot();
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
