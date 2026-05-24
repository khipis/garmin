// ═══════════════════════════════════════════════════════════════
// ValidationEngine.mc — Stateless helpers for clue validation.
//
// isSolved(grid)
//   For each row & column, compute the run-length sequence over
//   FILLED cells (X marks are treated as EMPTY) and compare against
//   the target clue list.  Returns true if all 2n lines match.
//
// errorMask(grid)
//   Returns a Number[n*n] where 1 means "this filled cell is wrong
//   relative to the canonical solution".  Used by the optional
//   error-highlight feature in the menu.  We compare to the stored
//   solution rather than the clues here because that's what gives
//   the player immediate, intuitive feedback ("you placed a fill
//   somewhere the picture doesn't have one").
// ═══════════════════════════════════════════════════════════════

class ValidationEngine {

    // Compute clues for a single line (length n) of a flat grid.
    // Treats `fillValue` cells as filled, all else as empty.
    hidden static function _runsLine(g, n, startIdx, step) {
        var runs = [];
        var cur = 0;
        for (var i = 0; i < n; i++) {
            var v = g[startIdx + i * step];
            if (v == NG_FILL) {
                cur = cur + 1;
            } else {
                if (cur > 0) { runs.add(cur); }
                cur = 0;
            }
        }
        if (cur > 0) { runs.add(cur); }
        if (runs.size() == 0) { runs.add(0); }
        return runs;
    }

    hidden static function _matchesClue(runs, clues, off, len) {
        // The all-zero clue [0] means "empty line".
        if (len == 1 && clues[off] == 0) {
            return (runs.size() == 1 && runs[0] == 0);
        }
        if (runs.size() == 1 && runs[0] == 0) { return false; }
        if (runs.size() != len) { return false; }
        for (var i = 0; i < len; i++) {
            if (runs[i] != clues[off + i]) { return false; }
        }
        return true;
    }

    static function isSolved(grid) {
        var n = grid.n;
        for (var r = 0; r < n; r++) {
            var runs = _runsLine(grid.cells, n, r * n, 1);
            var off  = grid.rowOffs[r];
            var len  = grid.rowOffs[r + 1] - off;
            if (!_matchesClue(runs, grid.rowClues, off, len)) { return false; }
        }
        for (var c = 0; c < n; c++) {
            var runs = _runsLine(grid.cells, n, c, n);
            var off  = grid.colOffs[c];
            var len  = grid.colOffs[c + 1] - off;
            if (!_matchesClue(runs, grid.colClues, off, len)) { return false; }
        }
        return true;
    }

    // Count of FILLED cells that contradict the canonical solution.
    // Cheap O(n²); we call it once per move only.
    static function errorCount(grid) {
        var e = 0;
        var n = grid.n;
        for (var i = 0; i < n * n; i++) {
            if (grid.cells[i] == NG_FILL && grid.solution[i] == 0) {
                e = e + 1;
            }
        }
        return e;
    }

    // Per-cell error flag: 1 = filled-but-shouldn't-be.
    static function isCellError(grid, r, c) {
        var i = grid.idx(r, c);
        return grid.cells[i] == NG_FILL && grid.solution[i] == 0;
    }
}
