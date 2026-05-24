// ═══════════════════════════════════════════════════════════════
// ProjectileSystem.mc — Bullets, both directions.
//
// We keep TWO arrays so collision pairs are obvious:
//
//   playerBullets  — fired UP from the cannon; max PI_MAX_P_SHOTS
//   enemyBullets   — fired DOWN from the formation; max PI_MAX_E_SHOTS
//
// Each bullet has an integer `col` (locked at fire time) and a
// floating `row` so it can interpolate between cells smoothly
// while still hit-testing on integer cells.  When `row` leaves
// the playfield the bullet is marked dead and compacted out.
//
// Speeds are tuned so player bullets cross the screen in ~1 s and
// enemy bullets in ~1.4 s — slightly slower, giving the player a
// chance to dodge.
// ═══════════════════════════════════════════════════════════════

const PI_MAX_P_SHOTS = 1;   // classic SI: ONE bullet at a time
const PI_MAX_E_SHOTS = 3;
const PI_P_BULLET_V  = 0.95;   // rows / tick (upward)
const PI_E_BULLET_V  = 0.55;   // rows / tick (downward)

class Bullet {
    var col;
    var row;       // float
    var alive;

    function initialize(c, r) { col = c; row = r; alive = true; }
}

class ProjectileSystem {
    var pShots;
    var eShots;

    function initialize() { pShots = []; eShots = []; }

    function reset() { pShots = []; eShots = []; }

    function playerFire(col, row) {
        if (pShots.size() >= PI_MAX_P_SHOTS) { return false; }
        // Start just above the player.
        pShots.add(new Bullet(col, row - 0.5));
        return true;
    }

    function enemyFire(col, row) {
        if (eShots.size() >= PI_MAX_E_SHOTS) { return false; }
        eShots.add(new Bullet(col, row + 0.5));
        return true;
    }

    function tick() {
        for (var i = 0; i < pShots.size(); i++) {
            var b = pShots[i];
            if (!b.alive) { continue; }
            b.row = b.row - PI_P_BULLET_V;
            if (b.row < -1.0) { b.alive = false; }
        }
        for (var j = 0; j < eShots.size(); j++) {
            var b = eShots[j];
            if (!b.alive) { continue; }
            b.row = b.row + PI_E_BULLET_V;
            if (b.row > PI_BOARD_ROWS + 0.5) { b.alive = false; }
        }
        _compact();
    }

    hidden function _compact() {
        var np = [];
        for (var i = 0; i < pShots.size(); i++) {
            if (pShots[i].alive) { np.add(pShots[i]); }
        }
        pShots = np;
        var ne = [];
        for (var j = 0; j < eShots.size(); j++) {
            if (eShots[j].alive) { ne.add(eShots[j]); }
        }
        eShots = ne;
    }
}
