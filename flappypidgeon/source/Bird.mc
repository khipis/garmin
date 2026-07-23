// ═══════════════════════════════════════════════════════════════
// Bird.mc — Player avatar (pigeon).
//
// The bird's x is fixed; only y/vy change each tick. It also keeps a
// small "wing phase" counter for a 3-frame wing flap animation —
// purely visual, costs nothing.
//
// Drawing is procedural (no bitmap) so the bird renders at any
// scale without an asset and stays sharp on hi-DPI Edge units.
//
// Cosmetics: a `skin` selector (0=CLASSIC, 1=NEON, 2=GOLD) recolours
// the body/belly/wing. The game clamps `skin` to what the player
// actually owns (rank-unlocked, shop-ready), so a locked pick just
// renders as the classic pidgeon. A short motion trail of fading
// dots follows the bird during play for extra juice.
// ═══════════════════════════════════════════════════════════════

using Toybox.Graphics;

class Bird {
    var x;
    var y;
    var vy;
    var radius;        // collision/render radius
    var alive;
    var wingPhase;     // 0..5 — drawing helper
    var skin;          // 0=CLASSIC 1=NEON 2=GOLD
    var showTrail;     // draw the motion trail (gameplay only)

    hidden const TRAIL = 6;
    hidden var _tx; hidden var _ty; hidden var _tHead;

    function initialize() {
        x = 0; y = 0; vy = 0.0; radius = 10; alive = true; wingPhase = 0;
        skin = 0; showTrail = false;
        _tx = new [TRAIL]; _ty = new [TRAIL]; _tHead = 0;
        for (var i = 0; i < TRAIL; i++) { _tx[i] = 0.0; _ty[i] = 0.0; }
    }

    function reset(startX, startY, r) {
        x = startX;
        y = startY;
        vy = 0.0;
        radius = r;
        alive = true;
        wingPhase = 0;
        for (var i = 0; i < TRAIL; i++) { _tx[i] = startX; _ty[i] = startY; }
        _tHead = 0;
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
        // Push current position into the trail ring buffer.
        _tHead = (_tHead + 1) % TRAIL;
        _tx[_tHead] = x; _ty[_tHead] = y;
    }

    // Axis-aligned bounding box used by ObstacleManager for the
    // pipe collision check. Square is slightly smaller than the
    // visual sphere (more forgiving than pixel-perfect collisions).
    function bbox() {
        var r = radius - 1;
        return [x - r, y - r, x + r, y + r];
    }

    // ── Skin palette helpers ───────────────────────────────────────
    hidden function _bodyCol() {
        if (skin == 1) { return 0x33E0B0; }   // NEON teal
        if (skin == 2) { return 0xFFCC22; }   // GOLD
        return 0x999999;                       // CLASSIC grey
    }
    hidden function _bellyCol() {
        if (skin == 1) { return 0xCFFCEC; }
        if (skin == 2) { return 0xFFEEAA; }
        return 0xEEEEEE;
    }
    hidden function _wingCol() {
        if (skin == 1) { return 0x11A888; }
        if (skin == 2) { return 0xCC9911; }
        return 0x666666;
    }
    hidden function _trailCol() {
        if (skin == 1) { return 0x66FFCC; }
        if (skin == 2) { return 0xFFDD66; }
        return 0xBBBBBB;
    }

    // Render the pigeon with an optional screen-shake offset (ox, oy).
    function drawAt(dc, ox, oy) {
        var bx = x + ox; var by = y + oy;
        var tilt = vy * 6;
        if (tilt < -15) { tilt = -15; }
        if (tilt > 70)  { tilt = 70;  }

        // Motion trail — faint fading dots behind the bird (gameplay only).
        if (showTrail) {
            var tc = _trailCol();
            for (var t = 1; t < TRAIL; t++) {
                var idx = (_tHead - t + TRAIL * 2) % TRAIL;
                var tr = (radius * (TRAIL - t)) / (TRAIL * 2);
                if (tr < 1) { tr = 1; }
                var f = 70 - t * 9;
                dc.setColor(_dim(tc, f), Graphics.COLOR_TRANSPARENT);
                dc.fillCircle((_tx[idx]).toNumber() + ox, (_ty[idx]).toNumber() + oy, tr);
            }
        }

        var bodyC  = _bodyCol();
        var bellyC = _bellyCol();
        var wingC  = _wingCol();

        // NEON gets a subtle glow ring behind the body.
        if (skin == 1) {
            dc.setColor(0x1C7A66, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(bx, by, radius + 2);
        }

        // Body — filled circle
        dc.setColor(bodyC, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(bx, by, radius);
        // Belly — lighter half
        dc.setColor(bellyC, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(bx - 1, by + radius / 3, radius * 2 / 3);
        // Wing — small triangle below the body whose tip moves with phase
        var wingDy = 0;
        if (wingPhase < 2)        { wingDy = -2; }
        else if (wingPhase < 4)   { wingDy =  0; }
        else                      { wingDy =  2; }
        dc.setColor(wingC, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[bx - 1,            by + 1],
                        [bx - radius - 2,   by + 1 + wingDy],
                        [bx - 1,            by + radius]]);
        // Eye
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(bx + radius / 3, by - radius / 3, radius / 4);
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(bx + radius / 3 + 1, by - radius / 3, (radius / 4 < 2) ? 1 : radius / 6);
        // Beak — small orange triangle pointing right
        dc.setColor(0xFF8822, Graphics.COLOR_TRANSPARENT);
        var beakY = by + (tilt / 18);
        dc.fillPolygon([[bx + radius,     beakY - 2],
                        [bx + radius + 5, beakY + 1],
                        [bx + radius,     beakY + 3]]);
        // GOLD gets a tiny sparkle glint on the crown.
        if (skin == 2) {
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(bx - radius / 3, by - radius / 2, (radius / 5 < 1) ? 1 : radius / 5);
        }
    }

    // Convenience: draw with no shake offset (menu art / simple callers).
    function draw(dc) { drawAt(dc, 0, 0); }

    // Scale a colour's channels by pct for a cheap fade.
    hidden function _dim(col, pct) {
        if (pct < 0) { pct = 0; }
        var r = ((col >> 16) & 0xFF) * pct / 100;
        var g = ((col >> 8)  & 0xFF) * pct / 100;
        var b = (col & 0xFF) * pct / 100;
        return (r << 16) | (g << 8) | b;
    }
}
