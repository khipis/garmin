using Toybox.WatchUi;
using Toybox.Sensor;

class BitochiBoxingDelegate extends WatchUi.BehaviorDelegate {
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
        _view.accelZ = a[2];
    }

    function onSelect() {
        if (_view.gameState == GS_MENU) { _view.menuActivate(); WatchUi.requestUpdate(); return true; }
        _view.doAction(); WatchUi.requestUpdate(); return true;
    }
    function onMenu() {
        if (_view.gameState == GS_MENU) { _view.menuActivate(); WatchUi.requestUpdate(); return true; }
        _view.doAction(); WatchUi.requestUpdate(); return true;
    }
    function onPreviousPage() {
        if (_view.gameState == GS_MENU) { _view.menuNav(-1); WatchUi.requestUpdate(); return true; }
        _view.doAction(); WatchUi.requestUpdate(); return true;
    }
    function onNextPage() {
        if (_view.gameState == GS_MENU) { _view.menuNav(1); WatchUi.requestUpdate(); return true; }
        _view.doAction(); WatchUi.requestUpdate(); return true;
    }

    function onTap(evt) {
        if (_view.gameState == GS_MENU) {
            var c = evt.getCoordinates();
            _view.handleMenuTap(c[0], c[1]);
            WatchUi.requestUpdate();
            return true;
        }
        _view.doAction(); WatchUi.requestUpdate(); return true;
    }

    function onBack() {
        if (_sensorOn) { Sensor.enableSensorEvents(null); }
        return false;
    }
}
