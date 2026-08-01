using Toybox.WatchUi;
using Toybox.Sensor;
using Toybox.System;

class BitochiBlobsDelegate extends WatchUi.BehaviorDelegate {

    hidden var _view;
    hidden var _sensorEnabled;

    // Phantom-back: right-edge flicks on Garmin touch panels fire onBack
    // (often BEFORE onSwipe, or with only onDrag). Mark every touch at
    // DRAG_TYPE_START / tap / swipe and swallow onBack for a short window.
    hidden var _lastGestureMs;
    hidden var _dragX;
    hidden var _dragY;
    hidden var _dragging;
    hidden var _hoppedThisDrag;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
        _sensorEnabled = false;
        _lastGestureMs = 0;
        _dragX = 0; _dragY = 0;
        _dragging = false;
        _hoppedThisDrag = false;
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

    hidden function _markGesture() {
        _lastGestureMs = System.getTimer();
    }

    hidden function _isPhantomBack() {
        if (_lastGestureMs == 0) { return false; }
        var dt = System.getTimer() - _lastGestureMs;
        // Wide window: edge-swipe onBack can lag the finger lift by a bit.
        return (dt >= 0 && dt < 800);
    }

    function onSensor(sensorInfo as Sensor.Info) as Void {
        if (sensorInfo == null) { return; }
        var accel = sensorInfo.accel;
        if (accel == null) { return; }
        _view.accelX = accel[0];
    }

    function onSelect() { _view.doAction(); WatchUi.requestUpdate(); return true; }
    function onMenu() { _view.doAction(); WatchUi.requestUpdate(); return true; }
    function onPreviousPage() { _view.doWeapon(-1); WatchUi.requestUpdate(); return true; }
    function onNextPage() { _view.doWeapon(1); WatchUi.requestUpdate(); return true; }

    function onKey(evt) {
        var k = evt.getKey();
        // Physical ESC / bottom-right on button watches — real exit.
        if (k == WatchUi.KEY_ESC) { return onBack(); }
        return false;
    }

    function onTap(evt) {
        _markGesture();
        return true;
    }

    // Primary hop path — more reliable than native onSwipe on many devices.
    function onDrag(evt) {
        _markGesture();   // CRITICAL: arm phantom-back BEFORE any onBack echo
        var t = evt.getType();
        var xy = evt.getCoordinates();
        if (xy == null) { return true; }

        if (t == WatchUi.DRAG_TYPE_START) {
            _dragging = true;
            _hoppedThisDrag = false;
            _dragX = xy[0];
            _dragY = xy[1];
            return true;
        }

        if (t == WatchUi.DRAG_TYPE_CONTINUE) {
            if (!_dragging || _hoppedThisDrag) { return true; }
            // Commit hop as soon as travel is clearly horizontal — don't wait
            // for STOP (some firmwares pair STOP with a late onBack).
            _tryDragHop(xy[0] - _dragX, xy[1] - _dragY);
            return true;
        }

        if (t == WatchUi.DRAG_TYPE_STOP) {
            if (_dragging && !_hoppedThisDrag) {
                _tryDragHop(xy[0] - _dragX, xy[1] - _dragY);
            }
            _dragging = false;
            _markGesture();
            return true;
        }
        return true;
    }

    hidden function _tryDragHop(dx, dy) {
        var adx = (dx < 0) ? -dx : dx;
        var ady = (dy < 0) ? -dy : dy;
        // Need a clear horizontal flick (~22 px).
        if (adx < 22 || adx < ady) { return; }
        _hoppedThisDrag = true;
        if (dx > 0) { _view.tryHop(1); }
        else        { _view.tryHop(-1); }
        WatchUi.requestUpdate();
    }

    function onSwipe(evt) {
        _markGesture();
        // If drag already hopped this flick, ignore the trailing onSwipe echo.
        if (_hoppedThisDrag) { return true; }
        var d = evt.getDirection();
        if (d == WatchUi.SWIPE_LEFT) {
            if (_view.tryHop(-1)) { WatchUi.requestUpdate(); }
        } else if (d == WatchUi.SWIPE_RIGHT) {
            if (_view.tryHop(1)) { WatchUi.requestUpdate(); }
        }
        return true;   // always consume — never let swipe bubble to onBack
    }

    function onBack() {
        // Swallow touch-panel phantom BACK (right-edge swipe / drag).
        // Real exit = physical bottom-right / KEY_ESC with no recent touch.
        if (_isPhantomBack()) {
            _lastGestureMs = 0;
            return true;
        }
        return SaveResume.confirmExit("blobs", _view.method(:exportSave));
    }
}
