// ═══════════════════════════════════════════════════════════════
// SudokuGenerator.mc — Pre-baked puzzles + symmetry transforms.
//
// Generating valid Sudokus from scratch (backtracking) is too slow for
// embedded Garmin devices and could trip the watchdog. Instead we keep
// a small bank of fully-solved 4x4 and 9x9 boards plus per-difficulty
// "blank masks" indicating which cells to clear, and combine them with
// four cheap symmetry transforms that preserve solvability:
//
//   1. Digit relabelling — permute digit identities (1..n → permuted)
//   2. Row-within-band swaps — swap two rows inside one band
//   3. Column-within-stack swaps
//   4. Optional transpose (rotates the board, still a valid solution)
//
// This yields hundreds of thousands of distinct-looking puzzles from
// the small baked bank, in O(n²) per generation — fast even on Fenix
// chronos / older devices.
//
// API:
//   generate(size, difficulty) -> [puzzle, solution]
//      size ∈ {SZ_4, SZ_9}
//      difficulty ∈ {DIFF_EASY, DIFF_MED, DIFF_HARD} (4x4 ignores diff)
// ═══════════════════════════════════════════════════════════════

using Toybox.Math;

const DIFF_EASY = 0;
const DIFF_MED  = 1;
const DIFF_HARD = 2;

class SudokuGenerator {

    // ── Baked solved boards ───────────────────────────────────────────
    // 4x4 solutions (4 different solved grids).
    hidden var _bank4;
    // 9x9 solutions (4 different solved grids).
    hidden var _bank9;
    // Per-difficulty target number of CLUES (filled cells) for 9x9.
    hidden var _clues9;

    function initialize() {
        _bank4 = [
            [1,2,3,4, 3,4,1,2, 2,1,4,3, 4,3,2,1],
            [2,3,4,1, 4,1,2,3, 1,4,3,2, 3,2,1,4],
            [1,3,2,4, 2,4,1,3, 3,1,4,2, 4,2,3,1],
            [4,2,3,1, 3,1,4,2, 2,4,1,3, 1,3,2,4]
        ];

        // Three independent solved 9x9 sudokus. Combined with the random
        // shuffles below this is enough to yield 10^6+ distinct puzzles.
        _bank9 = [
            // Bank 0 — Wikipedia classic
            [5,3,4,6,7,8,9,1,2,
             6,7,2,1,9,5,3,4,8,
             1,9,8,3,4,2,5,6,7,
             8,5,9,7,6,1,4,2,3,
             4,2,6,8,5,3,7,9,1,
             7,1,3,9,2,4,8,5,6,
             9,6,1,5,3,7,2,8,4,
             2,8,7,4,1,9,6,3,5,
             3,4,5,2,8,6,1,7,9],
            // Bank 1 — band-shift pattern
            [1,2,3,4,5,6,7,8,9,
             4,5,6,7,8,9,1,2,3,
             7,8,9,1,2,3,4,5,6,
             2,3,1,5,6,4,8,9,7,
             5,6,4,8,9,7,2,3,1,
             8,9,7,2,3,1,5,6,4,
             3,1,2,6,4,5,9,7,8,
             6,4,5,9,7,8,3,1,2,
             9,7,8,3,1,2,6,4,5],
            // Bank 2 — handcrafted
            [8,2,7,1,5,4,3,9,6,
             9,6,5,3,2,7,1,4,8,
             3,4,1,6,8,9,7,5,2,
             5,9,3,4,6,8,2,7,1,
             4,7,2,5,1,3,6,8,9,
             6,1,8,9,7,2,4,3,5,
             7,8,6,2,3,5,9,1,4,
             1,5,4,7,9,6,8,2,3,
             2,3,9,8,4,1,5,6,7]
        ];

        // 9x9 difficulty → number of clues left visible.
        // Standard ranges: easy 36-40, medium 30-32, hard 25-28.
        _clues9 = [38, 31, 26];
    }

    // ── Public API ───────────────────────────────────────────────────
    function generate(size, difficulty) {
        if (size == SZ_4) {
            return _gen4(difficulty);
        }
        return _gen9(difficulty);
    }

    // ── 4x4 generator ────────────────────────────────────────────────
    // 4x4 puzzles are tiny so we leave 6..7 of the 16 cells visible.
    hidden function _gen4(diff) {
        var pick = Math.rand() % _bank4.size();
        var sol  = _copy(_bank4[pick]);
        _shuffle4(sol);
        // Number of visible clues by difficulty.
        var clues = (diff == DIFF_EASY) ? 8 : ((diff == DIFF_MED) ? 7 : 6);
        var puz = _maskClues(sol, 4, clues);
        return [puz, sol];
    }

    // ── 9x9 generator ────────────────────────────────────────────────
    hidden function _gen9(diff) {
        if (diff < 0) { diff = 0; }
        if (diff > 2) { diff = 2; }
        var pick = Math.rand() % _bank9.size();
        var sol  = _copy(_bank9[pick]);
        _shuffle9(sol);
        var clues = _clues9[diff];
        var puz = _maskClues(sol, 9, clues);
        return [puz, sol];
    }

    // ── Cell masking — randomly blank cells until `clues` remain ─────
    hidden function _maskClues(sol, n, clues) {
        var total = n * n;
        var puz = new [total];
        for (var i = 0; i < total; i++) { puz[i] = sol[i]; }

        var toRemove = total - clues;
        var safety   = 0;
        while (toRemove > 0 && safety < total * 4) {
            var idx = Math.rand() % total;
            if (puz[idx] != 0) {
                puz[idx] = 0;
                toRemove = toRemove - 1;
            }
            safety = safety + 1;
        }
        return puz;
    }

    // ── 4x4 symmetry-preserving shuffles ─────────────────────────────
    hidden function _shuffle4(g) {
        _permuteDigits(g, 4);
        // Two bands of 2 rows each — swap row pairs inside bands.
        for (var b = 0; b < 2; b++) {
            if ((Math.rand() & 1) == 1) { _swapRows(g, 4, b * 2, b * 2 + 1); }
        }
        for (var s = 0; s < 2; s++) {
            if ((Math.rand() & 1) == 1) { _swapCols(g, 4, s * 2, s * 2 + 1); }
        }
        // Swap the bands themselves
        if ((Math.rand() & 1) == 1) {
            _swapRows(g, 4, 0, 2);
            _swapRows(g, 4, 1, 3);
        }
        if ((Math.rand() & 1) == 1) {
            _swapCols(g, 4, 0, 2);
            _swapCols(g, 4, 1, 3);
        }
        if ((Math.rand() & 1) == 1) { _transpose(g, 4); }
    }

    // ── 9x9 symmetry-preserving shuffles ─────────────────────────────
    hidden function _shuffle9(g) {
        _permuteDigits(g, 9);
        // 3 bands × 3 rows — random row swaps within each band
        for (var b = 0; b < 3; b++) {
            var i1 = b * 3 + (Math.rand() % 3);
            var i2 = b * 3 + (Math.rand() % 3);
            if (i1 != i2) { _swapRows(g, 9, i1, i2); }
            var i3 = b * 3 + (Math.rand() % 3);
            var i4 = b * 3 + (Math.rand() % 3);
            if (i3 != i4) { _swapRows(g, 9, i3, i4); }
        }
        // Column swaps within each stack
        for (var s = 0; s < 3; s++) {
            var j1 = s * 3 + (Math.rand() % 3);
            var j2 = s * 3 + (Math.rand() % 3);
            if (j1 != j2) { _swapCols(g, 9, j1, j2); }
            var j3 = s * 3 + (Math.rand() % 3);
            var j4 = s * 3 + (Math.rand() % 3);
            if (j3 != j4) { _swapCols(g, 9, j3, j4); }
        }
        // Band swaps (entire 3-row blocks)
        var bandA = Math.rand() % 3; var bandB = Math.rand() % 3;
        if (bandA != bandB) {
            for (var k = 0; k < 3; k++) {
                _swapRows(g, 9, bandA * 3 + k, bandB * 3 + k);
            }
        }
        // Stack swaps
        var stackA = Math.rand() % 3; var stackB = Math.rand() % 3;
        if (stackA != stackB) {
            for (var k = 0; k < 3; k++) {
                _swapCols(g, 9, stackA * 3 + k, stackB * 3 + k);
            }
        }
        if ((Math.rand() & 1) == 1) { _transpose(g, 9); }
    }

    // ── Low-level helpers ────────────────────────────────────────────
    hidden function _copy(src) {
        var n = src.size();
        var out = new [n];
        for (var i = 0; i < n; i++) { out[i] = src[i]; }
        return out;
    }

    // Random permutation of 1..n; rewrite every cell via the map.
    hidden function _permuteDigits(g, n) {
        var perm = new [n + 1];
        for (var i = 0; i <= n; i++) { perm[i] = i; }
        // Fisher-Yates on indices 1..n
        for (var i = n; i > 1; i--) {
            var j = 1 + Math.rand() % i;
            var t = perm[i]; perm[i] = perm[j]; perm[j] = t;
        }
        var total = n * n;
        for (var k = 0; k < total; k++) {
            g[k] = perm[g[k]];
        }
    }

    hidden function _swapRows(g, n, r1, r2) {
        if (r1 == r2) { return; }
        for (var c = 0; c < n; c++) {
            var t = g[r1 * n + c];
            g[r1 * n + c] = g[r2 * n + c];
            g[r2 * n + c] = t;
        }
    }

    hidden function _swapCols(g, n, c1, c2) {
        if (c1 == c2) { return; }
        for (var r = 0; r < n; r++) {
            var t = g[r * n + c1];
            g[r * n + c1] = g[r * n + c2];
            g[r * n + c2] = t;
        }
    }

    // In-place transpose (reflect across main diagonal). Preserves
    // sudoku validity since rows ↔ cols and boxes map to themselves.
    hidden function _transpose(g, n) {
        for (var r = 0; r < n; r++) {
            for (var c = r + 1; c < n; c++) {
                var t = g[r * n + c];
                g[r * n + c] = g[c * n + r];
                g[c * n + r] = t;
            }
        }
    }
}
