// ═══════════════════════════════════════════════════════════════
// GyroInput.mc — Wrist accelerometer → smoothed tilt vector.
//
// On the first frame after a calibrate() we capture the resting
// accel reading.  Subsequent frames feed (ax - cal, ay - cal) into
// a tilt vector that the PhysicsSystem turns into ball acceleration.
//
// Output:
//   tiltX  — positive when watch tilted RIGHT  (ball steers +x)
//   tiltY  — positive when watch tilted FORWARD (ball accelerates,
//                                                 ay is INVERTED so
//                                                 wrist-forward gives
//                                                 a positive number)
//
// Both are unit-less (≈ ±1.0) and pre-clamped.
//
// Dead zone: ±35 mg around the calibrated rest.  Anything inside
// is treated as exactly zero so the ball doesn't drift on a
// motionless wrist.
// ═══════════════════════════════════════════════════════════════

class GyroInput {

    var tiltX;
    var tiltY;

    hidden var _calX;
    hidden var _calY;
    hidden var _cal;
    hidden var _sens;

    function initialize() {
        tiltX = 0.0;
        tiltY = 0.0;
        _calX = 0;
        _calY = 0;
        _cal  = false;
        _sens = SR_SENS_NORMAL;
    }

    function setSensitivity(s) { _sens = s; }
    function recalibrate()     { _cal = false; }
    function isCalibrated()    { return _cal; }

    // ax, ay : raw milli-g from Sensor.getInfo().accel.
    function feed(ax, ay) {
        if (!_cal) { _calX = ax; _calY = ay; _cal = true; }
        var sc;
        if      (_sens == SR_SENS_LOW)  { sc = 0.0024; }
        else if (_sens == SR_SENS_HIGH) { sc = 0.0050; }
        else                             { sc = 0.0036; }
        var dx = ax - _calX;
        var dy = ay - _calY;
        if (dx > -35 && dx < 35) { dx = 0; }
        if (dy > -35 && dy < 35) { dy = 0; }
        var tx =  dx.toFloat() * sc;
        var ty = -dy.toFloat() * sc;
        // Saturating clamp — past ~±1.2 the player has tipped the
        // watch so far the ball would be unrecoverably fast anyway.
        if (tx >  1.2) { tx =  1.2; } if (tx < -1.2) { tx = -1.2; }
        if (ty >  1.2) { ty =  1.2; } if (ty < -1.2) { ty = -1.2; }
        tiltX = tx;
        tiltY = ty;
    }
}
