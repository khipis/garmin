// ═══════════════════════════════════════════════════════════════
// MatchEngine.mc — Find and clear 3+ in-a-row runs.
//
// Two-pass scan: rows then columns. Cells belonging to ANY match
// are flagged in a parallel `marks` array; once both axes have been
// scanned the engine clears every flagged cell in one sweep and
// returns the number of cleared tiles (used by the score system).
//
// The two-pass design is important because a single gem can belong
// to both a horizontal and a vertical match (an L / T / + shape);
// counting it once via a flag bitmap avoids double-scoring while
// still detecting all conflicting runs in O(rows·cols).
// ═══════════════════════════════════════════════════════════════

class MatchEngine {
    hidden var _marks;     // Boolean[rows*cols] — true = part of a match
    hidden var _capacity;  // size of _marks (reallocated if grid grows)

    function initialize() {
        _capacity = 0;
        _marks    = null;
    }

    // Scan the grid and populate _marks with cells belonging to any 3+
    // run. Does NOT mutate the grid. Returns the count of marked cells.
    // Safe to call before getMarks() for the flash animation — the
    // caller must NOT call findAndClear() until the flash is over
    // because findAndClear() also resets _marks.
    function markOnly(grid) {
        var total = grid.rows * grid.cols;
        if (_capacity != total) {
            _marks    = new [total];
            _capacity = total;
        }
        for (var i = 0; i < total; i++) { _marks[i] = false; }
        _scanRows(grid);
        _scanCols(grid);
        var count = 0;
        for (var i = 0; i < total; i++) { if (_marks[i]) { count++; } }
        return count;
    }

    // Returns the internal marks array populated by the last markOnly()
    // call. The reference is valid until the next markOnly()/findAndClear()
    // call resets it — which is exactly what we need: hold it during the
    // flash animation, then let findAndClear() overwrite it on cascade.
    function getMarks() { return _marks; }

    // Find all 3+ runs in the grid and clear them. Returns the number
    // of cleared cells (0 means no matches → cascade can stop).
    function findAndClear(grid) {
        markOnly(grid);
        var cleared = 0;
        var total   = grid.rows * grid.cols;
        for (var i = 0; i < total; i++) {
            if (_marks[i]) {
                grid.cells[i] = TILE_EMPTY;
                cleared = cleared + 1;
            }
        }
        return cleared;
    }

    hidden function _scanRows(grid) {
        for (var r = 0; r < grid.rows; r++) {
            var runVal = -1; var runStart = 0;
            for (var c = 0; c <= grid.cols; c++) {
                var v = (c < grid.cols) ? grid.cells[r * grid.cols + c] : -1;
                if (v != runVal) {
                    if (runVal > TILE_EMPTY && (c - runStart) >= 3) {
                        for (var k = runStart; k < c; k++) {
                            _marks[r * grid.cols + k] = true;
                        }
                    }
                    runVal = v; runStart = c;
                }
            }
        }
    }

    hidden function _scanCols(grid) {
        for (var c = 0; c < grid.cols; c++) {
            var runVal = -1; var runStart = 0;
            for (var r = 0; r <= grid.rows; r++) {
                var v = (r < grid.rows) ? grid.cells[r * grid.cols + c] : -1;
                if (v != runVal) {
                    if (runVal > TILE_EMPTY && (r - runStart) >= 3) {
                        for (var k = runStart; k < r; k++) {
                            _marks[k * grid.cols + c] = true;
                        }
                    }
                    runVal = v; runStart = r;
                }
            }
        }
    }

    // Quick "is there any match right now?" probe — used to validate a
    // swap before committing. Does NOT mutate the grid.
    function anyMatch(grid) {
        for (var r = 0; r < grid.rows; r++) {
            var runVal = grid.cells[r * grid.cols];
            var runLen = 1;
            for (var c = 1; c < grid.cols; c++) {
                var v = grid.cells[r * grid.cols + c];
                if (v == runVal && v > TILE_EMPTY) {
                    runLen = runLen + 1;
                    if (runLen >= 3) { return true; }
                } else { runVal = v; runLen = 1; }
            }
        }
        for (var c = 0; c < grid.cols; c++) {
            var runVal = grid.cells[c];
            var runLen = 1;
            for (var r = 1; r < grid.rows; r++) {
                var v = grid.cells[r * grid.cols + c];
                if (v == runVal && v > TILE_EMPTY) {
                    runLen = runLen + 1;
                    if (runLen >= 3) { return true; }
                } else { runVal = v; runLen = 1; }
            }
        }
        return false;
    }
}
