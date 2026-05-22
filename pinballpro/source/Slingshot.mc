// ═══════════════════════════════════════════════════════════════
// Slingshot.mc — Triangular kicker placed next to each flipper.
//
// A slingshot is defined by three corners A, B, C. Two of the
// corners (A and B) form the ACTIVE EDGE — the line segment that
// the ball collides with. The third corner C is used purely to
// figure out the OUTWARD direction: the kick normal points away
// from C (so the ball is hurled back into the playfield, not into
// the back wall).
//
// The shape is drawn as a filled triangle using all 3 corners so it
// reads visually as a classic sling. On hit, the renderer flashes
// the edges brighter for a few frames.
// ═══════════════════════════════════════════════════════════════

using Toybox.Math;

class Slingshot {
    // Active edge — what the ball actually collides with.
    var ax; var ay;
    var bx; var by;
    // Pre-computed outward unit normal (points away from corner C).
    var nx; var ny;
    // Third corner — used for drawing the triangle + for normal sign.
    var cx; var cy;
    var color;
    var flash;

    function initialize() {
        ax = 0; ay = 0; bx = 0; by = 0;
        nx = 0; ny = -1;
        cx = 0; cy = 0;
        color = 0xCC4488;
        flash = 0;
    }

    function configure(ax_, ay_, bx_, by_, cx_, cy_, col) {
        ax = ax_; ay = ay_;
        bx = bx_; by = by_;
        cx = cx_; cy = cy_;
        color = col;
        flash = 0;

        var dx = bx - ax;
        var dy = by - ay;
        var len = Math.sqrt(dx * dx + dy * dy);
        if (len < 0.001) { nx = 0; ny = -1; return; }
        // Perpendicular candidate; flip if it points toward the back
        // (third) corner so the outward normal points INTO the play
        // area (away from the wall/triangle interior).
        var n1x = -dy / len;
        var n1y =  dx / len;
        var midX = (ax + bx) / 2.0;
        var midY = (ay + by) / 2.0;
        var dot = (cx - midX) * n1x + (cy - midY) * n1y;
        if (dot > 0) { n1x = -n1x; n1y = -n1y; }
        nx = n1x; ny = n1y;
    }

    function hit() { flash = 5; }
    function tickFlash() { if (flash > 0) { flash = flash - 1; } }
}
