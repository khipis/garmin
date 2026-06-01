// ═══════════════════════════════════════════════════════════════
// AimSystem.mc — Low-pass-filtered gaze + breathing sway.
//
// Pipeline:
//
//   GyroInput.tYaw, .tPitch      (raw target from accelerometer)
//        ↓ low-pass filter (a)
//   _gazeYaw, _gazePitch         (smooth base gaze)
//        ↓ + breathing sway
//   aimYaw, aimPitch             (FINAL scope angle used by render
//                                  AND for shot ballistics)
//
// The filter coefficient `a` depends on the sensitivity preset so
// LOW = slow & cinematic, HIGH = snappy.
// ═══════════════════════════════════════════════════════════════

class AimSystem {

    var aimYaw;         // final scope direction (gaze + sway)
    var aimPitch;
    var gazeYaw;        // smoothed gaze (without sway) — used by
    var gazePitch;      //   BreathingSystem to detect "still"

    hidden var _sens;

    function initialize() {
        aimYaw     = 0.0;
        aimPitch   = 0.0;
        gazeYaw    = 0.0;
        gazePitch  = 0.0;
        _sens      = SS_SENS_NORMAL;
    }

    function setSensitivity(s) { _sens = s; }
    function reset() {
        aimYaw    = 0.0; aimPitch   = 0.0;
        gazeYaw   = 0.0; gazePitch  = 0.0;
    }

    // Called once per tick from GameController.
    //   tYaw, tPitch   — target gaze from GyroInput
    //   sYaw, sPitch   — sway from BreathingSystem
    function tick(tYaw, tPitch, sYaw, sPitch) {
        var a;
        if      (_sens == SS_SENS_LOW)  { a = 0.12; }
        else if (_sens == SS_SENS_HIGH) { a = 0.32; }
        else                             { a = 0.22; }
        gazeYaw   = gazeYaw   + (tYaw   - gazeYaw)   * a;
        gazePitch = gazePitch + (tPitch - gazePitch) * a;
        aimYaw    = gazeYaw   + sYaw;
        aimPitch  = gazePitch + sPitch;
    }
}
