using Toybox.WatchUi;
using Toybox.Sensor;

class BitochiBlocksDelegate extends WatchUi.BehaviorDelegate {

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
    }

    // SELECT — rotate piece (main action)
    function onSelect() {
        _view.doRotate();
        WatchUi.requestUpdate();
        return true;
    }

    // MENU — hard drop
    function onMenu() {
        _view.doHardDrop();
        WatchUi.requestUpdate();
        return true;
    }

    // UP — rotate
    function onPreviousPage() {
        _view.doRotate();
        WatchUi.requestUpdate();
        return true;
    }

    // DOWN — soft drop (speed up fall)
    function onNextPage() {
        _view.doSoftDrop();
        WatchUi.requestUpdate();
        return true;
    }

    function onBack() {
        if (_view.isPlaying()) {
            _view.doAction();
            WatchUi.requestUpdate();
            return true;
        }
        if (_sensorEnabled) { Sensor.enableSensorEvents(null); }
        return false;
    }
}
