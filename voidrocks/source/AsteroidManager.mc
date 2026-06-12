// ═══════════════════════════════════════════════════════════════
// AsteroidManager.mc — The rock belt.
//
// Each rock is an "irregular polygon" — a deterministic ring of
// SHAPE_VERTS vertices whose distance from the centre is jittered.
// The polygon itself is generated ONCE per rock at spawn time
// (cheap), then rotated each frame inside UIManager.drawAsteroid.
//
// Three size classes:
//   AST_LARGE  — biggest, slowest; splits into 2 MEDs
//   AST_MED    — splits into 2 SMALLs
//   AST_SMALL  — terminal: scored & removed
//
// `spawnWave(wave, sw, sh, baseSpeed, shipX, shipY)` repopulates
// the field for the new wave.  Spawn points are placed on the
// screen edges (never on the ship) so the player has a moment
// to react.
//
// `split(idx, sw, sh)` resolves a hit: marks the target rock dead
// and (if not SMALL) spawns 2 children with perpendicular random
// directions.  Returns the score awarded.
// ═══════════════════════════════════════════════════════════════

using Toybox.Math;

const AST_LARGE = 3;
const AST_MED   = 2;
const AST_SMALL = 1;

const SHAPE_VERTS = 8;       // verts per rock polygon

class Asteroid {
    var x; var y; var vx; var vy;
    var size;            // AST_LARGE | AST_MED | AST_SMALL
    var radius;
    var angle;           // rotation in radians
    var spin;            // delta rotation per tick
    var shape;           // Array<[ox, oy]>  unit-radius offsets
    var alive;

    function initialize(x_, y_, vx_, vy_, size_, radius_, shape_) {
        x = x_; y = y_; vx = vx_; vy = vy_;
        size = size_; radius = radius_;
        angle = 0.0;
        spin  = ((Math.rand() % 200) - 100) / 1500.0;   // ±0.066 rad/tick
        shape = shape_;
        alive = true;
    }
}

class AsteroidManager {
    var rocks;
    hidden var _baseSpeed;       // pixels/tick base

    function initialize() {
        rocks = [];
        _baseSpeed = 1.2;
    }

    function reset() { rocks = []; }

    // Build a unit-circle shape with jittered radii.
    hidden function _makeShape() {
        var verts = [];
        var step = VR_TWO_PI / SHAPE_VERTS;
        for (var i = 0; i < SHAPE_VERTS; i++) {
            var a = i * step;
            // r in [0.78, 1.05] — keeps rocks visibly bumpy but
            // never self-intersecting.
            var r = 0.78 + ((Math.rand() % 27) / 100.0);
            verts.add([Math.cos(a) * r, Math.sin(a) * r]);
        }
        return verts;
    }

    hidden function _radiusFor(size, baseR) {
        if (size == AST_LARGE) { return baseR; }
        if (size == AST_MED)   { return baseR * 65 / 100; }
        return baseR * 38 / 100;       // SMALL
    }

    hidden function _scoreFor(size) {
        if (size == AST_LARGE) { return 20;  }
        if (size == AST_MED)   { return 50;  }
        return 100;                          // SMALL
    }

    // Random unit direction.
    hidden function _randomDir() {
        var a = (Math.rand() % 1000) / 1000.0 * VR_TWO_PI;
        return [Math.cos(a), Math.sin(a)];
    }

    // Place a new asteroid at (x,y) with a random direction.
    hidden function _spawn(x, y, size, baseR, speed) {
        var d = _randomDir();
        var r = _radiusFor(size, baseR);
        var a = new Asteroid(x, y, d[0] * speed, d[1] * speed,
                              size, r, _makeShape());
        rocks.add(a);
    }

    function spawnWave(wave, sw, sh, baseR, baseSpeed, shipX, shipY) {
        rocks      = [];
        _baseSpeed = baseSpeed;

        // 4 large rocks on wave 1, +1 per wave (cap @ 10).
        var n = 3 + wave;
        if (n > 10) { n = 10; }

        // Pick spawn cells along the screen edges, avoiding ship.
        for (var i = 0; i < n; i++) {
            var x = 0; var y = 0;
            var tries = 0;
            while (true) {
                // Pick an edge bucket: 0=top 1=right 2=bottom 3=left
                var edge = Math.rand() % 4;
                if      (edge == 0) { x = Math.rand() % sw; y = 0; }
                else if (edge == 1) { x = sw - 1;            y = Math.rand() % sh; }
                else if (edge == 2) { x = Math.rand() % sw; y = sh - 1; }
                else                 { x = 0;                y = Math.rand() % sh; }
                var dx = x - shipX; var dy = y - shipY;
                if (dx * dx + dy * dy > (baseR * 4) * (baseR * 4)) { break; }
                tries = tries + 1;
                if (tries > 6) { break; }
            }
            var spd = baseSpeed * (0.7 + (Math.rand() % 80) / 100.0);  // 0.7..1.5×
            var d = _randomDir();
            var rad = _radiusFor(AST_LARGE, baseR);
            var a = new Asteroid(x, y, d[0] * spd, d[1] * spd,
                                  AST_LARGE, rad, _makeShape());
            rocks.add(a);
        }
    }

    function tick(sw, sh) {
        for (var i = 0; i < rocks.size(); i++) {
            var a = rocks[i];
            if (!a.alive) { continue; }
            var p = PhysicsEngine.step(a.x, a.y, a.vx, a.vy, sw, sh);
            a.x = p[0]; a.y = p[1];
            a.angle = a.angle + a.spin;
            if (a.angle >= VR_TWO_PI) { a.angle = a.angle - VR_TWO_PI; }
            if (a.angle <  0)          { a.angle = a.angle + VR_TWO_PI; }
        }
    }

    // Hit a rock with a projectile.  Mark dead, spawn children.
    // Returns score awarded.
    function hit(idx, baseR) {
        var a = rocks[idx];
        if (!a.alive) { return 0; }
        a.alive = false;
        var pts = _scoreFor(a.size);
        if (a.size > AST_SMALL) {
            var childSize = a.size - 1;
            var childR = _radiusFor(childSize, baseR);
            // Two children: perpendicular random directions, ~1.4× speed.
            for (var k = 0; k < 2; k++) {
                var d = _randomDir();
                var spd = _baseSpeed * (1.0 + (Math.rand() % 60) / 100.0);  // 1.0..1.6×
                rocks.add(new Asteroid(a.x, a.y,
                                        d[0] * spd, d[1] * spd,
                                        childSize, childR, _makeShape()));
            }
        }
        return pts;
    }

    function compact() {
        var nr = [];
        for (var i = 0; i < rocks.size(); i++) {
            if (rocks[i].alive) { nr.add(rocks[i]); }
        }
        rocks = nr;
    }

    function allDead() {
        for (var i = 0; i < rocks.size(); i++) {
            if (rocks[i].alive) { return false; }
        }
        return true;
    }
}
