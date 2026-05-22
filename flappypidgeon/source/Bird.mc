// ═══════════════════════════════════════════════════════════════
// Bird.mc — Player avatar (pigeon).
//
// The bird's x is fixed; only y/vy change each tick. It also keeps a
// small "wing phase" counter for a 3-frame wing flap animation —
// purely visual, costs nothing.
//
// Drawing is procedural (no bitmap) so the bird renders at any
// scale without an asset and stays sharp on hi-DPI Edge units.
// ═══════════════════════════════════════════════════════════════

using Toybox.Graphics;

class Bird {
    var x;
    var y;
    var vy;
    var radius;        // collision/render radius
    var alive;
    var wingPhase;     // 0..5 — drawing helper

    function initialize() {
        x = 0; y = 0; vy = 0.0; radius = 10; alive = true; wingPhase = 0;
    }

    function reset(startX, startY, r) {
        x = startX;
        y = startY;
        vy = 0.0;
        radius = r;
        alive = true;
        wingPhase = 0;
    }

    function flap() {
        if (!alive) { return; }
        vy = Physics.FLAP_VY;
        wingPhase = 0;       // restart wing animation
    }

    function step() {
        vy = Physics.applyGravity(vy);
        y  = y + vy;
        wingPhase = (wingPhase + 1) % 6;
    }

    // Axis-aligned bounding box used by ObstacleManager for the
    // pipe collision check. Square is slightly smaller than the
    // visual sphere (more forgiving than pixel-perfect collisions).
    function bbox() {
        var r = radius - 1;
        return [x - r, y - r, x + r, y + r];
    }

    // Render the pigeon. `tilt` ∈ [-15..70] degrees of nose pitch.
    function draw(dc) {
        var tilt = vy * 6;
        if (tilt < -15) { tilt = -15; }
        if (tilt > 70)  { tilt = 70;  }

        // Body — grey filled circle
        dc.setColor(0x999999, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, radius);
        // Belly — white half
        dc.setColor(0xEEEEEE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x - 1, y + radius / 3, radius * 2 / 3);
        // Wing — small triangle below the body whose tip moves with phase
        var wingDy = 0;
        if (wingPhase < 2)        { wingDy = -2; }
        else if (wingPhase < 4)   { wingDy =  0; }
        else                      { wingDy =  2; }
        dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[x - 1,            y + 1],
                        [x - radius - 2,   y + 1 + wingDy],
                        [x - 1,            y + radius]]);
        // Eye
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x + radius / 3, y - radius / 3, radius / 4);
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x + radius / 3 + 1, y - radius / 3, (radius / 4 < 2) ? 1 : radius / 6);
        // Beak — small orange triangle pointing right
        dc.setColor(0xFF8822, Graphics.COLOR_TRANSPARENT);
        var beakY = y + (tilt / 18);
        dc.fillPolygon([[x + radius,     beakY - 2],
                        [x + radius + 5, beakY + 1],
                        [x + radius,     beakY + 3]]);
    }
}
