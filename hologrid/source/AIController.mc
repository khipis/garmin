// ═══════════════════════════════════════════════════════════════
// AIController.mc — Blocker behaviours.
//
// HG_BL_STATIC   never moves
// HG_BL_MOVING   picks a random walkable neighbour each turn
// HG_BL_PREDICT  steps toward the player along the Manhattan-best
//                walkable neighbour (greedy chase)
//
// Blockers respect walls and other blockers — they never pile up.
// ═══════════════════════════════════════════════════════════════

using Toybox.Math;

class Blocker {
    var r;
    var c;
    var type;
    function initialize(rr, cc, t) { r = rr; c = cc; type = t; }
}

class AIController {

    static function _cellTaken(blockers, except, r, c) {
        for (var i = 0; i < blockers.size(); i++) {
            if (i == except) { continue; }
            var b = blockers[i];
            if (b.r == r && b.c == c) { return true; }
        }
        return false;
    }

    // Drive all blockers one step.  `player` is the post-move player
    // position so predictive blockers chase the player's *new* tile.
    static function step(blockers, grid, player) {
        for (var i = 0; i < blockers.size(); i++) {
            var b = blockers[i];
            if (b.type == HG_BL_STATIC) { continue; }
            if (b.type == HG_BL_MOVING) {
                _stepRandom(b, i, blockers, grid);
            } else {
                _stepGreedy(b, i, blockers, grid, player);
            }
        }
    }

    hidden static function _stepRandom(b, idx, blockers, grid) {
        var legal = [];
        for (var d = 0; d < 4; d++) {
            var de = GridSystem.dirDelta(d);
            var nr = b.r + de[0]; var nc = b.c + de[1];
            if (!grid.isWalkable(nr, nc)) { continue; }
            if (_cellTaken(blockers, idx, nr, nc)) { continue; }
            legal.add([nr, nc]);
        }
        if (legal.size() == 0) { return; }
        var pick = legal[Math.rand() % legal.size()];
        b.r = pick[0]; b.c = pick[1];
    }

    hidden static function _stepGreedy(b, idx, blockers, grid, player) {
        var best = -1;
        var bd   = 999999;
        var br = b.r; var bc = b.c;
        for (var d = 0; d < 4; d++) {
            var de = GridSystem.dirDelta(d);
            var nr = b.r + de[0]; var nc = b.c + de[1];
            if (!grid.isWalkable(nr, nc)) { continue; }
            if (_cellTaken(blockers, idx, nr, nc)) { continue; }
            var dist = (nr - player.r).abs() + (nc - player.c).abs();
            if (dist < bd) { bd = dist; best = d; br = nr; bc = nc; }
        }
        if (best >= 0) { b.r = br; b.c = bc; }
    }

    static function huntersHitPlayer(blockers, player) {
        for (var i = 0; i < blockers.size(); i++) {
            var b = blockers[i];
            if (b.r == player.r && b.c == player.c) { return true; }
        }
        return false;
    }
}
