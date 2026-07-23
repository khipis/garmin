using Toybox.WatchUi;
using Toybox.Sensor;

class BitochiBombDelegate extends WatchUi.BehaviorDelegate {

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
        _view.navigate(-1);
        WatchUi.requestUpdate();
        return true;
    }

    function onNextPage() {
        _view.navigate(1);
        WatchUi.requestUpdate();
        return true;
    }

    // Touch devices: tap drops the current weapon (or confirms menus); swipe
    // up/down cycles the loadout so the whole arsenal is reachable without
    // physical UP/DOWN keys.
    function onTap(evt) {
        _view.doAction();
        WatchUi.requestUpdate();
        return true;
    }

    function onSwipe(evt) {
        var d = evt.getDirection();
        if (d == WatchUi.SWIPE_UP) { _view.navigate(-1); }
        else if (d == WatchUi.SWIPE_DOWN) { _view.navigate(1); }
        else { return true; }
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
