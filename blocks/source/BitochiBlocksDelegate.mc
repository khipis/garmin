using Toybox.WatchUi;
using Toybox.Sensor;

class BitochiBlocksDelegate extends WatchUi.InputDelegate {

    hidden var _view;
    hidden var _sensorEnabled;

    function initialize(view) {
        InputDelegate.initialize();
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

    function onKey(evt) {
        var key = evt.getKey();
        if (key == WatchUi.KEY_ENTER) { _view.doAction();    WatchUi.requestUpdate(); return true; }
        if (key == WatchUi.KEY_UP) {
            if (_view.isMenu()) { _view.menuNav(-1); } else { _view.doMoveRight(); }
            WatchUi.requestUpdate(); return true;
        }
        if (key == WatchUi.KEY_DOWN) {
            if (_view.isMenu()) { _view.menuNav(1); } else { _view.doMoveLeft(); }
            WatchUi.requestUpdate(); return true;
        }
        if (key == WatchUi.KEY_MENU) {
            // Fallback: devices that don't fire onKeyPressed/Released use onKey (key-up)
            // for hard drop while playing; release clears soft-drop hold.
            _view.setSoftDropHeld(false);
            if (_view.isPlaying()) { _view.doHardDrop(); WatchUi.requestUpdate(); return true; }
            return false;
        }
        if (key == WatchUi.KEY_ESC) {
            // Back always returns to the shared root menu (framework pops us).
            // Release the accelerometer subscription on the way out.
            if (_sensorEnabled) { Sensor.enableSensorEvents(null); _sensorEnabled = false; }
            return false;
        }
        return false;
    }

    // Hold MENU button = soft drop (fast continuous fall, standard Tetris mechanic)
    function onKeyPressed(evt) {
        if (evt.getKey() == WatchUi.KEY_MENU && _view.isPlaying()) {
            _view.setSoftDropHeld(true);
            WatchUi.requestUpdate();
            return true;
        }
        return false;
    }

    function onKeyReleased(evt) {
        if (evt.getKey() == WatchUi.KEY_MENU) {
            _view.setSoftDropHeld(false);
            WatchUi.requestUpdate();
            return true;
        }
        return false;
    }

    function onSwipe(swipeEvent) {
        if (_view.isPlaying()) {
            var dir = swipeEvent.getDirection();
            if (dir == WatchUi.SWIPE_RIGHT) { _view.doMoveRight(); WatchUi.requestUpdate(); return true; }
            if (dir == WatchUi.SWIPE_LEFT)  { _view.doMoveLeft();  WatchUi.requestUpdate(); return true; }
            if (dir == WatchUi.SWIPE_DOWN)  { _view.doHardDrop();  WatchUi.requestUpdate(); return true; }
            if (dir == WatchUi.SWIPE_UP)    { _view.doRotate();    WatchUi.requestUpdate(); return true; }
        }
        return false;
    }

    function onTap(evt) {
        var xy = evt.getCoordinates();
        _view.doTap(xy[0], xy[1]);
        WatchUi.requestUpdate();
        return true;
    }
}
