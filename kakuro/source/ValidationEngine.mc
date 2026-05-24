// ═══════════════════════════════════════════════════════════════
// ValidationEngine.mc — Pure functions over GridManager state.
//
// All gameplay correctness lives here:
//
//   recomputeErrors(grid, errOut)
//     Stamp `errOut[i] = 1` for every cell whose value (when
//     non-zero) violates Kakuro rules:
//       • duplicate digit within its row-run or col-run, OR
//       • the run is fully filled but doesn't match the clue sum.
//
//   isWin(grid)
//     True iff every white cell is filled (1..9) AND every run
//     has unique digits AND every run sums exactly to its clue.
//
//   firstHint(grid)
//     Returns the first (in scan order) empty white cell where
//     `grid.sol` says what to fill — used by the pro hint system.
//
// Rules:
//   • An empty cell is never flagged as an error.
//   • A duplicate counts as an error on BOTH offending cells.
//   • Run-sum mismatches flag all cells of that run.
// ═══════════════════════════════════════════════════════════════

class ValidationEngine {

    static function recomputeErrors(grid, errOut) {
        var sz = grid.n * grid.n;
        for (var i = 0; i < sz; i++) { errOut[i] = 0; }

        // Sweep through each run; check duplicates and (when full)
        // the clue sum.
        for (var r = 0; r < grid.runs.size(); r++) {
            var run     = grid.runs[r];
            var members = run[0];
            var clue    = run[1];
            // Track last cell that contributed each digit so we can
            // mark BOTH cells of a duplicate pair.  -1 = unseen yet.
            var seenAt = [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1];
            var sum    = 0;
            var full   = true;
            for (var k = 0; k < members.size(); k++) {
                var ci = members[k];
                var v  = grid.val[ci];
                if (v == 0) { full = false; continue; }
                sum = sum + v;
                if (seenAt[v] >= 0) {
                    errOut[seenAt[v]] = 1;
                    errOut[ci]        = 1;
                } else {
                    seenAt[v] = ci;
                }
            }
            if (full && sum != clue) {
                for (var k2 = 0; k2 < members.size(); k2++) {
                    errOut[members[k2]] = 1;
                }
            }
        }
    }

    static function isWin(grid) {
        if (!grid.isFilled()) { return false; }
        for (var r = 0; r < grid.runs.size(); r++) {
            var run     = grid.runs[r];
            var members = run[0];
            var clue    = run[1];
            var seen    = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            var sum     = 0;
            for (var k = 0; k < members.size(); k++) {
                var v = grid.val[members[k]];
                if (v < 1 || v > 9) { return false; }
                if (seen[v] != 0)   { return false; }
                seen[v] = 1;
                sum     = sum + v;
            }
            if (sum != clue) { return false; }
        }
        return true;
    }

    // Scan order: first empty white cell.  Used by the hint system
    // to fill the canonical solution digit.
    static function firstEmpty(grid) {
        var sz = grid.n * grid.n;
        for (var i = 0; i < sz; i++) {
            if (grid.white[i] != 0 && grid.val[i] == 0) {
                return [i / grid.n, i % grid.n];
            }
        }
        return [-1, -1];
    }
}
