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

    // Draw the ball, offset by (ox,oy) so it shakes with the field.
    // A chrome ball look: soft comet trail → drop shadow → graded
    // steel body → crisp specular highlight.
    function draw(dc, ox, oy) {
        if (!alive) { return; }
        var bx = x + ox;
        var by = y + oy;
        var r  = radius;

        // Comet trail (faded) — smaller circles keep multi-ball cheap.
        dc.setColor(0x1A3450, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(t3x + ox, t3y + oy, r - 2);
        dc.setColor(0x3A6C9C, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(t2x + ox, t2y + oy, r - 1);

        // Drop shadow, offset down-right for a lit-from-top-left feel.
        dc.setColor(0x05060A, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(bx + 1, by + 2, r);

        // Graded steel body: dark rim → mid steel → bright core.
        dc.setColor(0x6E7A88, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(bx, by, r);
        dc.setColor(0xB8C2CE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(bx, by, (r * 3) / 4);
        dc.setColor(0xE8EEF6, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(bx - r / 4, by - r / 4, (r * 2) / 5);

        // Crisp specular highlight.
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        var hr = r / 3; if (hr < 1) { hr = 1; }
        dc.fillCircle(bx - r / 3, by - r / 3, hr);
    }
}
