// ═══════════════════════════════════════════════════════════════
// GridManager.mc — Boulder-Dash style tile storage.
//
// Tile codes (kept as bytes for compact storage):
//   TC_EMPTY    walkable cave space
//   TC_DIRT     diggable soil
//   TC_ROCK     boulder (falls, rolls off rounded tiles, kills)
//   TC_DIAMOND  diamond (falls, rolls; collectible; also kills)
//   TC_WALL     hard wall (border; indestructible)
//   TC_BRICK    soft wall (round-topped; rocks roll off; can be
//               smashed by a falling rock/diamond)
//   TC_EXIT     locked initially, opens when crystal goal met
// ═══════════════════════════════════════════════════════════════

const TC_EMPTY   = 0;
const TC_DIRT    = 1;
const TC_ROCK    = 2;
const TC_DIAMOND = 3;
const TC_WALL    = 4;
const TC_BRICK   = 5;
const TC_EXIT    = 6;

const DC_DIR_U = 0;
const DC_DIR_R = 1;
const DC_DIR_D = 2;
const DC_DIR_L = 3;

class GridManager {
    var w;
    var h;
    var tiles;
    var crystalTotal;

    function initialize(width, height) {
        w = width; h = height;
        tiles = new [w * h]b;
        crystalTotal = 0;
    }

    function idx(r, c) { return r * w + c; }

    function inBounds(r, c) { return r >= 0 && r < h && c >= 0 && c < w; }

    function get(r, c) {
        if (!inBounds(r, c)) { return TC_WALL; }
        return tiles[idx(r, c)];
    }

    function set(r, c, v) {
        if (!inBounds(r, c)) { return; }
        tiles[idx(r, c)] = v;
    }

    function countDiamonds() {
        var c = 0;
        for (var i = 0; i < tiles.size(); i++) {
            if (tiles[i] == TC_DIAMOND) { c = c + 1; }
        }
        return c;
    }

    // True if a falling rock/diamond can ROLL off the tile sideways.
    // In Boulder Dash that's any rounded-top tile: rock, diamond, brick.
    static function isRoundTop(t) {
        return t == TC_ROCK || t == TC_DIAMOND || t == TC_BRICK;
    }

    static function dirDelta(d) {
        if (d == DC_DIR_U) { return [-1,  0]; }
        if (d == DC_DIR_R) { return [ 0,  1]; }
        if (d == DC_DIR_D) { return [ 1,  0]; }
        return            [ 0, -1];
    }
}
