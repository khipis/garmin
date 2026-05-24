// ═══════════════════════════════════════════════════════════════
// IlluminationEngine.mc — Compute which white cells are lit.
//
// Pure stateless helper.  We call it once per move (NOT once per
// frame) from the controller and cache the result in
// `controller._lit` so the UI's per-cell rendering is O(1).
//
// Algorithm:
//   1. lit[i] = false for all i
//   2. For each cell with a bulb: mark the bulb cell + sweep the 4
//      cardinal rays outward.  A ray stops at the first wall (any
//      `cells[i] != 0`); white cells along the ray become lit.
//
// Complexity: O(B · n) where B is bulb count.  For 6×6 / 7×7 this
// is well under 100 iterations — comfortably below the watchdog
// threshold even on the slowest Garmin VMs.
// ═══════════════════════════════════════════════════════════════

class IlluminationEngine {

    // Returns a fresh Number[n*n] where 1 means "this white cell is
    // illuminated by some bulb (including itself)".  Wall cells are
    // always 0 in the output — irrelevant for them.
    static function compute(grid) {
        var n = grid.n;
        var lit = new [n * n];
        for (var i = 0; i < n * n; i++) { lit[i] = 0; }

        for (var r = 0; r < n; r++) {
            for (var c = 0; c < n; c++) {
                if (grid.markAt(r, c) != AK_BULB) { continue; }
                lit[grid.idx(r, c)] = 1;
                _ray(grid, lit, r, c, -1,  0);
                _ray(grid, lit, r, c,  1,  0);
                _ray(grid, lit, r, c,  0, -1);
                _ray(grid, lit, r, c,  0,  1);
            }
        }
        return lit;
    }

    hidden static function _ray(grid, lit, r, c, dr, dc) {
        var rr = r + dr;
        var cc = c + dc;
        while (grid.inBounds(rr, cc) && !grid.isWall(rr, cc)) {
            lit[grid.idx(rr, cc)] = 1;
            rr = rr + dr;
            cc = cc + dc;
        }
    }

    // Does this bulb "see" another bulb along its row or column
    // without a wall between?  Used by the error-highlight feature
    // and by the win check.
    static function bulbsSeeEachOther(grid, r, c) {
        return _seesBulb(grid, r, c, -1,  0)
            || _seesBulb(grid, r, c,  1,  0)
            || _seesBulb(grid, r, c,  0, -1)
            || _seesBulb(grid, r, c,  0,  1);
    }

    hidden static function _seesBulb(grid, r, c, dr, dc) {
        var rr = r + dr;
        var cc = c + dc;
        while (grid.inBounds(rr, cc) && !grid.isWall(rr, cc)) {
            if (grid.markAt(rr, cc) == AK_BULB) { return true; }
            rr = rr + dr;
            cc = cc + dc;
        }
        return false;
    }

    // Count of adjacent bulbs around a wall cell.
    static function adjacentBulbCount(grid, r, c) {
        var k = 0;
        if (_isBulbAt(grid, r - 1, c)) { k = k + 1; }
        if (_isBulbAt(grid, r + 1, c)) { k = k + 1; }
        if (_isBulbAt(grid, r, c - 1)) { k = k + 1; }
        if (_isBulbAt(grid, r, c + 1)) { k = k + 1; }
        return k;
    }

    hidden static function _isBulbAt(grid, r, c) {
        if (!grid.inBounds(r, c)) { return false; }
        return grid.markAt(r, c) == AK_BULB;
    }
}
