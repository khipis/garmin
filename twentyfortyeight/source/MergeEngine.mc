// ═══════════════════════════════════════════════════════════════
// MergeEngine.mc — Applies a swipe direction to the board.
//
// `MergeEngine.applyMove(grid, dir)` runs the canonical 2048 step
// for the given direction:
//   1. Build the 4 logical rows that correspond to `dir`
//      (a row for LEFT/RIGHT, a column for UP/DOWN).
//   2. Reverse them if the direction is RIGHT or DOWN, so the same
//      `collapseLeft` routine in GridManager can always be used.
//   3. Run the collapse, accumulating the score and a "moved" flag.
//   4. Reverse the result back if needed and write into the grid,
//      marking merged cells via `grid.markMerged()`.
//
// Returns a MoveResult containing:
//   moved   - true if anything changed (any tile slid or merged)
//   gained  - score gained from merges this move
//   reached2048 - true if a 2048 tile appeared this move
// ═══════════════════════════════════════════════════════════════

const DIR_LEFT  = 0;
const DIR_RIGHT = 1;
const DIR_UP    = 2;
const DIR_DOWN  = 3;

class MoveResult {
    var moved;
    var gained;
    var reached2048;
    function initialize() {
        moved = false;
        gained = 0;
        reached2048 = false;
    }
}

class MergeEngine {
    // The hot path. Allocates only the 4 small scratch buffers from
    // `grid`, no per-row arrays beyond the static `[0,0,0,0]` ones
    // used inside `GridManager.collapseLeft`.
    static function applyMove(grid, dir) {
        var res = new MoveResult();
        grid.clearMerged();

        var row    = [0, 0, 0, 0];
        var merged = [false, false, false, false];

        for (var line = 0; line < GRID_SIZE; line++) {
            // Snapshot of the original line for change detection.
            var orig = [0, 0, 0, 0];

            // Read the line in the canonical (collapse-toward-LEFT)
            // orientation, then collapse, then write back.
            for (var k = 0; k < GRID_SIZE; k++) {
                row[k] = _read(grid, dir, line, k);
                orig[k] = row[k];
            }
            res.gained = res.gained + GridManager.collapseLeft(row, merged);
            for (var k2 = 0; k2 < GRID_SIZE; k2++) {
                _write(grid, dir, line, k2, row[k2]);
                if (merged[k2]) {
                    _markMerged(grid, dir, line, k2);
                    if (row[k2] >= WIN_EXP) { res.reached2048 = true; }
                }
                if (orig[k2] != row[k2]) { res.moved = true; }
            }
        }
        return res;
    }

    // ── Direction-aware row helpers ─────────────────────────────────
    // For each direction, line ∈ [0..3] picks the row/col index, and
    // k ∈ [0..3] is the index ALONG that line in the canonical
    // (collapse-toward-LEFT) orientation. A k of 0 is the "near"
    // edge that tiles slide toward.

    hidden static function _coords(dir, line, k) {
        // Returns [r, c] for a given (dir, line, k).
        if (dir == DIR_LEFT)  { return [line, k];                   }
        if (dir == DIR_RIGHT) { return [line, GRID_SIZE - 1 - k];   }
        if (dir == DIR_UP)    { return [k, line];                   }
        return                       [GRID_SIZE - 1 - k, line];     // DOWN
    }

    hidden static function _read(grid, dir, line, k) {
        var rc = _coords(dir, line, k);
        return grid.get(rc[0], rc[1]);
    }

    hidden static function _write(grid, dir, line, k, v) {
        var rc = _coords(dir, line, k);
        grid.set(rc[0], rc[1], v);
    }

    hidden static function _markMerged(grid, dir, line, k) {
        var rc = _coords(dir, line, k);
        grid.markMerged(rc[0], rc[1]);
    }
}
