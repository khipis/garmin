using Toybox.WatchUi;
using Toybox.Sensor;

class BitochiSerpentDelegate extends WatchUi.BehaviorDelegate {

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

    // SELECT / tap — turn right, or start/restart
    function onSelect() {
        _view.doAction();
        WatchUi.requestUpdate();
        return true;
    }

    // MENU button — turn left in-game
    function onMenu() {
        if (!_view.doBack()) { return false; }
        WatchUi.requestUpdate();
        return true;
    }

    // UP — turn left
    function onPreviousPage() {
        _view.doLeft();
        WatchUi.requestUpdate();
        return true;
    }

    // DOWN — turn right
    function onNextPage() {
        _view.doRight();
        WatchUi.requestUpdate();
        return true;
    }

    function onBack() {
        if (_view.isPlaying()) {
            _view.doBack();
            WatchUi.requestUpdate();
            return true;
        }
        if (_sensorEnabled) { Sensor.enableSensorEvents(null); }
        return false;
    }
}
