// ═══════════════════════════════════════════════════════════════
// LevelGenerator.mc — Procedural Lights Out boards.
//
// Solvability strategy:
//
//   Start from all-OFF and apply K random "press" operations.
//   Any state reachable from all-OFF by presses is — by symmetry
//   of the press operator — solvable by pressing the SAME set of
//   cells again.  This gives us:
//
//     • guaranteed-solvable boards
//     • a known canonical solve sequence (used by the hint system)
//     • a deterministic puzzle per (seed, n, k)
//
// We use a tiny LCG so two players seeded with the same level
// number get the exact same starting state.
//
// Level layout (50 total predefined levels):
//
//   1..17   3×3, K = 2..6      (Easy)
//   18..34  4×4, K = 3..9      (Medium)
//   35..50  5×5, K = 4..12     (Hard)
//
// `generate(level)` returns a record:
//   { n, startCells (flat 0/1), solvePresses (flat list of indices) }
//
// Daily mode: `generateDaily(seed, diffN)` uses the day-of-year
// as seed for a board of size diffN (3, 4 or 5).
// ═══════════════════════════════════════════════════════════════

const LO_TOTAL_LEVELS = 50;
const LO_EASY_LAST    = 17;        // levels 1..17
const LO_MED_LAST     = 34;        // 18..34
// Hard 35..50

class LevelGenerator {

    static function gridSizeForLevel(level) {
        if (level <= LO_EASY_LAST) { return 3; }
        if (level <= LO_MED_LAST)  { return 4; }
        return 5;
    }

    // Press-count grows with level inside each bucket.
    static function pressCountForLevel(level) {
        if (level <= LO_EASY_LAST) {
            // 2..6
            return 2 + ((level - 1) * 5 / LO_EASY_LAST);
        }
        if (level <= LO_MED_LAST) {
            var i = level - LO_EASY_LAST - 1;
            var span = LO_MED_LAST - LO_EASY_LAST;
            return 3 + (i * 7 / span);   // 3..9
        }
        var i = level - LO_MED_LAST - 1;
        var span = LO_TOTAL_LEVELS - LO_MED_LAST;
        return 4 + (i * 9 / span);       // 4..12
    }

    static function gridSizeForDiff(diff) {
        if (diff == 0) { return 3; }
        if (diff == 1) { return 4; }
        return 5;
    }

    // ── LCG (Numerical Recipes-style; identical to DiceRoyale). ─
    hidden static function _lcg(seed) {
        return ((seed * 1103515245) + 12345) & 0x7FFFFFFF;
    }
    hidden static function _rnd(state, mod) {
        return state % mod;
    }

    // Procedurally generate a board by pressing `presses` random
    // distinct cells.  Returns an array:
    //   [n, startCellsFlat, solvePressesFlat]
    // Knuth integer hash multiplier (golden-ratio prime), stored as
    // signed int32 to satisfy Monkey C's Number range.
    hidden static var SEED_MIX = -1640531527;   // = 2654435769 - 2^32

    static function generateForLevel(level) {
        var n = gridSizeForLevel(level);
        var k = pressCountForLevel(level);
        var seed = (level * SEED_MIX) & 0x7FFFFFFF;
        return _generate(n, k, seed);
    }

    static function generateDaily(daySeed, diff) {
        var n = gridSizeForDiff(diff);
        var k = (diff == 0) ? 4 : ((diff == 1) ? 7 : 10);
        var seed = (daySeed * SEED_MIX) & 0x7FFFFFFF;
        if (seed == 0) { seed = 1; }
        return _generate(n, k, seed);
    }

    hidden static function _generate(n, k, seed) {
        var grid    = new [n * n];
        var presses = [];
        for (var i = 0; i < n * n; i++) { grid[i] = 0; }

        var sz = n * n;
        var state = seed;
        if (state == 0) { state = 1; }
        // Use a Set-like list to keep press positions unique (optional;
        // duplicates would just be no-ops since a press is its own
        // inverse).  Uniqueness ensures the board is "interesting".
        var used = new [sz];
        for (var i = 0; i < sz; i++) { used[i] = 0; }

        var picked = 0;
        var safety = 0;
        while (picked < k && safety < 200) {
            state = _lcg(state);
            var p = _rnd(state, sz);
            if (used[p] == 0) {
                used[p] = 1;
                presses.add(p);
                _pressOnFlat(grid, n, p);
                picked = picked + 1;
            }
            safety = safety + 1;
        }
        return [n, grid, presses];
    }

    // Apply a press to a flat grid (helper used by _generate and by
    // the hint system).
    hidden static function _pressOnFlat(g, n, p) {
        var r = p / n;
        var c = p % n;
        _flip(g, n, r,     c);
        _flip(g, n, r - 1, c);
        _flip(g, n, r + 1, c);
        _flip(g, n, r,     c - 1);
        _flip(g, n, r,     c + 1);
    }
    hidden static function _flip(g, n, r, c) {
        if (r < 0 || c < 0 || r >= n || c >= n) { return; }
        var i = r * n + c;
        g[i] = (g[i] != 0) ? 0 : 1;
    }
}
