// ═══════════════════════════════════════════════════════════════
// ProjectileSystem.mc — Player bullets.
//
// A bullet is a 2D point with constant velocity that dies after
// VR_BULLET_LIFE ticks (or after travelling roughly one screen
// width).  Up to VR_MAX_SHOTS bullets may be alive at once — the
// classic Asteroids "weapon throttling" so the player has to aim,
// not spray.
//
// Bullets wrap around the screen just like everything else.
// `collideAsteroids(asteroids, sw, sh)` is the main consumer of
// CPU here: O(bullets × asteroids), but both numbers are tiny
// (< 4 × < 16) so it's trivially fast.
// ═══════════════════════════════════════════════════════════════

const VR_BULLET_LIFE  = 30;     // ticks (~2.4 s @ 80 ms)
const VR_MAX_SHOTS    = 4;
const VR_BULLET_SPEED = 6.5;    // px/tick — faster than ship

class Bullet {
    var x; var y; var vx; var vy;
    var life;
    var alive;

    function initialize(x_, y_, vx_, vy_) {
        x = x_; y = y_; vx = vx_; vy = vy_;
        life = VR_BULLET_LIFE; alive = true;
    }
}

class ProjectileSystem {
    var bullets;

    function initialize() { bullets = []; }

    function reset() { bullets = []; }

    // Fire from ship's nose in ship's facing direction.
    // Adds ship velocity → bullet travels even faster forward.
    function fire(ship) {
        if (bullets.size() >= VR_MAX_SHOTS) { return false; }
        var dx = ship.noseDx();
        var dy = ship.noseDy();
        var sx = ship.x + dx * (ship.radius + 1);
        var sy = ship.y + dy * (ship.radius + 1);
        var bvx = dx * VR_BULLET_SPEED + ship.vx * 0.5;
        var bvy = dy * VR_BULLET_SPEED + ship.vy * 0.5;
        bullets.add(new Bullet(sx, sy, bvx, bvy));
        return true;
    }

    function tick(sw, sh) {
        for (var i = 0; i < bullets.size(); i++) {
            var b = bullets[i];
            if (!b.alive) { continue; }
            var p = PhysicsEngine.step(b.x, b.y, b.vx, b.vy, sw, sh);
            b.x = p[0]; b.y = p[1];
            b.life = b.life - 1;
            if (b.life <= 0) { b.alive = false; }
        }
        // Compact.
        var nb = [];
        for (var j = 0; j < bullets.size(); j++) {
            if (bullets[j].alive) { nb.add(bullets[j]); }
        }
        bullets = nb;
    }

    // Returns an Array of asteroid indices that were hit this tick.
    // Each impacted bullet is removed; caller resolves the
    // asteroid split + scoring.
    function collideAsteroids(asteroids, sw, sh) {
        var hits = [];
        for (var i = 0; i < bullets.size(); i++) {
            var b = bullets[i];
            if (!b.alive) { continue; }
            for (var k = 0; k < asteroids.size(); k++) {
                var a = asteroids[k];
                if (!a.alive) { continue; }
                if (PhysicsEngine.circlesHit(b.x, b.y, 2.0,
                                              a.x, a.y, a.radius,
                                              sw, sh)) {
                    b.alive = false;
                    hits.add(k);
                    break;
                }
            }
        }
        return hits;
    }
}
