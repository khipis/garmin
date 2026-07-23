// ═══════════════════════════════════════════════════════════════
// Flipper.mc — Pivoting paddle with simple angular motion.
//
// Geometry
//   A flipper is a fat line segment from `pivot` to `tip`. The tip
//   position is derived from (pivotX, pivotY, length, angleDeg)
//   each tick. Collision treats the flipper as a *capsule* of
//   `radius` around that segment, so the ball never tunnels into
//   the segment's interior even at high speed.
//
// Motion
//   - When inactive: angle relaxes toward restAngle.
//   - When active:   angle drives toward activeAngle (the flipped-up
//     position) at swingSpeed deg/tick.
//   The previous angle is kept so we can compute angular velocity for
//   the "impulse" we add to the ball on contact (the satisfying KICK).
//
// Side
//   side = -1 for LEFT flipper, +1 for RIGHT flipper. Used to flip
//   the angle convention so both flippers raise their tips upward
//   toward the centre of the table.
// ═══════════════════════════════════════════════════════════════

using Toybox.Math;
using Toybox.Graphics;

class Flipper {
    var pivotX;
    var pivotY;
    var length;
    var radius;           // COLLISION capsule radius (fat for robustness)
    var drawRadius;       // VISUAL radius — kept thin for retro feel
    var side;             // -1 = left, +1 = right
    var restAngle;        // degrees, world frame (0 = pointing right)
    var activeAngle;      // degrees
    var swingSpeed;       // deg/tick
    var relaxSpeed;       // deg/tick
    var angle;
    var prevAngle;
    var active;
    // Self-release pulse — ticks remaining before auto-release. 0
    // means "no auto-release scheduled" (e.g. when held via a button
    // or active touch). Bumped by `pulse(n)` for tap-fire scenarios
    // where the input doesn't tell us when the finger lifts. The
    // GameController ticks this exactly once per frame (NOT per
    // sub-step) so timing is deterministic regardless of physics rate.
    var pulseTicks;

    function initialize(_side) {
        pivotX = 0; pivotY = 0; length = 32; radius = 4; drawRadius = 3;
        side = _side;
        restAngle   = (_side < 0) ?  25 :  155;
        activeAngle = (_side < 0) ? -35 :  215;
        swingSpeed  = 28.0;
        relaxSpeed  = 12.0;
        angle       = restAngle;
        prevAngle   = restAngle;
        active      = false;
        pulseTicks  = 0;
    }

    // `rad` = collision radius. The visual radius is decoupled and
    // pinned thin (≈ 3 px) so the paddle always looks like a classic
    // retro flipper, regardless of how big we make the collision
    // capsule for robustness.
    function setGeometry(px, py, len, rad) {
        pivotX = px; pivotY = py; length = len; radius = rad;
        drawRadius = 3;
        if (rad <= 4) { drawRadius = 2; }
    }

    function setAngles(restA, activeA, sSpeed, rSpeed) {
        restAngle   = restA;
        activeAngle = activeA;
        swingSpeed  = sSpeed;
        relaxSpeed  = rSpeed;
        angle       = restA;
        prevAngle   = restA;
    }

    // ── Press / release API ─────────────────────────────────────────
    // `press()` / `release()` — used for HELD input (button or touch
    // hold). No auto-release scheduled.
    function press()   { active = true;  pulseTicks = 0; }
    function release() { active = false; pulseTicks = 0; }

    // `pulse(n)` — used for SHOTGUN input (onTap fallback that
    // doesn't tell us when the finger lifts). Activates the flipper
    // and schedules an auto-release after `n` frames. Re-calling
    // pulse extends the window. A subsequent press() / release() from
    // a held input takes priority and cancels the pulse.
    function pulse(n) {
        active = true;
        if (n > pulseTicks) { pulseTicks = n; }
    }

    // Called exactly once per frame by GameController.step() — drives
    // the pulse auto-release. Independent of the sub-step collision
    // loop so timing stays deterministic at any physics rate.
    function tickPulse() {
        if (pulseTicks > 0) {
            pulseTicks = pulseTicks - 1;
            if (pulseTicks == 0) { active = false; }
        }
    }

    // Advance the angle toward its current target. `dtFrac` lets the
    // controller substep rotation — calling step(1.0/3) three times
    // per tick produces the same total rotation as one step(1.0) call
    // but with intermediate positions where collision can be checked.
    // Without that, a fast paddle can sweep past the ball entirely.
    function step(dtFrac) {
        prevAngle = angle;
        var target = active ? activeAngle : restAngle;
        var spd;
        if (active) { spd = swingSpeed * dtFrac; }
        else        { spd = relaxSpeed * dtFrac; }
        var d = target - angle;
        if      (d >  spd) { angle = angle + spd; }
        else if (d < -spd) { angle = angle - spd; }
        else               { angle = target;      }
    }

    // Returns deg/tick — signed angular velocity (positive when angle
    // increased this tick). Caller uses |angVel| to scale the kick.
    function angularVelocity() { return angle - prevAngle; }

    // World coordinates of the tip.
    function tipX() {
        var rad = angle * 3.14159 / 180.0;
        return pivotX + length * Math.cos(rad);
    }
    function tipY() {
        var rad = angle * 3.14159 / 180.0;
        return pivotY + length * Math.sin(rad);
    }

    // Draw the flipper offset by (ox,oy). A glossy moulded paddle:
    // dark under-shadow → coloured body → bright top gloss line →
    // chrome pivot hub. Flashes brighter for a couple frames right
    // after an active swing so a good hit reads visually.
    function draw(dc, ox, oy) {
        var px = pivotX + ox;
        var py = pivotY + oy;
        var tx = tipX() + ox;
        var ty = tipY() + oy;
        var hot = active && (angle != prevAngle);
        var col;
        if (side < 0) { col = hot ? 0xFF8866 : 0xFF4422; }
        else          { col = hot ? 0xFFEE66 : 0xFFCC22; }
        var shadow = (side < 0) ? 0x661A0C : 0x664008;
        var r = drawRadius;

        // Under-shadow capsule.
        dc.setColor(shadow, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(r * 2 + 2);
        dc.drawLine(px + 1, py + 2, tx + 1, ty + 2);

        // Coloured body.
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(r * 2 + 1);
        dc.drawLine(px, py, tx, ty);

        // Top gloss line.
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(px, py - r + 1, tx, ty - r + 1);

        dc.setPenWidth(1);
        // Rounded caps.
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(px, py, r);
        dc.fillCircle(tx, ty, r - 1);
        // Chrome pivot hub.
        dc.setColor(0xE8EEF6, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(px, py, r / 2 + 1);
        dc.setColor(0x303844, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(px, py, r / 2);
    }
}
