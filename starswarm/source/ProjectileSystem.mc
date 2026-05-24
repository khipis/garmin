// ═══════════════════════════════════════════════════════════════
// ProjectileSystem.mc — Player bullets travelling upward.
//
// Each shot is a tiny record {col, row} with row stored as a Float
// so the bullet looks like it's "rising" between cells.  At most
// MAX_SHOTS bullets are alive at once (Galaga-style two-shot limit).
// On every tick each bullet moves up by BULLET_SPEED rows.  When a
// bullet's row drops below 0 it's removed.
//
// `collideAndKill(enemies)`:
//   For each active bullet, look for any non-dead enemy whose
//   integer cell matches the bullet's cell.  If a hit occurs the
//   bullet is removed and the enemy's `state` is flipped to
//   E_DEAD; the caller may then increment the score.  Returns the
//   number of enemies killed this call.
// ═══════════════════════════════════════════════════════════════

class Bullet {
    var col;   // integer-ish float (set on fire from player.col)
    var row;   // Float — top edge of the bullet
    var alive;

    function initialize(c, r) { col = c; row = r; alive = true; }
}

class ProjectileSystem {
    var bullets;
    hidden var BULLET_SPEED = 0.85;
    hidden var MAX_SHOTS    = 2;

    function initialize() { bullets = []; }

    function reset() { bullets = []; }

    function fire(playerCol, playerRow) {
        if (bullets.size() >= MAX_SHOTS) { return false; }
        bullets.add(new Bullet(playerCol, playerRow - 1.0));
        return true;
    }

    function tick() {
        for (var i = 0; i < bullets.size(); i++) {
            var b = bullets[i];
            if (!b.alive) { continue; }
            b.row = b.row - BULLET_SPEED;
            if (b.row < -1.0) { b.alive = false; }
        }
        // Compact: drop dead bullets.
        var nb = [];
        for (var j = 0; j < bullets.size(); j++) {
            if (bullets[j].alive) { nb.add(bullets[j]); }
        }
        bullets = nb;
    }

    // Check each bullet against the enemy list and resolve hits.
    // Returns total points awarded (caller knows the per-enemy
    // scoring rule).
    function collideAndKill(enemies) {
        var killed = 0;
        for (var i = 0; i < bullets.size(); i++) {
            var b = bullets[i];
            if (!b.alive) { continue; }
            // Snap bullet to its current cell for collision.
            var bc = (b.col + 0.5).toNumber();
            var br = (b.row + 0.5).toNumber();
            for (var k = 0; k < enemies.size(); k++) {
                var e = enemies[k];
                if (e.state == E_DEAD) { continue; }
                var ec = e.intCol();
                var er = e.intRow();
                if (ec == bc && er == br) {
                    e.state = E_DEAD;
                    b.alive = false;
                    killed = killed + 1;
                    break;
                }
            }
        }
        return killed;
    }
}
