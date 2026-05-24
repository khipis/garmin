// ═══════════════════════════════════════════════════════════════
// CollisionSystem.mc — Pure-function hit-tests.
//
// Two pairs of interactions:
//   1. PLAYER BULLET  →  ENEMY     (snap bullet row to int, match
//                                    against alive enemies' cells)
//   2. ENEMY BULLET   →  PLAYER    (bullet on player row + col)
//
// All checks are on integer cells — both bullets and entities
// snap to the grid for collision so it's never ambiguous what
// got hit.  Visually the bullet renders at its float row.
// ═══════════════════════════════════════════════════════════════

class CollisionSystem {

    // Return total score awarded by player bullets this tick.
    // Side-effects: kills hit enemies and zeroes bullet `alive`.
    static function playerBulletsVsEnemies(pShots, enemies) {
        var pts = 0;
        for (var i = 0; i < pShots.size(); i++) {
            var b = pShots[i];
            if (!b.alive) { continue; }
            var br = (b.row + 0.5).toNumber();
            for (var k = 0; k < enemies.size(); k++) {
                var e = enemies[k];
                if (!e.alive) { continue; }
                if (e.col == b.col && e.row == br) {
                    e.alive = false;
                    b.alive = false;
                    pts = pts + EnemyManager.scoreFor(e.type);
                    break;
                }
            }
        }
        return pts;
    }

    // Returns true if any enemy bullet struck the player this tick.
    // Kills the bullet whether or not the player was hit (so it
    // doesn't pass through invulnerable shields).
    static function enemyBulletsVsPlayer(eShots, player) {
        var hit = false;
        for (var i = 0; i < eShots.size(); i++) {
            var b = eShots[i];
            if (!b.alive) { continue; }
            var br = (b.row + 0.5).toNumber();
            if (br == PI_PLAYER_ROW && b.col == player.col) {
                b.alive = false;
                if (!player.isInvulnerable()) { hit = true; }
            }
        }
        return hit;
    }
}
