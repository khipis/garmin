// ═══════════════════════════════════════════════════════════════
// GyroInput.mc — Accelerometer reading + calibration for tilt-steer.
//
// Garmin accelerometers report gravity components in milli-g.
// On a flat wrist: accel[0] ≈ 0 (X), accel[1] ≈ 0 (Y), accel[2]
// ≈ -1000 (Z, pointing away from screen). We only need the Y axis
// here — tilting the top of the watch away from you changes accel[1],
// which we map to vertical paddle motion.
//
// Calibration: capture the current resting Y as "neutral" and
// subtract it from every reading so the paddle sits still when the
// wrist is held at whatever angle the match started from.
// ═══════════════════════════════════════════════════════════════

using Toybox.Sensor;

class GyroInput {
    var calibY;
    var available;

    function initialize() {
        calibY    = 0;
        available = false;
        calibrate();
    }

    // Snapshot the current tilt as the new neutral position.
    function calibrate() {
        var info = Sensor.getInfo();
        if (info == null) { return; }
        try {
            var a = info.accel;
            if (a != null) {
                calibY    = a[1];
                available = true;
            }
        } catch (e) {}
    }

    // Calibrated Y tilt in milli-g (0 at the neutral resting angle).
    // Returns 0 when no accelerometer is present.
    function readY() {
        var info = Sensor.getInfo();
        if (info == null) { return 0; }
        try {
            var a = info.accel;
            if (a != null) {
                available = true;
                return a[1] - calibY;
            }
        } catch (e) {}
        return 0;
    }

    // True once we've seen a real accelerometer reading.
    function isAvailable() { return available; }
}
