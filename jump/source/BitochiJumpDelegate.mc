using Toybox.WatchUi;
using Toybox.Sensor;

class BitochiJumpDelegate extends WatchUi.BehaviorDelegate {

    hidden var _view;
    hidden var _sensorEnabled;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
        _sensorEnabled = false;
        if (Toybox has :Sensor && Sensor has :enableSensorEvents) {
            try {
                Sensor.enableSensorEvents(method(:onSensor));
                _sensorEnabled = true;
            } catch (e) {}
        }
    }

    function onSensor(sensorInfo as Sensor.Info) as Void {
        if (sensorInfo == null) { return; }
        var accel = sensorInfo.accel;
        if (accel == null) { return; }
        _view.accelX = accel[0];
        _view.accelY = accel[1];
    }

    function onSelect() { _view.doAction(); WatchUi.requestUpdate(); return true; }
    function onMenu() { _view.doAction(); WatchUi.requestUpdate(); return true; }

    function onPreviousPage() {
        if (_view.gameState == JS_MENU) {
            _view.cycleJumper(-1);
        } else {
            _view.doAction();
        }
        WatchUi.requestUpdate();
        return true;
    }

    function onNextPage() {
        if (_view.gameState == JS_MENU) {
            _view.cycleJumper(1);
        } else {
            _view.doAction();
        }
        WatchUi.requestUpdate();
        return true;
    }

    function onBack() {
        if (_sensorEnabled) { Sensor.enableSensorEvents(null); }
        return false;
    }
}
