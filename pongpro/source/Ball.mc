// ═══════════════════════════════════════════════════════════════
// Ball.mc — Position + velocity + simple AABB-vs-paddle physics.
//
// The ball is a small filled square (cheap to draw, easy to collide).
// Speed slowly increases with each paddle hit which keeps rallies
// short and tense. Wall bounces are perfectly elastic. Paddle bounces
// add a vertical "english" based on where the ball struck the paddle
// — closer to the edges → steeper angle, classic Pong feel.
//
// Coordinates are screen-pixels (y grows downward). All speeds are
// in px/tick (tick = 25 ms / 40 Hz — see MainView).
// ═══════════════════════════════════════════════════════════════

using Toybox.Graphics;
using Toybox.Math;

class Ball {
    var x;
    var y;
    var vx;
    var vy;
    var size;       // edge length in pixels
    var maxSpeed;   // cap on |vx| so paddles can keep up

    function initialize() {
        x = 0; y = 0; vx = 0.0; vy = 0.0; size = 6; maxSpeed = 6.0;
    }

    function reset(cx, cy, baseSpd, toLeft) {
        x  = cx; y  = cy;
        // Random starting angle within ±35° of horizontal.
        var ang = (Math.rand() % 70) - 35;          // degrees
        // Cheap sin/cos via Toybox.Math.
        var rad = ang * 3.14159 / 180.0;
        var c   = Math.cos(rad);
        var s   = Math.sin(rad);
        var dir = toLeft ? -1 : 1;
        vx = baseSpd * c * dir;
        vy = baseSpd * s;
    }

    function bbox() {
        var h = size / 2;
        return [x - h, y - h, x + h, y + h];
    }

    // Advance one tick. Returns:
    //    0 nothing special
    //   -1 ball passed the LEFT wall (right player scored)
    //   +1 ball passed the RIGHT wall (left player scored)
    function step(playX0, playY0, playX1, playY1) {
        x = x + vx;
        y = y + vy;
        // Top / bottom walls
        var half = size / 2;
        if (y - half < playY0) {
            y  = playY0 + half;
            vy = -vy;
        } else if (y + half > playY1) {
            y  = playY1 - half;
            vy = -vy;
        }
        // Scoring walls
        if (x + half < playX0) { return -1; }
        if (x - half > playX1) { return  1; }
        return 0;
    }

    // Try to bounce off a paddle AABB. Returns true on hit.
    // `paddleSide`: -1 = left paddle, +1 = right paddle.
    function tryPaddleBounce(px, py, pw, ph, paddleSide) {
        var bx0 = x - size / 2;
        var by0 = y - size / 2;
        var bx1 = x + size / 2;
        var by1 = y + size / 2;

        // Quick reject: y-range and x-range must overlap.
        if (bx1 < px || bx0 > px + pw) { return false; }
        if (by1 < py || by0 > py + ph) { return false; }

        // Only bounce if travelling toward the paddle (avoids re-trigger
        // when the ball is already moving away after a previous bounce).
        if (paddleSide < 0 && vx >= 0) { return false; }
        if (paddleSide > 0 && vx <= 0) { return false; }

        // Move ball just outside the paddle on the relevant face.
        if (paddleSide < 0) { x = px + pw + size / 2; }
        else                { x = px - size / 2;      }

        // Compute hit position [-1..+1] relative to paddle centre.
        var rel = (y - (py + ph / 2)) * 2.0 / ph;
        if (rel >  1.0) { rel =  1.0; }
        if (rel < -1.0) { rel = -1.0; }

        // Reflect + boost speed slightly, and re-aim using rel.
        // Angle: ±60° at extremes.
        var ang   = rel * 60.0 * 3.14159 / 180.0;
        var spd   = Math.sqrt(vx * vx + vy * vy) + 0.25;
        if (spd > maxSpeed) { spd = maxSpeed; }
        var c     = Math.cos(ang);
        var s     = Math.sin(ang);
        var dir   = (paddleSide < 0) ? 1 : -1;
        vx = spd * c * dir;
        vy = spd * s;
        return true;
    }

    function draw(dc) {
        var h = size / 2;
        // Glow halo
        dc.setColor(0x115566, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x - h - 1, y - h - 1, size + 2, size + 2);
        // Body — neon cyan
        dc.setColor(0x00EEFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x - h, y - h, size, size);
    }
}
