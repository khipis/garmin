// ═══════════════════════════════════════════════════════════════
// BattleLogic.mc — Pure functions: resolve a shot + auto-place a fleet.
//
// Stateless utility class. Keeps Grid/ShipManager unaware of the
// rules of Battleship; both stores can be reused for any naval-style
// game by swapping out BattleLogic.
//
// ── fire(grid, ships, r, c) ────────────────────────────────────────
// Returns a ShotResult:
//   • alreadyShot  — true if the cell was already fired on (no-op)
//   • hit          — true if the shot landed on a ship cell
//   • sunkId       — ship id that just sank, or -1
//
// ── autoPlace(grid, ships) ─────────────────────────────────────────
// Random-uniform placement that respects bounds and the no-overlap
// rule. Tries up to 200 random positions per ship, falls back to a
// deterministic linear scan if random fails, so it ALWAYS succeeds.
// ═══════════════════════════════════════════════════════════════

using Toybox.Math;

class ShotResult {
    var hit;
    var sunkId;
    var alreadyShot;
    function initialize() {
        hit = false;
        sunkId = -1;
        alreadyShot = false;
    }
}

class BattleLogic {

    // Resolve a single shot. Mutates `grid` and `ships`.
    //
    // Soviet-rules extension: when a hit sinks a ship, the rule
    // "ships cannot touch" tells us every neighbour of every cell of
    // the sunk ship MUST be water. We auto-mark that 8-neighbour halo
    // as CELL_SHOT so the player can see it as "known empty" dots
    // without having to spend turns probing it. The AI benefits
    // identically — it consults `grid.isShot()` to skip those cells.
    static function fire(grid, ships, r, c) {
        var res = new ShotResult();
        if (grid.isShot(r, c)) {
            res.alreadyShot = true;
            return res;
        }
        grid.markShot(r, c);
        if (grid.hasShip(r, c)) {
            res.hit = true;
            var sid = grid.getShipId(r, c);
            if (ships.applyHit(sid)) {
                res.sunkId = sid;
                _markShipHalo(grid, sid);
            }
        }
        return res;
    }

    // Place every ship in `SHIP_LENS` onto `grid`, resetting both.
    // Bump attempt budget — the no-touch rule on a 10×10 with 10
    // ships is much denser than the classic ruleset.
    static function autoPlace(grid, ships) {
        grid.clear();
        ships.reset();
        for (var id = 0; id < NUM_SHIPS; id++) {
            var len = SHIP_LENS[id];
            if (!_tryRandomPlace(grid, id, len, 600)) {
                _deterministicPlace(grid, id, len);
            }
        }
    }

    // Mark the 8-neighbour halo of every cell in ship `sid` as
    // CELL_SHOT (a "known empty" miss). Skips cells already shot and
    // any cell carrying a ship (defensive — shouldn't happen under
    // the no-touch rule, but cheap to check).
    hidden static function _markShipHalo(grid, sid) {
        var cells = grid.cellsForShip(sid);
        for (var i = 0; i < cells.size(); i++) {
            var rc = cells[i];
            for (var dr = -1; dr <= 1; dr++) {
                for (var dc = -1; dc <= 1; dc++) {
                    if (dr == 0 && dc == 0) { continue; }
                    var nr = rc[0] + dr;
                    var nc = rc[1] + dc;
                    if (!GridManager.inBoundsRC(nr, nc)) { continue; }
                    if (grid.hasShip(nr, nc))            { continue; }
                    if (grid.isShot(nr, nc))             { continue; }
                    grid.markShot(nr, nc);
                }
            }
        }
    }

    // ── private helpers ─────────────────────────────────────────────
    hidden static function _tryRandomPlace(grid, id, len, attempts) {
        for (var t = 0; t < attempts; t++) {
            var horizontal = (Math.rand() % 2) == 0;
            var maxR = horizontal ? GRID_SIZE : (GRID_SIZE - len + 1);
            var maxC = horizontal ? (GRID_SIZE - len + 1) : GRID_SIZE;
            if (maxR <= 0 || maxC <= 0) { continue; }
            var r = Math.rand() % maxR;
            var c = Math.rand() % maxC;
            if (grid.canPlace(r, c, len, horizontal)) {
                grid.placeShip(r, c, len, horizontal, id);
                return true;
            }
        }
        return false;
    }

    hidden static function _deterministicPlace(grid, id, len) {
        for (var orientations = 0; orientations < 2; orientations++) {
            var horizontal = (orientations == 0);
            for (var r = 0; r < GRID_SIZE; r++) {
                for (var c = 0; c < GRID_SIZE; c++) {
                    if (grid.canPlace(r, c, len, horizontal)) {
                        grid.placeShip(r, c, len, horizontal, id);
                        return;
                    }
                }
            }
        }
    }
}
