// ═══════════════════════════════════════════════════════════════
// Ball.mc — One instance per ball in play. Up to MAX_BALLS = 3 balls
// can coexist (multi-ball mode), so this class is deliberately
// allocation-free in the hot path.
//
// Coordinates are screen-pixels (y grows downward). Speeds are
// px/tick (tick ≈ 25 ms → 40 Hz). All numbers are floats for the
// integrator and rounded only at draw time.
//
// A short motion trail (3 history positions) is kept inline to
// avoid per-frame allocations and make multi-ball look snappy.
// ═══════════════════════════════════════════════════════════════

using Toybox.Graphics;
using Toybox.Math;

class Ball {
    var x;
    var y;
    var vx;
    var vy;
    var radius;
    var alive;        // false → ignored by physics + renderer

    // Trail — three recent positions for a short comet tail.
    var t1x; var t1y;
    var t2x; var t2y;
    var t3x; var t3y;

    function initialize() {
        x = 0.0; y = 0.0; vx = 0.0; vy = 0.0; radius = 5;
        alive = false;
        t1x = 0; t1y = 0; t2x = 0; t2y = 0; t3x = 0; t3y = 0;
    }

    function reset(rx, ry, r) {
        x  = rx; y  = ry;
        vx = 0.0; vy = 0.0;
        radius = r;
        alive  = true;
        t1x = rx; t1y = ry;
        t2x = rx; t2y = ry;
        t3x = rx; t3y = ry;
    }

    function kill() { alive = false; }

    function speed() { return Math.sqrt(vx * vx + vy * vy); }

    function rollTrail() {
        t3x = t2x; t3y = t2y;
        t2x = t1x; t2y = t1y;
        t1x = x;   t1y = y;
    }

    function draw(dc) {
        if (!alive) { return; }
        // Trail (faded) — smaller circles to keep multi-ball cheap.
        dc.setColor(0x224466, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(t3x, t3y, radius - 2);
        dc.setColor(0x4488BB, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(t2x, t2y, radius - 1);
        // Body
        dc.setColor(0xCCCCDD, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, radius);
        // Bright highlight pixel
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x - radius / 3, y - radius / 3,
                      (radius / 3 < 1) ? 1 : radius / 3);
    }
}
