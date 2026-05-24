// ═══════════════════════════════════════════════════════════════
// PhysicsSim.mc — Boulder-Dash gravity & rolling rules.
//
// One step iterates the grid bottom-up.  For each falling-capable
// tile (rock or diamond) it does:
//
//   1. If the cell directly below is EMPTY:
//        – If a firefly stands there, the firefly is killed and the
//          rock/diamond continues to occupy that cell.
//        – If the player stands there, the player is crushed.
//        – Otherwise the tile falls one cell down.
//
//   2. Else if the cell below is rounded-top (ROCK / DIAMOND / BRICK)
//      the tile may ROLL sideways:
//        – Prefer rolling LEFT if both (r, c-1) and (r+1, c-1) are
//          EMPTY (or firefly / player as in 1).
//        – Else try ROLLING RIGHT under the same rule.
//
// `settle()` repeats `step()` until no movement occurs or `maxIter`
// passes are exhausted.  Each step records whether the player was
// crushed and returns the flag up the chain.
// ═══════════════════════════════════════════════════════════════

class PhysicsSim {

    // Returns [stable, crushed].  `enemies` is the firefly list — any
    // firefly that lands beneath a falling stone is removed.
    static function step(grid, playerR, playerC, enemies) {
        var moved   = false;
        var crushed = false;

        for (var r = grid.h - 2; r >= 0; r--) {
            for (var c = 0; c < grid.w; c++) {
                var t = grid.get(r, c);
                if (t != TC_ROCK && t != TC_DIAMOND) { continue; }

                // 1) Fall straight down if possible.
                var below = grid.get(r + 1, c);
                if (_isFallTarget(below)) {
                    var hitFirefly = _killFireflyAt(enemies, r + 1, c);
                    var hitPlayer  = (r + 1 == playerR && c == playerC);
                    grid.set(r, c, TC_EMPTY);
                    grid.set(r + 1, c, t);
                    moved = true;
                    if (hitPlayer)  { crushed = true; }
                    if (hitFirefly) { /* firefly removed by helper */ }
                    continue;
                }

                // 2) Roll sideways off a rounded-top tile.
                if (!GridManager.isRoundTop(below)) { continue; }

                // Roll left?
                if (_isFallTarget(grid.get(r, c - 1)) &&
                    _isFallTarget(grid.get(r + 1, c - 1))) {
                    grid.set(r, c, TC_EMPTY);
                    grid.set(r, c - 1, t);
                    moved = true;
                    continue;
                }
                // Roll right?
                if (_isFallTarget(grid.get(r, c + 1)) &&
                    _isFallTarget(grid.get(r + 1, c + 1))) {
                    grid.set(r, c, TC_EMPTY);
                    grid.set(r, c + 1, t);
                    moved = true;
                    continue;
                }
            }
        }
        return [!moved, crushed];
    }

    // Iterate until stable or `maxIter` reached.  Returns true if
    // the player got crushed at any point in the cascade.
    static function settle(grid, playerR, playerC, enemies, maxIter) {
        for (var i = 0; i < maxIter; i++) {
            var res = step(grid, playerR, playerC, enemies);
            if (res[1]) { return true; }
            if (res[0]) { return false; }
        }
        return false;
    }

    // A "fall target" is an empty cell, or one occupied by the
    // player / a firefly (rocks happily land on them — crushing or
    // squashing as the case may be).
    hidden static function _isFallTarget(t) { return t == TC_EMPTY; }

    // If a firefly stands at (r,c) it dies — pop from the list.
    // Returns true if a firefly was killed.
    hidden static function _killFireflyAt(enemies, r, c) {
        if (enemies == null) { return false; }
        for (var i = 0; i < enemies.size(); i++) {
            var e = enemies[i];
            if (e.alive && e.r == r && e.c == c) {
                e.alive = false;
                return true;
            }
        }
        return false;
    }
}
