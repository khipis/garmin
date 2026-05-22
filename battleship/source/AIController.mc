// ═══════════════════════════════════════════════════════════════
// AIController.mc — Three difficulty levels of enemy fire control.
//
// All three difficulties share the same call surface:
//   ai.pickShot(playerGrid)         → [r, c]
//   ai.onShotResult(r, c, result, sunkShipCells)
//
// pickShot() never mutates the grid; it only inspects shot flags.
// onShotResult() is the AI's bookkeeping hook — controller must
// call it right after BattleLogic.fire() resolves.
//
// ── EASY ────────────────────────────────────────────────────────────
// Random uniform over unshot cells. No memory whatsoever.
//
// ── MEDIUM ─────────────────────────────────────────────────────────
// Maintains a list of past hits. While the list is non-empty, fires
// at one of the 4-connected adjacent unshot cells of the most
// recent hit (random pick). Once a ship is sunk, clears the list.
//
// ── HARD ───────────────────────────────────────────────────────────
// HUNT/TARGET state machine with parity hunting:
//   • HUNT  — when the hit list is empty, fire at a parity-matching
//             cell ((r+c)%2 == 0). All ships are ≥ 2 cells long, so
//             a checkerboard of half the board is guaranteed to hit
//             every ship at least once. This roughly doubles HUNT
//             efficiency over random.
//   • TARGET — when 1 hit is known, try a random unshot 4-adjacency.
//              When ≥ 2 hits are aligned, extend the line in both
//              directions until misses bound it.
// When a ship is sunk, the AI receives the exact cell list of that
// sunk ship and removes those cells from its hit memory. This
// prevents wasted shots from adjacent surviving ships being
// mistaken for the just-sunk one.
// ═══════════════════════════════════════════════════════════════

using Toybox.Math;

const AI_EASY   = 0;
const AI_MEDIUM = 1;
const AI_HARD   = 2;

class AIController {
    var difficulty;
    var _hits;       // Array of [r, c] hit cells still on a non-sunk ship
    var _lastDir;    // -1 unknown, 0 horizontal, 1 vertical — HARD line lock

    function initialize() {
        difficulty = AI_MEDIUM;
        _hits      = [];
        _lastDir   = -1;
    }

    function setDifficulty(d) {
        difficulty = d;
        reset();
    }

    function reset() {
        _hits    = [];
        _lastDir = -1;
    }

    // ── Public entry: choose where to fire ──────────────────────────
    function pickShot(grid) {
        if (difficulty == AI_EASY) { return _randomShot(grid); }

        // MEDIUM + HARD: drain active hit memory first
        var t = _pickFromHits(grid);
        if (t != null) { return t; }

        // HUNT phase
        if (difficulty == AI_HARD) { return _huntParity(grid); }
        return _randomShot(grid);
    }

    // ── Public entry: feed back the resolved shot ───────────────────
    function onShotResult(r, c, result, sunkShipCells) {
        if (difficulty == AI_EASY) { return; }
        if (!result.hit) { return; }

        if (result.sunkId >= 0 && sunkShipCells != null) {
            // Remove every cell of the just-sunk ship from memory.
            _hits = _removeCells(_hits, sunkShipCells);
            // If hit memory is now empty, drop the line lock; else
            // re-evaluate direction based on remaining hits.
            if (_hits.size() < 2) { _lastDir = -1; }
            return;
        }

        // Non-sunk hit: append + try to lock direction
        _hits.add([r, c]);
        if (_lastDir < 0 && _hits.size() >= 2) {
            var a = _hits[_hits.size() - 2];
            if (a[0] == r)      { _lastDir = 0; } // horizontal line
            else if (a[1] == c) { _lastDir = 1; } // vertical line
        }
    }

    // ── HUNT helpers ────────────────────────────────────────────────
    hidden function _randomShot(grid) {
        var candidates = _collectUnshot(grid, false);
        if (candidates.size() == 0) { return [0, 0]; }
        return candidates[Math.rand() % candidates.size()];
    }

    hidden function _huntParity(grid) {
        var parity = _collectUnshot(grid, true);
        if (parity.size() > 0) {
            return parity[Math.rand() % parity.size()];
        }
        // Fallback to any unshot cell (parity board is exhausted).
        return _randomShot(grid);
    }

    hidden function _collectUnshot(grid, parityOnly) {
        var out = [];
        for (var r = 0; r < GRID_SIZE; r++) {
            for (var c = 0; c < GRID_SIZE; c++) {
                if (grid.isShot(r, c)) { continue; }
                if (parityOnly && ((r + c) % 2 != 0)) { continue; }
                out.add([r, c]);
            }
        }
        return out;
    }

    // ── TARGET helpers ──────────────────────────────────────────────
    hidden function _pickFromHits(grid) {
        if (_hits.size() == 0) { return null; }

        // Locked-direction extension
        if (_lastDir >= 0 && _hits.size() >= 2) {
            var aligned = _alignedSegmentThroughLast();
            if (aligned.size() >= 2) {
                var ext = _extendAlongDir(grid, aligned, _lastDir);
                if (ext != null) { return ext; }
                // Both ends exhausted; the line is sandwiched by misses.
                // Drop the line lock — remaining hits probably belong to
                // a different ship (adjacent placements).
                _lastDir = -1;
            }
        }

        // 4-adjacency probe from latest hits (newest first)
        for (var i = _hits.size() - 1; i >= 0; i--) {
            var h = _hits[i];
            var adj = _firstValidAdj(grid, h[0], h[1]);
            if (adj != null) { return adj; }
        }
        return null;
    }

    // Collect hits aligned with the locked direction, sharing the
    // last hit's fixed coordinate.
    hidden function _alignedSegmentThroughLast() {
        var last = _hits[_hits.size() - 1];
        var fixed = (_lastDir == 0) ? last[0] : last[1];
        var aligned = [];
        for (var i = 0; i < _hits.size(); i++) {
            var h = _hits[i];
            var hf = (_lastDir == 0) ? h[0] : h[1];
            if (hf == fixed) { aligned.add(h); }
        }
        return aligned;
    }

    // Find min/max along the variable axis; return the first unshot
    // cell off either end (random end-order to avoid bias).
    hidden function _extendAlongDir(grid, aligned, dir) {
        var fixed = (dir == 0) ? aligned[0][0] : aligned[0][1];
        var minV = 9999;
        var maxV = -1;
        for (var i = 0; i < aligned.size(); i++) {
            var v = (dir == 0) ? aligned[i][1] : aligned[i][0];
            if (v < minV) { minV = v; }
            if (v > maxV) { maxV = v; }
        }
        var first = (Math.rand() % 2 == 0) ? (maxV + 1) : (minV - 1);
        var second = (first == maxV + 1) ? (minV - 1) : (maxV + 1);
        var probes = [first, second];
        for (var k = 0; k < 2; k++) {
            var r;
            var c;
            if (dir == 0) { r = fixed; c = probes[k]; }
            else          { r = probes[k]; c = fixed; }
            if (GridManager.inBoundsRC(r, c) && !grid.isShot(r, c)) {
                return [r, c];
            }
        }
        return null;
    }

    hidden function _firstValidAdj(grid, r, c) {
        var dr = [-1, 1,  0, 0];
        var dc = [ 0, 0, -1, 1];
        var order = [0, 1, 2, 3];
        // Fisher-Yates shuffle so probe order doesn't bias one side
        for (var i = 3; i > 0; i--) {
            var j = Math.rand() % (i + 1);
            var t = order[i]; order[i] = order[j]; order[j] = t;
        }
        for (var k = 0; k < 4; k++) {
            var o = order[k];
            var rr = r + dr[o];
            var cc = c + dc[o];
            if (GridManager.inBoundsRC(rr, cc) && !grid.isShot(rr, cc)) {
                return [rr, cc];
            }
        }
        return null;
    }

    // Filter helper: returns a copy of `list` with every [r, c] that
    // appears in `remove` excluded.
    hidden function _removeCells(list, remove) {
        var out = [];
        for (var i = 0; i < list.size(); i++) {
            var h = list[i];
            var drop = false;
            for (var j = 0; j < remove.size(); j++) {
                var rc = remove[j];
                if (h[0] == rc[0] && h[1] == rc[1]) { drop = true; break; }
            }
            if (!drop) { out.add(h); }
        }
        return out;
    }
}
