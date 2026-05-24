// ═══════════════════════════════════════════════════════════════
// ValidationEngine.mc — Win + per-cell error checks.
//
// Win condition (classic Akari rules):
//   1. Every white cell is illuminated.
//   2. No two bulbs see each other along their row/column without
//      a wall in between.
//   3. Every numbered wall has *exactly* the specified number of
//      bulbs orthogonally adjacent.
//
// Error checks (used when the "Errs" menu option is ON):
//   cellError(grid, lit, r, c) returns true when a player-placed
//   bulb at (r,c) is provably wrong:
//     - it sees another bulb, OR
//     - it would push a numbered-wall neighbour OVER its limit.
//
//   Numbered-wall errors are surfaced via wallExceeds(...).
// ═══════════════════════════════════════════════════════════════

class ValidationEngine {

    static function isSolved(grid, lit) {
        var n = grid.n;
        // (1) every white cell lit?
        for (var i = 0; i < n * n; i++) {
            if (grid.cells[i] == 0 && lit[i] == 0) { return false; }
        }
        // (2) no two bulbs see each other?
        for (var r = 0; r < n; r++) {
            for (var c = 0; c < n; c++) {
                if (grid.markAt(r, c) != AK_BULB) { continue; }
                if (IlluminationEngine.bulbsSeeEachOther(grid, r, c)) {
                    return false;
                }
            }
        }
        // (3) numbered walls satisfied?
        for (var r = 0; r < n; r++) {
            for (var c = 0; c < n; c++) {
                var num = grid.wallNumber(r, c);
                if (num < 0) { continue; }
                if (IlluminationEngine.adjacentBulbCount(grid, r, c) != num) {
                    return false;
                }
            }
        }
        return true;
    }

    // Is the bulb at (r,c) "clearly wrong" right now?
    static function bulbError(grid, r, c) {
        if (grid.markAt(r, c) != AK_BULB) { return false; }
        if (IlluminationEngine.bulbsSeeEachOther(grid, r, c)) { return true; }
        // Check each orthogonally-adjacent wall — if any has a
        // number and the current bulb count exceeds it, that's a
        // local violation.
        return _adjWallExceeded(grid, r - 1, c)
            || _adjWallExceeded(grid, r + 1, c)
            || _adjWallExceeded(grid, r, c - 1)
            || _adjWallExceeded(grid, r, c + 1);
    }

    hidden static function _adjWallExceeded(grid, r, c) {
        if (!grid.inBounds(r, c)) { return false; }
        var num = grid.wallNumber(r, c);
        if (num < 0) { return false; }
        return IlluminationEngine.adjacentBulbCount(grid, r, c) > num;
    }

    // Used by the UI: should this numbered wall be drawn in red?
    static function wallError(grid, r, c) {
        var num = grid.wallNumber(r, c);
        if (num < 0) { return false; }
        return IlluminationEngine.adjacentBulbCount(grid, r, c) > num;
    }
}
