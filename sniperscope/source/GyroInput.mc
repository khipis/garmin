// ═══════════════════════════════════════════════════════════════
// GyroInput.mc — Wrist accelerometer → calibrated tilt angles.
//
// Reads the watch accelerometer once per tick (called from
// MainView.onTick) and produces a smoothed target gaze that the
// AimSystem then low-pass-filters into the actual scope position.
//
// Calibration: on first read, the accel sample is captured as
// the resting baseline so the player can level the watch in
// their natural shooting stance.  `recalibrate()` re-arms this.
//
// Symmetric ease-out aiming: near the calibrated horizon the
// response is 1:1 for fine control, then past a small linear
// zone the travel is amplified equally in BOTH directions.  This
// is what lets the wrist swing the scope all the way DOWN (and
// up) with a small, comfortable tilt — and crucially it does not
// depend on the sign of the accelerometer axis, so "aim down"
// works on every device.  Earlier revisions boosted only one
// pitch half and clamped the other tighter, which (depending on
// axis polarity) made aiming down impossible.
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

    function initialize() {
        tYaw   = 0.0;
        tPitch = 0.0;
        _calX  = 0;
        _calY  = 0;
        _cal   = false;
        _sens  = SS_SENS_NORMAL;
    }

    function setSensitivity(s) { _sens = s; }
    function isCalibrated()    { return _cal; }
    function recalibrate()     { _cal = false; }

    // ax, ay : raw milli-g from Sensor.getInfo().accel.
    function feed(ax, ay) {
        if (!_cal) {
            _calX = ax; _calY = ay; _cal = true;
        }
        var sc;
        if      (_sens == SS_SENS_LOW)  { sc = 0.0026; }
        else if (_sens == SS_SENS_HIGH) { sc = 0.0060; }
        else                             { sc = 0.0042; }
        var dx = ax - _calX;
        var dy = ay - _calY;
        // Small dead zone with a SMOOTH edge (subtract the zone instead of
        // snapping to zero) so the scope eases in with no jump — key to the
        // fluid tracking feel. ~18 mg is enough to reject resting jitter.
        var DZ = 18;
        if (dx > -DZ && dx < DZ) { dx = 0; } else { dx = (dx > 0) ? dx - DZ : dx + DZ; }
        if (dy > -DZ && dy < DZ) { dy = 0; } else { dy = (dy > 0) ? dy - DZ : dy + DZ; }
        var ty =  dx.toFloat() * sc;
        // Pitch gets a higher gain than yaw: the comfortable vertical wrist
        // range is smaller, so a natural tilt must be enough to swing the
        // scope all the way down onto ground-level hostiles.
        //
        // SIGN: this is the WORLD-MOVES / reticle-centred model, where a low
        // hostile (pitch > 0, sitting below centre) is brought up to the fixed
        // reticle by a POSITIVE gazePitch. Archery is the opposite model (the
        // reticle itself moves, needing a negative aimPitch to go down), so it
        // uses -dy. Here we must use +dy: tilting the wrist DOWN then raises
        // gazePitch and the low targets rise to the crosshair — i.e. "aim down"
        // finally works. The previous -dy inverted this and made down aiming
        // impossible no matter how the target band was tuned.
        var tp = dy.toFloat() * sc * 1.6;

        // Symmetric ease-out amplification: precise near the horizon,
        // easy to swing to the extremes in EITHER direction. Applied
        // identically to up/down (and left/right) so no direction is
        // privileged and aiming down is always reachable.
        ty = _amplify(ty);
        tp = _amplify(tp);

        // Symmetric, generous clamp — both directions reach comfortably
        // past the target band so no hostile is ever out of reach.
        var limP = SS_WORLD_PITCH * 1.15;
        var limY = SS_WORLD_YAW   * 1.05;
        if (ty >  limY) { ty =  limY; }
        if (ty < -limY) { ty = -limY; }
        if (tp >  limP) { tp =  limP; }
        if (tp < -limP) { tp = -limP; }

        tYaw   = ty;
        tPitch = tp;
    }

    // Ease-out response curve, symmetric about the calibrated centre:
    // a small linear zone for fine aim, then the excess travel past it
    // is scaled up so the scope reaches the field edges without the
    // wrist having to contort. Sign-agnostic → up and down feel equal.
    hidden function _amplify(v) {
        var lin = 0.15;   // 1:1 fine-control zone (radians)
        var k   = 2.0;    // amplification of travel beyond the linear zone
        if (v >  lin) { return  lin + (v - lin) * k; }
        if (v < -lin) { return -lin + (v + lin) * k; }
        return v;
    }
}
