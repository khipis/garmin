// ═══════════════════════════════════════════════════════════════
// GyroInput.mc — Accelerometer reading + calibration.
//
// Garmin accelerometers report gravity components in milli-g.
// On a flat wrist: accel[0] ≈ 0 (X), accel[1] ≈ 0 (Y), accel[2]
// ≈ -1000 (Z, pointing away from screen). When the user tilts:
//   tilt right  → accel[0] increases (ball should go right)
//   tilt toward body (top away) → accel[1] decreases
//
// Calibration: read initial X/Y as "neutral" and subtract every
// subsequent reading so the resting position is always (0,0).
// ═══════════════════════════════════════════════════════════════

using Toybox.Sensor;

class GyroInput {
    var calibX;
    var calibY;

    function initialize() {
        calibX = 0;
        calibY = 0;
        calibrate();
    }

    function calibrate() {
        var info = Sensor.getInfo();
        if (info == null) { return; }
        try {
            var a = info.accel;
            if (a != null) {
                calibX = a[0];
                calibY = a[1];
            }
        } catch (e) {}
    }

    // Returns [ax, ay] in calibrated milli-g.
    // Returns [0, 0] when the sensor is unavailable.
    function read() {
        var info = Sensor.getInfo();
        if (info == null) { return [0, 0]; }
        try {
            var a = info.accel;
            if (a != null) {
                return [a[0] - calibX, a[1] - calibY];
            }
        } catch (e) {}
        return [0, 0];
    }
}
