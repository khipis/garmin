// ═══════════════════════════════════════════════════════════════
// MatchEngine.mc — Find and clear 3+ in-a-row runs, plus the
// "power gem" chain-reaction layer:
//
//   Run of 4+  →  one cell in the run survives as a BOMB gem
//                 instead of clearing (see Tile.TILE_BOMB).
//   Bomb gem cleared (matched, swapped into, or caught in another
//   bomb's blast) → detonates a 3×3 blast around itself. Blasts can
//   overlap other bombs, which then detonate too — a genuine
//   chain reaction that keeps propagating until stable.
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
    hidden var _marks;      // Boolean[rows*cols] — true = part of a match/blast
    hidden var _capacity;   // size of _marks (reallocated if grid grows)
    hidden var _bombSpawns; // flat indices that should become TILE_BOMB on clear

    function initialize() {
        _capacity   = 0;
        _marks      = null;
        _bombSpawns = new [0];
    }

    // Scan the grid and populate _marks with cells belonging to any 3+
    // run. Does NOT mutate the grid. Returns the count of marked cells.
    // Also records run>=4 midpoints as bomb-spawn candidates.
    function markOnly(grid) {
        var total = grid.rows * grid.cols;
        if (_capacity != total) {
            _marks    = new [total];
            _capacity = total;
        }
        for (var i = 0; i < total; i++) { _marks[i] = false; }
        _bombSpawns = new [0];
        _scanRows(grid);
        _scanCols(grid);
        var count = 0;
        for (var i = 0; i < total; i++) { if (_marks[i]) { count++; } }
        return count;
    }

    // Returns the internal marks array populated by the last markOnly()
    // call (and possibly extended since by markBombBlast/expandBombChains).
    function getMarks() { return _marks; }

    // Marks the 3×3 neighbourhood of (r,c) as matched — used both when the
    // player swaps directly into a bomb and when a chain detonation spreads
    // to a neighbouring bomb. No-op if the cell isn't actually a bomb.
    function markBombBlast(grid, r, c) {
        if (grid.get(r, c) != TILE_BOMB) { return; }
        for (var dr = -1; dr <= 1; dr++) {
            for (var dc = -1; dc <= 1; dc++) {
                var rr = r + dr; var cc = c + dc;
                if (rr < 0 || rr >= grid.rows || cc < 0 || cc >= grid.cols) { continue; }
                _marks[rr * grid.cols + cc] = true;
            }
        }
    }

    // Any bomb adjacent to an already-marked cell also detonates — and its
    // blast may in turn touch further bombs, so this loops (bounded) until
    // no new bomb ignites. This is what turns a single match into a real
    // chain reaction across the board.
    function expandBombChains(grid) {
        var changed = true;
        var iter    = 0;
        while (changed && iter < 6) {
            changed = false;
            for (var r = 0; r < grid.rows; r++) {
                for (var c = 0; c < grid.cols; c++) {
                    if (grid.get(r, c) != TILE_BOMB) { continue; }
                    var idx = r * grid.cols + c;
                    if (_marks[idx]) { continue; }
                    if (_hasMarkedNeighbor(grid, r, c)) {
                        markBombBlast(grid, r, c);
                        changed = true;
                    }
                }
            }
            iter = iter + 1;
        }
    }

    hidden function _hasMarkedNeighbor(grid, r, c) {
        return (_isMarked(grid, r - 1, c) || _isMarked(grid, r + 1, c) ||
                _isMarked(grid, r, c - 1) || _isMarked(grid, r, c + 1));
    }
    hidden function _isMarked(grid, r, c) {
        if (r < 0 || r >= grid.rows || c < 0 || c >= grid.cols) { return false; }
        return _marks[r * grid.cols + c];
    }

    // Find all 3+ runs in the grid and clear them immediately (no bomb
    // logic — used only by the synchronous dead-board safety net).
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

    // Clears every currently-marked cell, converting designated bomb-spawn
    // cells into TILE_BOMB instead of emptying them. Returns the count of
    // cells resolved (used for scoring) — this is the animated-cascade
    // counterpart to findAndClear().
    function clearMarked(grid) {
        var total = grid.rows * grid.cols;
        var count = 0;
        for (var i = 0; i < total; i++) {
            if (!_marks[i]) { continue; }
            grid.cells[i] = _isBombSpawn(i) ? TILE_BOMB : TILE_EMPTY;
            count = count + 1;
        }
        return count;
    }

    hidden function _isBombSpawn(idx) {
        for (var k = 0; k < _bombSpawns.size(); k++) {
            if (_bombSpawns[k] == idx) { return true; }
        }
        return false;
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
                        if ((c - runStart) >= 4) {
                            var mid = runStart + (c - runStart) / 2;
                            _bombSpawns.add(r * grid.cols + mid);
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
                        if ((r - runStart) >= 4) {
                            var mid = runStart + (r - runStart) / 2;
                            _bombSpawns.add(mid * grid.cols + c);
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
