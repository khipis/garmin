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

    function onSelect() {
        if (_view.inMenu()) { _view.menuActivate(); } else { _view.doAction(); }
        WatchUi.requestUpdate(); return true;
    }
    function onMenu() {
        if (_view.inMenu()) { _view.menuActivate(); } else { _view.doAction(); }
        WatchUi.requestUpdate(); return true;
    }
    function onPreviousPage() {
        if (_view.inMenu()) { _view.menuPrev(); } else { _view.doAction(); }
        WatchUi.requestUpdate(); return true;
    }
    function onNextPage() {
        if (_view.inMenu()) { _view.menuNext(); } else { _view.doAction(); }
        WatchUi.requestUpdate(); return true;
    }

    function onKey(evt) {
        if (_view.inMenu()) {
            var k = evt.getKey();
            if      (k == WatchUi.KEY_UP)   { _view.menuPrev(); }
            else if (k == WatchUi.KEY_DOWN) { _view.menuNext(); }
            else                            { _view.menuActivate(); }
            WatchUi.requestUpdate(); return true;
        }
        return false;
    }

    function onTap(evt) {
        if (_view.inMenu()) {
            var c = evt.getCoordinates();
            _view.handleMenuTap(c[0], c[1]);
        } else {
            _view.doAction();
        }
        WatchUi.requestUpdate(); return true;
    }

    function onBack() {
        if (_sensorOn) { Sensor.enableSensorEvents(null); }
        return false;
    }
}
