// ═══════════════════════════════════════════════════════════════
// PhysicsSystem.mc — Ball motion.
//
// State (owned by the system, mutated each tick):
//   px, py     — world tile position (float)
//   vx, vy     — velocity (tiles / tick, float)
//
// Forces, applied each tick in order:
//   1. Constant forward push   (vy += SR_FWD_BASE × speedMul)
//   2. Pitch tilt acceleration (vy += tiltY × SR_FWD_TILT)
//   3. Side tilt acceleration  (vx += tiltX × SR_SIDE_ACC)
//   4. Friction                (vx *= FRIC_X, vy *= FRIC_Y)
//   5. Speed clamps            (|vx| ≤ MAX_VX, MIN_VY ≤ vy ≤ MAX_VY)
//   6. Integrate position      (px += vx, py += vy)
//
// "Always rolling": the floor of `vy` is MIN_VY so even a wrist
// tipped fully backward can only SLOW the ball, not stop it.  This
// is what makes the game an endless runner — you HAVE to navigate.
// ═══════════════════════════════════════════════════════════════

class PhysicsSystem {

    var px;
    var py;
    var vx;
    var vy;

    function initialize() {
        px = 0.0; py = 0.0;
        vx = 0.0; vy = 0.0;
    }

    function reset(startX, startY) {
        px = startX.toFloat();
        py = startY.toFloat();
        vx = 0.0;
        vy = 0.0;
    }

    // Apply an instantaneous impulse (used by boost tiles).
    function impulse(dvx, dvy) { vx = vx + dvx; vy = vy + dvy; }

    // tiltX, tiltY   : from GyroInput (≈ ±1.0)
    // speedMul       : from PathGenerator.speedMul()
    function tick(tiltX, tiltY, speedMul) {
        var fwdBase = (SR_FWD_BASE.toFloat() / 100.0) * speedMul;
        var fwdTilt =  SR_FWD_TILT.toFloat() / 100.0;
        var sideAcc =  SR_SIDE_ACC.toFloat() / 100.0;
        var fricX   =  SR_FRIC_X.toFloat()   / 100.0;
        var fricY   =  SR_FRIC_Y.toFloat()   / 100.0;
        var maxVX   =  SR_MAX_VX.toFloat()   / 100.0;
        var maxVY   = (SR_MAX_VY.toFloat()   / 100.0) * speedMul;
        var minVY   =  SR_MIN_VY.toFloat()   / 100.0;

        vy = vy + fwdBase;
        vy = vy + tiltY * fwdTilt;
        vx = vx + tiltX * sideAcc;
        vx = vx * fricX;
        vy = vy * fricY;

        if (vx >  maxVX) { vx =  maxVX; }
        if (vx < -maxVX) { vx = -maxVX; }
        if (vy >  maxVY) { vy =  maxVY; }
        if (vy <  minVY) { vy =  minVY; }

        px = px + vx;
        py = py + vy;
    }
}
