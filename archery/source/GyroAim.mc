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
        var dx = ax - _calX;
        var dy = ay - _calY;
        if (dx > -30 && dx < 30) { dx = 0; }
        if (dy > -30 && dy < 30) { dy = 0; }

        // Scale (rad / milli-g).
        // Reduced from earlier values — the original felt too twitchy on
        // a typical wrist motion. HIGH now matches the old NORMAL so users
        // who prefer the snappier feel can still select it.
        var sc;
        if      (_sens == AR_SENS_LOW)  { sc = 0.0032; }
        else if (_sens == AR_SENS_HIGH) { sc = 0.0062; }
        else                             { sc = 0.0045; }
        var ty =  dx.toFloat() * sc;
        var tp = -dy.toFloat() * sc;

        // Wrists rotate backward (look-DOWN) less comfortably than
        // forward, so amplify the down half of pitch past a small
        // dead zone.  Small tilts still give fine control near the
        // horizon; larger tilts reach further below.
        if (tp > 0.15) { tp = 0.15 + (tp - 0.15) * 1.7; }

        // Asymmetric clamp: more room looking DOWN so enemies on
        // the ground are always reachable.
        var limU = 1.2;
        var limD = 1.8;
        if (ty >  1.4) { ty =  1.4; }
        if (ty < -1.4) { ty = -1.4; }
        if (tp >  limD) { tp =  limD; }
        if (tp < -limU) { tp = -limU; }

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

    hidden function _randf() {
        _rng = (_rng * 1103515245 + 12345) & 0x7FFFFFFF;
        return (_rng % 10000).toFloat() * 0.0001;
    }
}
