using Toybox.WatchUi;
using Toybox.Sensor;

class BitochiParachuteDelegate extends WatchUi.BehaviorDelegate {

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
        _view.accelZ = accel[2];
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

    function onTap(evt) {
        if (_view.gameState == PS_MENU && _view.tapInLbRow(evt.getCoordinates())) {
            _view.openLeaderboard();
            return true;
        }
        _view.doAction();
        WatchUi.requestUpdate();
        return true;
    }

    function onPreviousPage() {
        if (_view.gameState == PS_MENU) { _view.menuMove(-1); }
        else { _view.doAction(); }
        WatchUi.requestUpdate();
        return true;
    }

    function onNextPage() {
        if (_view.gameState == PS_MENU) { _view.menuMove(1); }
        else { _view.doAction(); }
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
