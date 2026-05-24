// ═══════════════════════════════════════════════════════════════
// GravityEngine.mc — Per-tick collapse simulation.
//
// One pass walks the grid bottom-to-top and drops every "loose"
// block (rock/ore/gem) one cell if the cell below is empty.
// `settle()` keeps stepping until the grid is stable, capped at
// `maxIter` to keep the watchdog happy.
//
// Returns true if the player was crushed at any point.
// ═══════════════════════════════════════════════════════════════

class GravityEngine {

    static function step(grid, pr, pc) {
        var moved   = false;
        var crushed = false;
        for (var r = grid.h - 2; r >= 0; r--) {
            for (var c = 0; c < grid.w; c++) {
                var t = grid.get(r, c);
                if (!GridManager.isFalling(t)) { continue; }
                if (grid.get(r + 1, c) != GM_EMPTY) { continue; }
                grid.set(r, c, GM_EMPTY);
                grid.set(r + 1, c, t);
                moved = true;
                if (r + 1 == pr && c == pc) { crushed = true; }
            }
        }
        return [!moved, crushed];
    }

    static function settle(grid, pr, pc, maxIter) {
        for (var i = 0; i < maxIter; i++) {
            var s = step(grid, pr, pc);
            if (s[1]) { return true; }
            if (s[0]) { return false; }
        }
        return false;
    }

    // Cause player to fall (one cell) if there is nothing supporting
    // them.  Returns the new player row (may equal old row if no
    // fall happens), and a `crushed` flag if they hit a wall floor.
    static function applyPlayerGravity(grid, pr, pc, maxFall) {
        var fell = false;
        var r = pr;
        for (var i = 0; i < maxFall; i++) {
            if (grid.get(r + 1, pc) == GM_EMPTY) {
                r = r + 1; fell = true;
            } else { break; }
        }
        // If r == h-1 (the wall row), player is crushed against the
        // bottom — but in our grid h-1 is always the bottom wall, so
        // landing on row h-2 is the actual "win the level" floor.
        return [r, fell];
    }
}
