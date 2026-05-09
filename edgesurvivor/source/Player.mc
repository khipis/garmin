// Player — constrained to the edge circle, defined entirely by angle.
//
// Constants used (defined in GameView.mc):
//   PLAYER_MAX_VEL, DASH_DEGREES, DASH_COOLDOWN, TRAIL_LEN

class Player {
    var angle;       // integer degrees 0–359, position on the edge
    var vel;         // integer degrees/tick, signed
    var dashCd;      // cooldown ticks remaining
    var isDashing;   // positive = visual flash frames remaining

    var trailAngle;  // int[TRAIL_LEN] — previous positions (newest at [0])

    function initialize() {
        trailAngle = new [TRAIL_LEN];
        reset();
    }

    function reset() {
        angle    = 270;   // start at top of circle
        vel      = 0;
        dashCd   = 0;
        isDashing = 0;
        for (var i = 0; i < TRAIL_LEN; i++) { trailAngle[i] = 270; }
    }

    function update(keyRight, keyLeft) {
        // push current angle into trail (shift back)
        var t = TRAIL_LEN - 1;
        while (t > 0) {
            trailAngle[t] = trailAngle[t - 1];
            t = t - 1;
        }
        trailAngle[0] = angle;

        // angular acceleration with friction
        if (keyRight == 1) {
            vel = vel + 1;
            if (vel > PLAYER_MAX_VEL) { vel = PLAYER_MAX_VEL; }
        }
        if (keyLeft == 1) {
            vel = vel - 1;
            if (vel < -PLAYER_MAX_VEL) { vel = -PLAYER_MAX_VEL; }
        }
        if (keyRight == 0 && keyLeft == 0) {
            // linear friction — decelerate toward zero
            if (vel > 0) { vel = vel - 1; }
            else if (vel < 0) { vel = vel + 1; }
        }

        angle = (angle + vel + 360) % 360;

        if (dashCd   > 0) { dashCd   = dashCd   - 1; }
        if (isDashing > 0) { isDashing = isDashing - 1; }
    }

    function doDash() {
        if (dashCd > 0) { return; }
        // dash in the direction we're currently moving (or clockwise if still)
        var dir = (vel > 0) ? 1 : ((vel < 0) ? -1 : 1);
        angle    = (angle + dir * DASH_DEGREES + 360) % 360;
        dashCd   = DASH_COOLDOWN;
        isDashing = 10;
    }
}
