// ═══════════════════════════════════════════════════════════════
// Ghost.mc — One of Manpac's ghosts.
//
// Two behaviour types:
//   GHOST_TRACKER  — greedy step toward Pac-Man's tile
//   GHOST_RANDOM   — random walk that avoids U-turns
//
// In FRIGHTENED mode (set by GameController after Pac-Man eats a
// power pellet) the ghost flees: every step picks the legal move
// that MAXIMISES Manhattan distance to Pac-Man.  When the
// frightened timer runs out it returns to its normal behaviour.
//
// A ghost that's been eaten in frightened mode is teleported back
// to its home spawn tile and stays inactive for `respawnTicks`
// ticks before re-entering play.
// ═══════════════════════════════════════════════════════════════

using Toybox.Math;

const GHOST_TRACKER = 0;
const GHOST_RANDOM  = 1;

class Ghost {
    var r;
    var c;
    var dir;
    var type;
    var homeR;
    var homeC;
    var frightened;     // true: edible / flees Pac-Man
    var respawnTicks;   // >0: hidden in the home box, counting down

    function initialize(initR, initC, t) {
        r = initR; c = initC;
        homeR = initR; homeC = initC;
        dir = DIR_L;
        type = t;
        frightened   = false;
        respawnTicks = 0;
    }

    function frighten(ticks) {
        if (respawnTicks > 0) { return; }
        frightened = true;
    }
    function unfrighten() { frightened = false; }
    function eaten()      {
        // Drop back home, hide for 8 ticks, drop frightened state.
        r = homeR; c = homeC;
        frightened   = false;
        respawnTicks = 8;
    }
    function isActive() { return respawnTicks <= 0; }

    function step(grid, n, targetR, targetC) {
        if (respawnTicks > 0) { respawnTicks = respawnTicks - 1; return; }

        if (frightened) {
            _stepFlee(grid, n, targetR, targetC);
            return;
        }
        if (type == GHOST_RANDOM) {
            _stepRandom(grid, n);
            return;
        }
        _stepChase(grid, n, targetR, targetC);
    }

    hidden function _stepChase(grid, n, rt, ct) {
        var bestDir = dir; var bestD = 99999; var found = false;
        for (var d = 0; d < 4; d++) {
            if (_isReverse(d, dir)) { continue; }
            var de = Player.delta(d);
            var nr = r + de[0]; var nc = c + de[1];
            if (nr < 0 || nr >= n || nc < 0 || nc >= n) { continue; }
            if (grid[nr * n + nc] == TILE_WALL) { continue; }
            var dist = (nr - rt).abs() + (nc - ct).abs();
            if (dist < bestD) { bestD = dist; bestDir = d; found = true; }
        }
        if (!found) {
            // Dead end — force a U-turn.
            for (var d2 = 0; d2 < 4; d2++) {
                var de2 = Player.delta(d2);
                var nr2 = r + de2[0]; var nc2 = c + de2[1];
                if (nr2 < 0 || nr2 >= n || nc2 < 0 || nc2 >= n) { continue; }
                if (grid[nr2 * n + nc2] == TILE_WALL) { continue; }
                bestDir = d2; found = true; break;
            }
        }
        if (found) {
            dir = bestDir;
            var ded = Player.delta(dir);
            r = r + ded[0]; c = c + ded[1];
        }
    }

    hidden function _stepFlee(grid, n, rt, ct) {
        var bestDir = dir; var bestD = -1; var found = false;
        for (var d = 0; d < 4; d++) {
            if (_isReverse(d, dir)) { continue; }
            var de = Player.delta(d);
            var nr = r + de[0]; var nc = c + de[1];
            if (nr < 0 || nr >= n || nc < 0 || nc >= n) { continue; }
            if (grid[nr * n + nc] == TILE_WALL) { continue; }
            var dist = (nr - rt).abs() + (nc - ct).abs();
            if (dist > bestD) { bestD = dist; bestDir = d; found = true; }
        }
        if (!found) {
            for (var d2 = 0; d2 < 4; d2++) {
                var de2 = Player.delta(d2);
                var nr2 = r + de2[0]; var nc2 = c + de2[1];
                if (nr2 < 0 || nr2 >= n || nc2 < 0 || nc2 >= n) { continue; }
                if (grid[nr2 * n + nc2] == TILE_WALL) { continue; }
                bestDir = d2; found = true; break;
            }
        }
        if (found) {
            dir = bestDir;
            var ded = Player.delta(dir);
            r = r + ded[0]; c = c + ded[1];
        }
    }

    hidden function _stepRandom(grid, n) {
        var legal = [];
        for (var d = 0; d < 4; d++) {
            if (_isReverse(d, dir)) { continue; }
            var de = Player.delta(d);
            var nr = r + de[0]; var nc = c + de[1];
            if (nr < 0 || nr >= n || nc < 0 || nc >= n) { continue; }
            if (grid[nr * n + nc] == TILE_WALL) { continue; }
            legal.add(d);
        }
        if (legal.size() == 0) {
            for (var d2 = 0; d2 < 4; d2++) {
                var de2 = Player.delta(d2);
                var nr2 = r + de2[0]; var nc2 = c + de2[1];
                if (nr2 < 0 || nr2 >= n || nc2 < 0 || nc2 >= n) { continue; }
                if (grid[nr2 * n + nc2] == TILE_WALL) { continue; }
                legal.add(d2);
            }
        }
        if (legal.size() == 0) { return; }
        var pick = legal[Math.rand() % legal.size()];
        dir = pick;
        var ded = Player.delta(dir);
        r = r + ded[0]; c = c + ded[1];
    }

    hidden function _isReverse(d1, d2) {
        if (d1 == DIR_U && d2 == DIR_D) { return true; }
        if (d1 == DIR_D && d2 == DIR_U) { return true; }
        if (d1 == DIR_L && d2 == DIR_R) { return true; }
        if (d1 == DIR_R && d2 == DIR_L) { return true; }
        return false;
    }
}
