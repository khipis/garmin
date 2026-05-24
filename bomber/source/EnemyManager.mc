// ═══════════════════════════════════════════════════════════════
// EnemyManager.mc — 1-3 simple enemies with grid AI.
//
// Each enemy is a [r, c, alive, stepCooldownMs, lastDir] entry:
//   alive            1 = alive, 0 = dead
//   stepCooldownMs   ms remaining before the next grid-step
//   lastDir          0..3 (preferred continuation direction)
//
// AI rules:
//   1. Continue in `lastDir` if that tile is walkable AND has no
//      bomb on it.  This produces straight-line patrols.
//   2. Otherwise pick a random valid direction (uniformly from the
//      walkable, non-bomb neighbours).
//   3. If completely blocked, stay still and pick a fresh direction
//      next tick.
//
// Enemies don't carry bombs and don't drop power-ups.  Contact with
// the player kills the player (unless shielded); flames kill the
// enemy and award score.
// ═══════════════════════════════════════════════════════════════

class EnemyManager {
    var enemies;
    var stepIntervalMs;
    hidden var _rngState;

    function initialize() {
        enemies        = [];
        stepIntervalMs = 800;
        _rngState      = 0x12345678;
    }

    function reset() { enemies = []; }

    function spawn(grid, count) {
        enemies = [];
        var cells = GridManager.enemySpawns(grid.n, count);
        for (var i = 0; i < cells.size(); i++) {
            var rc = cells[i];
            enemies.add([rc[0], rc[1], 1, stepIntervalMs, -1]);
        }
    }

    function aliveCount() {
        var k = 0;
        for (var i = 0; i < enemies.size(); i++) {
            if (enemies[i][2] != 0) { k = k + 1; }
        }
        return k;
    }

    // Returns true if any enemy occupies (r,c).
    function isAt(r, c) {
        for (var i = 0; i < enemies.size(); i++) {
            var e = enemies[i];
            if (e[2] != 0 && e[0] == r && e[1] == c) { return true; }
        }
        return false;
    }

    // Kill any enemy on a flame tile.  Returns the number killed.
    function killOnFlame(expl) {
        var k = 0;
        for (var i = 0; i < enemies.size(); i++) {
            var e = enemies[i];
            if (e[2] != 0 && expl.isFlameAt(e[0], e[1])) {
                e[2] = 0;
                k = k + 1;
            }
        }
        return k;
    }

    function tick(dtMs, grid, bombSys) {
        for (var i = 0; i < enemies.size(); i++) {
            var e = enemies[i];
            if (e[2] == 0) { continue; }
            e[3] = e[3] - dtMs;
            if (e[3] > 0) { continue; }
            e[3] = stepIntervalMs;
            _stepOne(e, grid, bombSys);
        }
    }

    hidden function _stepOne(e, grid, bombSys) {
        var dirs = _validDirs(e[0], e[1], grid, bombSys);
        if (dirs.size() == 0) { return; }
        var pick = -1;
        // Prefer last direction for straight-line patrols.
        if (e[4] >= 0) {
            for (var i = 0; i < dirs.size(); i++) {
                if (dirs[i] == e[4]) { pick = e[4]; break; }
            }
        }
        if (pick < 0) {
            _rngState = (_rngState * 1103515245 + 12345) & 0x7FFFFFFF;
            pick = dirs[_rngState % dirs.size()];
        }
        var dr = 0; var dc = 0;
        if      (pick == 0) { dr = -1; }
        else if (pick == 1) { dr =  1; }
        else if (pick == 2) { dc = -1; }
        else                { dc =  1; }
        e[0] = e[0] + dr;
        e[1] = e[1] + dc;
        e[4] = pick;
    }

    hidden function _validDirs(r, c, grid, bombSys) {
        var out = [];
        for (var d = 0; d < 4; d++) {
            var dr = 0; var dc = 0;
            if      (d == 0) { dr = -1; }
            else if (d == 1) { dr =  1; }
            else if (d == 2) { dc = -1; }
            else             { dc =  1; }
            var rr = r + dr; var cc = c + dc;
            if (!grid.isWalkable(rr, cc, false)) { continue; }
            if (bombSys.hasBombAt(rr, cc))       { continue; }
            out.add(d);
        }
        return out;
    }
}
