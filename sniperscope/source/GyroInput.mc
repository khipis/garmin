// ═══════════════════════════════════════════════════════════════
// GyroInput.mc — Wrist accelerometer → calibrated tilt angles.
//
// Reads the watch accelerometer once per tick (called from
// MainView.onTick) and produces a smoothed target gaze that the
// AimSystem then low-pass-filters into the actual scope position.
//
// Calibration: NEVER use a single first sample (that captures the
// tap / menu-hold pose and makes some hostiles unreachable). Wait
// for a short low-motion window, average several samples into the
// resting baseline, then unlock aiming. `recalibrate()` re-arms.
//
// Symmetric ease-out aiming: near the calibrated horizon the
// response is 1:1 for fine control, then past a small linear
// zone the travel is amplified equally in BOTH directions so
// "aim down" works on every device.
// ═══════════════════════════════════════════════════════════════

using Toybox.Math;

class GyroInput {

    // Output: target gaze (consumed by AimSystem each tick).
    var tYaw;
    var tPitch;

    hidden var _calX;
    hidden var _calY;
    hidden var _cal;
    hidden var _sens;     // SS_SENS_*

    // Settle-window state for stable baseline capture.
    hidden var _settleN;      // consecutive low-jitter samples so far
    hidden var _settleTries;  // total samples while waiting (timeout)
    hidden var _sumX;
    hidden var _sumY;
    hidden var _lastAx;
    hidden var _lastAy;
    hidden var _justCal;      // one-shot flag for AimSystem reset

    // ~12 * 60 ms ≈ 0.7 s of stillness; force-calibrate by ~2.4 s.
    const SETTLE_NEED   = 12;
    const SETTLE_MAX    = 40;
    const SETTLE_JITTER = 35;   // milli-g — restart settle if exceeded

    function initialize() {
        tYaw   = 0.0;
        tPitch = 0.0;
        _calX  = 0;
        _calY  = 0;
        _cal   = false;
        _sens  = SS_SENS_NORMAL;
        _settleN = 0; _settleTries = 0;
        _sumX = 0; _sumY = 0;
        _lastAx = 0; _lastAy = 0;
        _justCal = false;
    }

    function setSensitivity(s) { _sens = s; }
    function isCalibrated()    { return _cal; }
    // True exactly once after a successful (re)calibration settles.
    function consumeJustCalibrated() {
        if (!_justCal) { return false; }
        _justCal = false;
        return true;
    }

    function recalibrate() {
        _cal = false;
        _settleN = 0; _settleTries = 0;
        _sumX = 0; _sumY = 0;
        _justCal = false;
        tYaw = 0.0; tPitch = 0.0;
    }

    // ax, ay : raw milli-g from Sensor.getInfo().accel.
    function feed(ax, ay) {
        if (!_cal) {
            _feedSettle(ax, ay);
            tYaw = 0.0;
            tPitch = 0.0;
            return;
        }
        var sc;
        if      (_sens == SS_SENS_LOW)  { sc = 0.0028; }
        else if (_sens == SS_SENS_HIGH) { sc = 0.0060; }
        else                             { sc = 0.0044; }
        var dx = ax - _calX;
        var dy = ay - _calY;
        // Small dead zone with a SMOOTH edge (subtract the zone instead of
        // snapping to zero) so the scope eases in with no jump — key to the
        // fluid tracking feel. ~16 mg is enough to reject resting jitter.
        var DZ = 16;
        if (dx > -DZ && dx < DZ) { dx = 0; } else { dx = (dx > 0) ? dx - DZ : dx + DZ; }
        if (dy > -DZ && dy < DZ) { dy = 0; } else { dy = (dy > 0) ? dy - DZ : dy + DZ; }
        var ty =  dx.toFloat() * sc;
        // Pitch gets a higher gain than yaw: the comfortable vertical wrist
        // range is smaller, so a natural tilt must swing the scope onto
        // ground-level hostiles without wrist contortion.
        //
        // SIGN: WORLD-MOVES / reticle-centred — a low hostile (pitch > 0)
        // is brought up to the fixed reticle by a POSITIVE gazePitch.
        // Tilting the wrist DOWN raises gazePitch → "aim down" works.
        var tp = dy.toFloat() * sc * 1.85;

        // Symmetric ease-out amplification: precise near the horizon,
        // easy to swing to the extremes in EITHER direction.
        ty = _amplify(ty);
        tp = _amplify(tp);

        // Symmetric clamp — both directions past the target band.
        var limP = SS_WORLD_PITCH * 1.15;
        var limY = SS_WORLD_YAW   * 1.05;
        if (ty >  limY) { ty =  limY; }
        if (ty < -limY) { ty = -limY; }
        if (tp >  limP) { tp =  limP; }
        if (tp < -limP) { tp = -limP; }

        tYaw   = ty;
        tPitch = tp;
    }

    hidden function _feedSettle(ax, ay) {
        _settleTries++;
        if (_settleN > 0) {
            var jx = ax - _lastAx; if (jx < 0) { jx = -jx; }
            var jy = ay - _lastAy; if (jy < 0) { jy = -jy; }
            if (jx > SETTLE_JITTER || jy > SETTLE_JITTER) {
                // Still moving — restart the stillness window, keep trying.
                _settleN = 0;
                _sumX = 0; _sumY = 0;
            }
        }
        _lastAx = ax; _lastAy = ay;
        _sumX = _sumX + ax;
        _sumY = _sumY + ay;
        _settleN++;

        if (_settleN >= SETTLE_NEED || _settleTries >= SETTLE_MAX) {
            var n = _settleN;
            if (n < 1) { n = 1; }
            _calX = _sumX / n;
            _calY = _sumY / n;
            _cal = true;
            _justCal = true;
        }
    }

    // Ease-out response curve, symmetric about the calibrated centre.
    hidden function _amplify(v) {
        var lin = 0.12;   // 1:1 fine-control zone (radians)
        var k   = 2.2;    // amplification beyond the linear zone
        if (v >  lin) { return  lin + (v - lin) * k; }
        if (v < -lin) { return -lin + (v + lin) * k; }
        return v;
    }
}
