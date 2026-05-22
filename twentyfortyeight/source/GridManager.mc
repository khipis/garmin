// ═══════════════════════════════════════════════════════════════
// GridManager.mc — Owns the 4×4 board state.
//
// Storage is a single flat Number array of 16 entries, each holding
// the tile EXPONENT (0 = empty, 1 = "2", 2 = "4", …). Flat layout
// keeps copies cheap and indexing trivial: idx = row * GRID_SIZE + col.
//
// A parallel `_merged` byte map records which cells became a merge
// THIS move, so UIManager can briefly highlight them. The map is
// cleared at the start of every move.
//
// MergeEngine acts on the cells through GridManager's helpers
// (`get`, `set`, `clearMerged`, `markMerged`) — the merge algorithm
// itself is kept here as `_collapseRow`, the only nontrivial piece
// of game logic.
// ═══════════════════════════════════════════════════════════════

using Toybox.Math;

class GridManager {
    var cells;       // Array<Number>, length 16, exponents
    var _merged;     // Array<Number>, length 16, 1 if merged on last move
    var _scratch;    // Array<Number>, length 4, reused per row collapse

    function initialize() {
        cells   = new [GRID_CELLS];
        _merged = new [GRID_CELLS];
        _scratch = new [GRID_SIZE];
        clear();
    }

    function clear() {
        for (var i = 0; i < GRID_CELLS; i++) {
            cells[i]   = 0;
            _merged[i] = 0;
        }
    }

    function get(r, c)        { return cells[r * GRID_SIZE + c]; }
    function set(r, c, v)     { cells[r * GRID_SIZE + c] = v;    }
    function isMerged(r, c)   { return _merged[r * GRID_SIZE + c] != 0; }
    function clearMerged() {
        for (var i = 0; i < GRID_CELLS; i++) { _merged[i] = 0; }
    }
    function markMerged(r, c) { _merged[r * GRID_SIZE + c] = 1; }

    // Drop a fresh tile (90% chance "2", 10% chance "4") onto a
    // random empty cell. Returns true if one was spawned. The caller
    // should always check `hasEmpty()` first if it needs to react to
    // a full board.
    function spawnRandom() {
        var emptyCount = 0;
        for (var i = 0; i < GRID_CELLS; i++) {
            if (cells[i] == 0) { emptyCount++; }
        }
        if (emptyCount == 0) { return false; }
        var pick = Math.rand() % emptyCount;
        for (var j = 0; j < GRID_CELLS; j++) {
            if (cells[j] == 0) {
                if (pick == 0) {
                    cells[j] = (Math.rand() % 10 == 0) ? 2 : 1;
                    return true;
                }
                pick--;
            }
        }
        return false;
    }

    function hasEmpty() {
        for (var i = 0; i < GRID_CELLS; i++) {
            if (cells[i] == 0) { return true; }
        }
        return false;
    }

    // Highest tile currently on the board (exponent).
    function maxExp() {
        var m = 0;
        for (var i = 0; i < GRID_CELLS; i++) {
            if (cells[i] > m) { m = cells[i]; }
        }
        return m;
    }

    // Returns true if at least one move (any direction) is still
    // possible. Used to detect "game over" without committing a real
    // collapse — checks for empties first, then for any neighbouring
    // pair with the same exponent.
    function hasAnyMove() {
        if (hasEmpty()) { return true; }
        for (var r = 0; r < GRID_SIZE; r++) {
            for (var c = 0; c < GRID_SIZE; c++) {
                var v = get(r, c);
                if (c + 1 < GRID_SIZE && get(r, c + 1) == v) { return true; }
                if (r + 1 < GRID_SIZE && get(r + 1, c) == v) { return true; }
            }
        }
        return false;
    }

    // Collapse one "logical row" of length 4 toward the LEFT
    // (toward index 0). Returns the score gained from merges done
    // here and writes back into the row array. `merged` is a
    // parallel boolean output flag per index.
    //
    // This is the canonical 2048 routine — slide non-zero values
    // left, then merge equal neighbours once, then slide again.
    // Each cell can only be involved in one merge per move.
    static function collapseLeft(row, merged) {
        // 1. Slide all non-zero values left, preserving order.
        var write = 0;
        var tmp = [0, 0, 0, 0];
        for (var i = 0; i < GRID_SIZE; i++) {
            if (row[i] != 0) {
                tmp[write] = row[i];
                write++;
            }
        }
        for (var k = write; k < GRID_SIZE; k++) { tmp[k] = 0; }

        // 2. Merge adjacent equals, advancing the write head only when
        //    the cell becomes a merge candidate (i.e. not after a merge).
        var out = [0, 0, 0, 0];
        var mout = [false, false, false, false];
        var wi = 0;
        var i2 = 0;
        var gained = 0;
        while (i2 < GRID_SIZE) {
            var v = tmp[i2];
            if (v == 0) { i2++; continue; }
            if (i2 + 1 < GRID_SIZE && tmp[i2 + 1] == v && v != 0) {
                var merged_e = v + 1;
                out[wi] = merged_e;
                mout[wi] = true;
                gained = gained + Tile.valueOf(merged_e);
                wi++;
                i2 = i2 + 2;
            } else {
                out[wi] = v;
                mout[wi] = false;
                wi++;
                i2++;
            }
        }

        // 3. Write results back to the caller's arrays.
        for (var j = 0; j < GRID_SIZE; j++) {
            row[j]    = out[j];
            merged[j] = mout[j];
        }
        return gained;
    }
}
