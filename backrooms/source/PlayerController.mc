// ═══════════════════════════════════════════════════════════════════════════
// PlayerController.mc — Position, camera and the feel of walking.
//
// Input is discrete (a swipe, a button press) but movement must not be: every
// input tops up a short throttle window and the controller eases velocity and
// turn rate toward their targets, so corridors glide instead of teleporting.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Math;
using Toybox.Lang;

class PlayerController {
    var x; var y; var ang;
    var dirX; var dirY; var planeX; var planeY;
    var vel; var avel;
    var throttle;      // frames of forward walk still owed
    var turnDir;       // -1 left, +1 right, 0 idle
    var turnFrames;
    var sprint;        // frames of panic sprint left
    var bob;           // walk cycle phase
    var bobY;          // current vertical camera offset in px
    var hasKey;
    var moved;         // cells walked this run (distance score)

    function initialize() {
        x = 1.5; y = 1.5; ang = 0.0;
        vel = 0.0; avel = 0.0;
        throttle = 0; turnDir = 0; turnFrames = 0; sprint = 0;
        bob = 0.0; bobY = 0; hasKey = false; moved = 0.0;
        _updateVectors();
    }

    function placeAt(cxx, cyy, a) {
        x = cxx + 0.5; y = cyy + 0.5; ang = a;
        vel = 0.0; avel = 0.0; throttle = 0; turnFrames = 0;
        _updateVectors();
    }

    function _updateVectors() {
        dirX = Math.cos(ang);
        dirY = Math.sin(ang);
        // Camera plane is the view vector rotated 90°, scaled to the FOV.
        planeX = -dirY * Br.FOV_PLANE;
        planeY =  dirX * Br.FOV_PLANE;
    }

    // ── Input intents ────────────────────────────────────────────────────────
    function pushForward() { throttle = Br.THROTTLE_F; }
    function pushTurn(d) { turnDir = d; turnFrames = 7; }
    function pushSprint() { sprint = Br.SPRINT_F; throttle = Br.SPRINT_F; }

    // ── Per-frame integration ────────────────────────────────────────────────
    function update(map) {
        // Turning: ease toward the requested rate, ease back to still.
        var tTarget = 0.0;
        if (turnFrames > 0) {
            turnFrames -= 1;
            tTarget = turnDir * Br.TURN_MAX;
        }
        if (avel < tTarget) {
            avel += Br.TURN_ACCEL;
            if (avel > tTarget) { avel = tTarget; }
        } else if (avel > tTarget) {
            avel -= Br.TURN_DECEL;
            if (avel < tTarget) { avel = tTarget; }
        }
        if (avel != 0.0) {
            ang += avel;
            if (ang > 6.2832) { ang -= 6.2832; }
            if (ang < 0.0) { ang += 6.2832; }
            _updateVectors();
        }

        // Walking: same easing, with a sprint multiplier while panicking.
        var vTarget = 0.0;
        if (throttle > 0) {
            throttle -= 1;
            vTarget = Br.MOVE_MAX;
            if (sprint > 0) {
                sprint -= 1;
                vTarget = Br.MOVE_MAX * Br.SPRINT_MULT / 100.0;
            }
        }
        if (vel < vTarget) {
            vel += Br.MOVE_ACCEL;
            if (vel > vTarget) { vel = vTarget; }
        } else if (vel > vTarget) {
            vel -= Br.MOVE_DECEL;
            if (vel < vTarget) { vel = vTarget; }
        }

        if (vel > 0.0005) {
            var nx = x + dirX * vel;
            var ny = y + dirY * vel;
            // Axes resolved separately so a glancing wall slides you along it.
            var okX = _free(map, nx, y);
            var okY = _free(map, x, ny);
            if (okX) { moved += (nx > x) ? (nx - x) : (x - nx); x = nx; }
            if (okY) { moved += (ny > y) ? (ny - y) : (y - ny); y = ny; }
            if (!okX && !okY) {
                // Face first into a corner: stop rather than grind.
                throttle = 0; vel = 0.0; sprint = 0;
            }
            bob += vel * 9.0;
            if (bob > 6.2832) { bob -= 6.2832; }
        } else {
            // Standing still still breathes.
            bob += 0.06;
            if (bob > 6.2832) { bob -= 6.2832; }
        }

        var amp = 2.0 + vel * 22.0;
        bobY = (Math.sin(bob) * amp).toNumber();
    }

    hidden function _free(map, fx, fy) {
        var r = Br.RADIUS / 100.0;
        if (map.isWall((fx - r).toNumber(), fy.toNumber())) { return false; }
        if (map.isWall((fx + r).toNumber(), fy.toNumber())) { return false; }
        if (map.isWall(fx.toNumber(), (fy - r).toNumber())) { return false; }
        if (map.isWall(fx.toNumber(), (fy + r).toNumber())) { return false; }
        return true;
    }

    function cellX() { return x.toNumber(); }
    function cellY() { return y.toNumber(); }

    // Squared distance to a cell centre — cheap comparisons, no sqrt.
    function dist2To(gx, gy) {
        var dx = (gx + 0.5) - x;
        var dy = (gy + 0.5) - y;
        return dx * dx + dy * dy;
    }

    // Is that cell inside the view cone? cosLimit 0.82 ≈ ±35°.
    function looksAt(gx, gy, cosLimit) {
        var dx = (gx + 0.5) - x;
        var dy = (gy + 0.5) - y;
        var len = Math.sqrt(dx * dx + dy * dy);
        if (len < 0.001) { return true; }
        var d = (dx * dirX + dy * dirY) / len;
        return d >= cosLimit;
    }

    // Compass letter for the HUD — orientation is the one thing you can keep.
    function facing() {
        var a = ang;
        if (a < 0.7854 || a >= 5.4978) { return "E"; }
        if (a < 2.3562) { return "S"; }
        if (a < 3.9270) { return "W"; }
        return "N";
    }
}
