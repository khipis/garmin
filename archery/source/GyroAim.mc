// ═══════════════════════════════════════════════════════════════
// GyroAim.mc — Calibrated, smoothed first-person aim.
//
// The Garmin accelerometer reports gravity in milli-g.  We turn it
// into two angular components used as the player's gaze:
//   ax (X)  →  +yaw   (look right when tilting watch right)
//   ay (Y)  →  −pitch (look up when tilting top-forward)
//
// On the first reading after calibration we capture (ax, ay) as
// the neutral baseline so the resting wrist is gaze (0, 0).
//
// Two layers of smoothing prevent jitter:
//   • Dead-zone (small tilts ignored)
//   • Low-pass: gaze = gaze + (target − gaze) * α
//
// While the bow is drawn we *intentionally* inject muscle tension:
//   a tiny noise vector pushes the aim around by a few px so a
//   long-held draw is harder to keep on target.
// ═══════════════════════════════════════════════════════════════

using Toybox.Sensor;
using Toybox.Math;

class GyroAim {
    var aimYaw;
    var aimPitch;

    hidden var _tYaw;
    hidden var _tPitch;
    hidden var _calX;
    hidden var _calY;
    hidden var _calibrated;
    hidden var _sens;
    hidden var _rng;

    function initialize() {
        aimYaw   = 0.0;
        aimPitch = 0.0;
        _tYaw    = 0.0;
        _tPitch  = 0.0;
        _calX    = 0;
        _calY    = 0;
        _calibrated = false;
        _sens    = AR_SENS_NORMAL;
        _rng     = 271828;
    }

    function setSensitivity(s) { _sens = s; }

    function recalibrate() { _calibrated = false; }

    // Called every game tick (after we've read the live accel).
    // tension: 0..1 — how strongly bow is drawn (0 = none, 1 = full).
    function update(ax, ay, tension) {
        if (!_calibrated) {
            _calX = ax; _calY = ay; _calibrated = true;
        }
        // Small dead zone with a SMOOTH edge (subtract the zone rather
        // than snapping to 0) so the aim eases in with no jump — this is
        // what makes fine tracking feel fluid instead of steppy.
        var DZ = 16;
        var dx = ax - _calX;
        var dy = ay - _calY;
        if (dx > -DZ && dx < DZ) { dx = 0; } else { dx = (dx > 0) ? dx - DZ : dx + DZ; }
        if (dy > -DZ && dy < DZ) { dy = 0; } else { dy = (dy > 0) ? dy - DZ : dy + DZ; }

        // Scale (rad / milli-g). Pitch gets a higher gain than yaw because
        // the comfortable wrist range in the vertical axis is smaller — so
        // enemies on the ground are reachable with a natural, small tilt.
        var sc;
        if      (_sens == AR_SENS_LOW)  { sc = 0.0034; }
        else if (_sens == AR_SENS_HIGH) { sc = 0.0068; }
        else                             { sc = 0.0050; }
        var ty =  dx.toFloat() * sc;
        var tp = -dy.toFloat() * sc * 1.7;   // vertical gain boost

        // SYMMETRIC ease-out: 1:1 near the horizon for fine control, then
        // amplify travel past a small linear zone EQUALLY up and down. No
        // direction is privileged, so "aim down" is exactly as reachable as
        // "aim up" regardless of the accelerometer axis polarity.
        ty = _ease(ty);
        tp = _ease(tp);

        // Symmetric, generous clamp — both directions reach well past the
        // enemy band so no target on the ground is ever out of reach.
        var lim = 1.6;
        if (ty >  1.4) { ty =  1.4; }
        if (ty < -1.4) { ty = -1.4; }
        if (tp >  lim) { tp =  lim; }
        if (tp < -lim) { tp = -lim; }

        // Bow tension jitter — only when actively drawing.
        if (tension > 0.0) {
            var amp = 0.004 + 0.014 * tension;
            ty = ty + (_randf() - 0.5) * amp;
            tp = tp + (_randf() - 0.5) * amp;
        }
        _tYaw   = ty;
        _tPitch = tp;

        // Smoothing — slightly tighter than before for more deliberate feel.
        var a;
        if      (_sens == AR_SENS_LOW)  { a = 0.14; }
        else if (_sens == AR_SENS_HIGH) { a = 0.26; }
        else                             { a = 0.20; }
        aimYaw   = aimYaw   + (_tYaw   - aimYaw)   * a;
        aimPitch = aimPitch + (_tPitch - aimPitch) * a;
    }

    // Symmetric ease-out response curve about the calibrated centre.
    hidden function _ease(v) {
        var lin = 0.16;   // 1:1 fine-control zone (radians)
        var k   = 1.8;    // amplification of travel beyond the linear zone
        if (v >  lin) { return  lin + (v - lin) * k; }
        if (v < -lin) { return -lin + (v + lin) * k; }
        return v;
    }

    hidden function _randf() {
        _rng = (_rng * 1103515245 + 12345) & 0x7FFFFFFF;
        return (_rng % 10000).toFloat() * 0.0001;
    }
}
