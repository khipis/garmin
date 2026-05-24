// ═══════════════════════════════════════════════════════════════
// LevelGenerator.mc — Procedural Hologrid level builder.
//
// Supports levels 1..HG_MAX_LEVEL (30).
//
// Every level is GUARANTEED solvable: after dropping random walls
// we carve an L-shaped corridor from spawn to exit, then clear a
// 2×2 pocket around each so the player and the goal have room to
// breathe.  Blockers are then placed on remaining FLOOR tiles
// outside both pockets, so they can never spawn glued to the
// player.
//
// Difficulty knobs scale smoothly with `level` (capped):
//   wallPct      8  →  32     (+1/level)
//   blockerCnt   2  →  8      (+1 per ~4 levels)
//   predictPct   5  →  80     (~+3/level)
//   movingPct    fills the gap between predict and static so
//                lower levels are mostly STATIC + MOVING, while
//                later levels are mostly PREDICT.
//
// Spawn / exit also cycle around the four corners every level
// so two adjacent levels never feel identical.
//
// Returns:
//   [grid, playerSpawn(r,c), exit(r,c), blockerSpecs]
//   where each spec is [r, c, type].
// ═══════════════════════════════════════════════════════════════

using Toybox.Math;

const HG_GRID_N    = 10;
const HG_MAX_LEVEL = 30;

const HG_BL_STATIC  = 0;
const HG_BL_MOVING  = 1;
const HG_BL_PREDICT = 2;

class LevelGenerator {

    // ── Public entry ────────────────────────────────────────────
    static function build(level) {
        if (level < 1)              { level = 1;             }
        if (level > HG_MAX_LEVEL)   { level = HG_MAX_LEVEL;  }
        var n = HG_GRID_N;
        var g = new GridSystem(n);

        // Difficulty knobs (linear scales, capped).
        var wallPct = 8 + (level - 1);
        if (wallPct > 32) { wallPct = 32; }

        var blkCnt  = 2 + (level - 1) / 4;
        if (blkCnt > 8) { blkCnt = 8; }

        var predPct = 5 + (level - 1) * 3;
        if (predPct > 80) { predPct = 80; }

        var movPct  = 60 - level;
        if (movPct < 15) { movPct = 15; }

        // 1. Border walls + random interior walls.
        _initBorderAndWalls(g, n, wallPct);

        // 2. Pick spawn / exit corners (rotates every level).
        var corners = _cornersForLevel(level, n);
        var sr = corners[0]; var sc = corners[1];
        var er = corners[2]; var ec = corners[3];

        // 3. Clear 2×2 pockets so the player isn't trapped at spawn
        //    and the exit can be approached.
        _clearPocket(g, sr, sc);
        _clearPocket(g, er, ec);

        // 4. Carve an L-shaped corridor — alternating style means
        //    even levels feel different from odd ones at the same
        //    spawn/exit pair.
        _carvePath(g, sr, sc, er, ec, (level - 1) % 2);

        // 5. Mark exit tile.
        g.set(er, ec, HG_EXIT);
        g.exitR = er; g.exitC = ec;

        // 6. Place blockers (skip pockets, skip duplicates).
        var blockers = _placeBlockers(g, n, blkCnt, predPct, movPct,
                                       sr, sc, er, ec);

        return [g, [sr, sc], [er, ec], blockers];
    }

    // ── Helpers (static) ────────────────────────────────────────

    hidden static function _initBorderAndWalls(g, n, wallPct) {
        for (var r = 0; r < n; r++) {
            for (var c = 0; c < n; c++) {
                if (r == 0 || r == n - 1 || c == 0 || c == n - 1) {
                    g.set(r, c, HG_WALL);
                } else {
                    g.set(r, c, HG_FLOOR);
                }
            }
        }
        for (var r2 = 2; r2 < n - 2; r2++) {
            for (var c2 = 2; c2 < n - 2; c2++) {
                if (Math.rand() % 100 < wallPct) {
                    g.set(r2, c2, HG_WALL);
                }
            }
        }
    }

    // Four-corner rotation.  `(level-1) % 4` picks one of the
    // diagonal pairs; spawn is always opposite the exit.
    hidden static function _cornersForLevel(level, n) {
        var idx = (level - 1) % 4;
        if (idx == 0) { return [1,     1,     n - 2, n - 2]; }
        if (idx == 1) { return [1,     n - 2, n - 2, 1    ]; }
        if (idx == 2) { return [n - 2, 1,     1,     n - 2]; }
        return        [n - 2, n - 2, 1,     1    ];
    }

    // Clear a 2×2 pocket of FLOOR around (r, c) toward the interior.
    hidden static function _clearPocket(g, r, c) {
        var dr = (r <= 1) ? 1 : -1;
        var dc = (c <= 1) ? 1 : -1;
        g.set(r,         c,         HG_FLOOR);
        g.set(r + dr,    c,         HG_FLOOR);
        g.set(r,         c + dc,    HG_FLOOR);
        g.set(r + dr,    c + dc,    HG_FLOOR);
    }

    // True if (r, c) lies inside the 2×2 pocket of corner (pr, pc).
    hidden static function _inPocket(r, c, pr, pc) {
        var dr = (pr <= 1) ? 1 : -1;
        var dc = (pc <= 1) ? 1 : -1;
        if (r != pr && r != pr + dr) { return false; }
        if (c != pc && c != pc + dc) { return false; }
        return true;
    }

    // Carve an L corridor from (sr,sc) to (er,ec).
    //   style 0: along row sr first, then column ec.
    //   style 1: along column sc first, then row er.
    // All carved cells become FLOOR (overwriting any earlier wall).
    hidden static function _carvePath(g, sr, sc, er, ec, style) {
        if (style == 0) {
            var ca = sc; var cb = ec;
            if (cb < ca) { ca = ec; cb = sc; }
            for (var c = ca; c <= cb; c++) { g.set(sr, c, HG_FLOOR); }
            var ra = sr; var rb = er;
            if (rb < ra) { ra = er; rb = sr; }
            for (var r = ra; r <= rb; r++) { g.set(r, ec, HG_FLOOR); }
        } else {
            var ra2 = sr; var rb2 = er;
            if (rb2 < ra2) { ra2 = er; rb2 = sr; }
            for (var r2 = ra2; r2 <= rb2; r2++) { g.set(r2, sc, HG_FLOOR); }
            var ca2 = sc; var cb2 = ec;
            if (cb2 < ca2) { ca2 = ec; cb2 = sc; }
            for (var c2 = ca2; c2 <= cb2; c2++) { g.set(er, c2, HG_FLOOR); }
        }
    }

    hidden static function _placeBlockers(g, n, blkCnt, predPct, movPct,
                                          sr, sc, er, ec) {
        var blockers = [];
        var guard = 0;
        while (blockers.size() < blkCnt && guard < 250) {
            guard = guard + 1;
            var rr = 1 + Math.rand() % (n - 2);
            var cc = 1 + Math.rand() % (n - 2);
            // Don't drop a blocker on (or adjacent to) spawn / exit.
            if (_inPocket(rr, cc, sr, sc)) { continue; }
            if (_inPocket(rr, cc, er, ec)) { continue; }
            if (g.get(rr, cc) != HG_FLOOR) { continue; }
            var dup = false;
            for (var i = 0; i < blockers.size(); i++) {
                if (blockers[i][0] == rr && blockers[i][1] == cc) { dup = true; break; }
            }
            if (dup) { continue; }
            var typ  = HG_BL_STATIC;
            var roll = Math.rand() % 100;
            if (roll < predPct) {
                typ = HG_BL_PREDICT;
            } else if (roll < predPct + movPct) {
                typ = HG_BL_MOVING;
            }
            blockers.add([rr, cc, typ]);
        }
        return blockers;
    }
}
