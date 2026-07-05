// ═══════════════════════════════════════════════════════════════
// GridManager.mc — Grid storage, swap, gravity, refill.
//
// Tiles are stored in a single flat Int array (row-major, idx = r*COLS + c).
// 0 = empty cell, 1..NUM_TILE_TYPES = gem.
//
// All grid mutations live here. MatchEngine reads the grid and writes
// 0s into matched cells; GameController orchestrates the cascade by
// calling clearMatches → applyGravity → refill → MatchEngine.find.
//
// Grid is intentionally small (default 6×7 = 42 cells) so every
// operation is O(R·C) and runs in <2K operations even on Fenix Chronos.
// ═══════════════════════════════════════════════════════════════

using Toybox.Math;

const ROWS = 7;
const COLS = 6;

class GridManager {
    var rows;
    var cols;
    var cells;   // Int[rows*cols]

    function initialize() {
        rows  = ROWS;
        cols  = COLS;
        cells = new [rows * cols];
        clear();
    }

    function clear() {
        var total = rows * cols;
        for (var i = 0; i < total; i++) { cells[i] = TILE_EMPTY; }
    }

    function get(r, c) {
        if (r < 0 || r >= rows || c < 0 || c >= cols) { return TILE_EMPTY; }
        return cells[r * cols + c];
    }

    function set(r, c, v) {
        cells[r * cols + c] = v;
    }

    // Initial board fill — every cell gets a random gem, but the
    // generator avoids creating any 3-in-a-row at spawn so the
    // player starts with a clean board (no free cascades).
    function fillNoMatches() {
        for (var r = 0; r < rows; r++) {
            for (var c = 0; c < cols; c++) {
                var safety = 0;
                while (safety < 12) {
                    var t = 1 + (Math.rand() % NUM_TILE_TYPES);
                    cells[r * cols + c] = t;
                    // Reject if it forms a horizontal/vertical run of 3.
                    if (c >= 2
                        && cells[r * cols + c - 1] == t
                        && cells[r * cols + c - 2] == t) {
                        safety = safety + 1; continue;
                    }
                    if (r >= 2
                        && cells[(r - 1) * cols + c] == t
                        && cells[(r - 2) * cols + c] == t) {
                        safety = safety + 1; continue;
                    }
                    break;
                }
            }
        }
    }

    // True when (r1,c1) and (r2,c2) differ by exactly one cell
    // horizontally OR vertically.
    function isAdjacent(r1, c1, r2, c2) {
        var dr = r1 - r2; if (dr < 0) { dr = -dr; }
        var dc = c1 - c2; if (dc < 0) { dc = -dc; }
        return (dr + dc) == 1;
    }

    // Swap two tiles unconditionally (no adjacency or match check).
    function swap(r1, c1, r2, c2) {
        var i1 = r1 * cols + c1;
        var i2 = r2 * cols + c2;
        var t  = cells[i1];
        cells[i1] = cells[i2];
        cells[i2] = t;
    }

    // After matches are cleared, pull tiles downward to fill empty
    // cells, column by column (gravity).
    function applyGravity() {
        for (var c = 0; c < cols; c++) {
            var write = rows - 1;
            for (var r = rows - 1; r >= 0; r--) {
                var v = cells[r * cols + c];
                if (v != TILE_EMPTY) {
                    cells[write * cols + c] = v;
                    if (write != r) { cells[r * cols + c] = TILE_EMPTY; }
                    write = write - 1;
                }
            }
            // Anything above `write` (inclusive) is now empty — leave 0s.
        }
    }

    // Spawn random gems in every empty cell. Called after applyGravity
    // so the freshly fallen tiles plus new ones fill the board again.
    function refill() {
        var total = rows * cols;
        for (var i = 0; i < total; i++) {
            if (cells[i] == TILE_EMPTY) {
                cells[i] = 1 + (Math.rand() % NUM_TILE_TYPES);
            }
        }
    }

    // Animated counterpart to applyGravity(): identical result, but also
    // records, for every surviving gem's NEW position, which row it fell
    // FROM — so the view layer can tween it from old → new for a real
    // "gems tumbling down" cascade instead of an instant snap.
    // `fallFrom` must be an Int[rows*cols] array supplied by the caller;
    // untouched entries default to their own row (i.e. "didn't move").
    function applyGravityAnimated(fallFrom) {
        for (var c = 0; c < cols; c++) {
            var vals     = new [rows];
            var origRows = new [rows];
            var n = 0;
            for (var r = 0; r < rows; r++) {
                var v = cells[r * cols + c];
                if (v != TILE_EMPTY) {
                    vals[n] = v; origRows[n] = r; n = n + 1;
                }
            }
            var write = rows - 1;
            for (var i = n - 1; i >= 0; i--) {
                cells[write * cols + c]    = vals[i];
                fallFrom[write * cols + c] = origRows[i];
                write = write - 1;
            }
            for (var r = write; r >= 0; r--) { cells[r * cols + c] = TILE_EMPTY; }
        }
    }

    // Animated counterpart to refill(): freshly spawned gems get a negative
    // fallFrom (stacked per column) so they visibly drop in from above the
    // visible board top rather than popping into existence.
    function refillAnimated(fallFrom) {
        for (var c = 0; c < cols; c++) {
            var above = 1;
            for (var r = 0; r < rows; r++) {
                var idx = r * cols + c;
                if (cells[idx] == TILE_EMPTY) {
                    cells[idx]    = 1 + (Math.rand() % NUM_TILE_TYPES);
                    fallFrom[idx] = -above;
                    above = above + 1;
                }
            }
        }
    }

    // True when at least one valid swap exists that would create a
    // match. Used by the controller to auto-shuffle dead boards so
    // the player is never stuck.
    function hasAnyValidMove() {
        for (var r = 0; r < rows; r++) {
            for (var c = 0; c < cols; c++) {
                // Try swap with right neighbour
                if (c + 1 < cols) {
                    swap(r, c, r, c + 1);
                    var ok = _wouldMatchAt(r, c) || _wouldMatchAt(r, c + 1);
                    swap(r, c, r, c + 1);
                    if (ok) { return true; }
                }
                // Try swap with bottom neighbour
                if (r + 1 < rows) {
                    swap(r, c, r + 1, c);
                    var ok2 = _wouldMatchAt(r, c) || _wouldMatchAt(r + 1, c);
                    swap(r, c, r + 1, c);
                    if (ok2) { return true; }
                }
            }
        }
        return false;
    }

    // Helper for hasAnyValidMove — would the gem at (r,c) be part of a
    // horizontal or vertical run of 3+ under the current grid state?
    hidden function _wouldMatchAt(r, c) {
        var v = cells[r * cols + c];
        if (v == TILE_EMPTY) { return false; }

        // Horizontal: count contiguous run through (r,c)
        var hLen = 1;
        var k = c - 1;
        while (k >= 0   && cells[r * cols + k] == v) { hLen++; k--; }
        k = c + 1;
        while (k < cols && cells[r * cols + k] == v) { hLen++; k++; }
        if (hLen >= 3) { return true; }

        // Vertical
        var vLen = 1;
        k = r - 1;
        while (k >= 0   && cells[k * cols + c] == v) { vLen++; k--; }
        k = r + 1;
        while (k < rows && cells[k * cols + c] == v) { vLen++; k++; }
        return vLen >= 3;
    }
}
