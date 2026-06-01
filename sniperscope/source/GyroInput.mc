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
// Asymmetric pitch clamping: tilting the wrist DOWN past the
// horizon is mechanically cramped — we amplify the down half
// past a small dead zone so the player can comfortably aim at
// targets near the ground without contorting the wrist.
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
        if      (_sens == SS_SENS_LOW)  { sc = 0.0024; }
        else if (_sens == SS_SENS_HIGH) { sc = 0.0058; }
        else                             { sc = 0.0040; }
        var dx = ax - _calX;
        var dy = ay - _calY;
        // Dead zone — ignore noise jitter under ~40 mg.
        if (dx > -40 && dx < 40) { dx = 0; }
        if (dy > -40 && dy < 40) { dy = 0; }
        var ty =  dx.toFloat() * sc;
        var tp = -dy.toFloat() * sc;

        // Asymmetric down-boost so the wrist can reach low targets.
        if (tp > 0.20) { tp = 0.20 + (tp - 0.20) * 1.75; }

        // Hard clamp to the world bounds — past the edge of the
        // scene there's nothing to see, no point letting gaze drift.
        var limU = SS_WORLD_PITCH * 0.75;
        var limD = SS_WORLD_PITCH * 1.10;
        var limY = SS_WORLD_YAW   * 1.00;
        if (ty >  limY) { ty =  limY; }
        if (ty < -limY) { ty = -limY; }
        if (tp >  limD) { tp =  limD; }
        if (tp < -limU) { tp = -limU; }

        tYaw   = ty;
        tPitch = tp;
    }
}
