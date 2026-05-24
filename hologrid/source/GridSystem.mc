// ═══════════════════════════════════════════════════════════════
// GridSystem.mc — Hologrid tile storage.
//
// Tiles:  HG_FLOOR, HG_WALL, HG_EXIT.
// Actors (player, blockers) live in separate arrays and overlay
// the grid at render time.  This keeps the grid pure terrain and
// makes "did anyone land on the player" a simple actor scan.
// ═══════════════════════════════════════════════════════════════

const HG_FLOOR = 0;
const HG_WALL  = 1;
const HG_EXIT  = 2;

const HG_DIR_U = 0;
const HG_DIR_R = 1;
const HG_DIR_D = 2;
const HG_DIR_L = 3;

class GridSystem {
    var n;
    var tiles;
    var exitR;
    var exitC;

    function initialize(size) {
        n     = size;
        tiles = new [n * n]b;
        exitR = -1; exitC = -1;
    }

    function idx(r, c) { return r * n + c; }
    function inBounds(r, c) { return r >= 0 && r < n && c >= 0 && c < n; }

    function get(r, c) {
        if (!inBounds(r, c)) { return HG_WALL; }
        return tiles[idx(r, c)];
    }
    function set(r, c, v) {
        if (!inBounds(r, c)) { return; }
        tiles[idx(r, c)] = v;
    }
    function isWalkable(r, c) {
        var t = get(r, c);
        return t == HG_FLOOR || t == HG_EXIT;
    }

    static function dirDelta(d) {
        if (d == HG_DIR_U) { return [-1,  0]; }
        if (d == HG_DIR_R) { return [ 0,  1]; }
        if (d == HG_DIR_D) { return [ 1,  0]; }
        return            [ 0, -1];
    }
}
