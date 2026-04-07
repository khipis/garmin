using Toybox.WatchUi;
using Toybox.Sensor;

class BitochiFishDelegate extends WatchUi.BehaviorDelegate {
    hidden var _view;
    hidden var _sensorOn;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
        _sensorOn = false;
        if (Toybox has :Sensor && Sensor has :enableSensorEvents) {
            try {
                Sensor.enableSensorEvents(method(:onSensor));
                _sensorOn = true;
            } catch (e) {}
        }
    }

    function onSensor(info as Sensor.Info) as Void {
        if (info == null) { return; }
        var a = info.accel;
        if (a == null) { return; }
        _view.accelX = a[0];
        _view.accelY = a[1];
    }

    function onSelect() { _view.doAction(); WatchUi.requestUpdate(); return true; }
    function onMenu() { _view.doAction(); WatchUi.requestUpdate(); return true; }
    function onPreviousPage() { _view.doAction(); WatchUi.requestUpdate(); return true; }
    function onNextPage() { _view.doAction(); WatchUi.requestUpdate(); return true; }

    function onBack() {
        if (_sensorOn) { Sensor.enableSensorEvents(null); }
        return false;
    }
}
