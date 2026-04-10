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

    // SELECT — start game (from menu/over) OR rotate piece (during play)
    function onSelect() {
        _view.doAction();
        WatchUi.requestUpdate();
        return true;
    }

    // MENU — start game (from menu/over) OR hard drop (during play)
    function onMenu() {
        if (_view.isPlaying()) {
            _view.doHardDrop();
        } else {
            _view.doAction();
        }
        WatchUi.requestUpdate();
        return true;
    }

    // UP — rotate piece during play
    function onPreviousPage() {
        _view.doRotate();
        WatchUi.requestUpdate();
        return true;
    }

    // DOWN — soft drop during play
    function onNextPage() {
        _view.doSoftDrop();
        WatchUi.requestUpdate();
        return true;
    }

    function onBack() {
        if (_view.isPlaying()) {
            // BACK during play → go back to menu
            _view.doBack();
            WatchUi.requestUpdate();
            return true;
        }
        if (_sensorEnabled) { Sensor.enableSensorEvents(null); }
        return false;
    }
}
