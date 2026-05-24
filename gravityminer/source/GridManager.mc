// ═══════════════════════════════════════════════════════════════
// GridManager.mc — Vertical mineshaft grid.
//
// Grid is W × H cells of GM_* tile constants.  Width is kept small
// (9) so even tight watch faces can render it with legible cells;
// height is taller (12) to give the game a real "shaft" feel.
//
// Level generation is procedural with a difficulty knob.
// ═══════════════════════════════════════════════════════════════

using Toybox.Math;

const GM_EMPTY = 0;
const GM_DIRT  = 1;
const GM_ROCK  = 2;
const GM_ORE   = 3;
const GM_GEM   = 4;
const GM_WALL  = 5;

const GM_DIR_L = 0;
const GM_DIR_R = 1;
const GM_DIR_D = 2;

class GridManager {
    var w;
    var h;
    var tiles;

    function initialize(width, height) {
        w = width; h = height;
        tiles = new [w * h]b;
    }

    function idx(r, c) { return r * w + c; }
    function get(r, c) {
        if (r < 0 || r >= h || c < 0 || c >= w) { return GM_WALL; }
        return tiles[idx(r, c)];
    }
    function set(r, c, v) {
        if (r < 0 || r >= h || c < 0 || c >= w) { return; }
        tiles[idx(r, c)] = v;
    }

    // Difficulty 0..2 → richer ore vs heavier rocks.
    function generate(diff) {
        var rockPct = [10, 18, 28][diff];
        var orePct  = [22, 18, 14][diff];
        var gemPct  = [ 6,  4,  3][diff];

        for (var r = 0; r < h; r++) {
            for (var c = 0; c < w; c++) {
                if (c == 0 || c == w - 1) { set(r, c, GM_WALL); continue; }
                if (r == h - 1)           { set(r, c, GM_WALL); continue; }
                // Top row stays empty so the player has a platform.
                if (r == 0)               { set(r, c, GM_EMPTY); continue; }
                if (r == 1)               { set(r, c, GM_DIRT);  continue; }
                var roll = Math.rand() % 100;
                if      (roll < rockPct)            { set(r, c, GM_ROCK); }
                else if (roll < rockPct + orePct)   { set(r, c, GM_ORE);  }
                else if (roll < rockPct + orePct + gemPct) { set(r, c, GM_GEM); }
                else                                { set(r, c, GM_DIRT); }
            }
        }
        // Guarantee a clear column under spawn so the player can
        // always make at least one downward move without dying.
        set(0, w / 2, GM_EMPTY);
        set(1, w / 2, GM_DIRT);
    }

    static function isSolid(t) {
        return t == GM_DIRT || t == GM_ROCK || t == GM_ORE ||
               t == GM_GEM  || t == GM_WALL;
    }

    static function isFalling(t) {
        return t == GM_ROCK || t == GM_ORE || t == GM_GEM;
    }
}
