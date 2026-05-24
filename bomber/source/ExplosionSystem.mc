// ═══════════════════════════════════════════════════════════════
// ExplosionSystem.mc — Cross-pattern flames + decay timer.
//
// A flame is a [r, c, msLeft] entry (≈300 ms visible).  Ignite()
// expands a flame from the bomb tile in the four cardinal
// directions up to `range`, stopping on the first wall or after
// destroying a single breakable block (classic Bomberman).  Flames
// also damage enemies and the player — those checks live in
// GameController which simply asks `isFlameAt(r,c)` each tick.
//
// Bomb chain reactions:
//   When a flame reaches a tile occupied by another bomb, that
//   bomb's fuse is set to 0 via BombSystem.igniteAt(); it'll
//   detonate on the next tick.
// ═══════════════════════════════════════════════════════════════

class ExplosionSystem {
    var _flames;
    var flameDurMs;

    function initialize() {
        _flames    = [];
        flameDurMs = 320;
    }

    function reset() { _flames = []; }
    function each()  { return _flames; }

    function isFlameAt(r, c) {
        for (var i = 0; i < _flames.size(); i++) {
            var f = _flames[i];
            if (f[0] == r && f[1] == c && f[2] > 0) { return true; }
        }
        return false;
    }

    // Ignite a bomb at (r,c) with the given range, painting flames
    // and damaging tiles via the grid.  Returns the number of
    // blocks destroyed (for scoring).
    function ignite(grid, bombSys, r, c, range) {
        var destroyed = 0;
        _addFlame(r, c);
        for (var d = 0; d < 4; d++) {
            var dr = 0; var dc = 0;
            if      (d == 0) { dr = -1; }
            else if (d == 1) { dr =  1; }
            else if (d == 2) { dc = -1; }
            else             { dc =  1; }
            for (var k = 1; k <= range; k++) {
                var rr = r + dr * k;
                var cc = c + dc * k;
                if (!grid.inBounds(rr, cc))     { break; }
                var v = grid.tileAt(rr, cc);
                if (v == BT_WALL) { break; }
                _addFlame(rr, cc);
                if (v == BT_BLOCK) {
                    grid.damageTile(rr, cc);
                    destroyed = destroyed + 1;
                    break;
                }
                // Chain to any bomb sitting on this tile.
                bombSys.igniteAt(rr, cc);
            }
        }
        return destroyed;
    }

    hidden function _addFlame(r, c) {
        // De-dupe so overlapping flames share one timer.
        for (var i = 0; i < _flames.size(); i++) {
            var f = _flames[i];
            if (f[0] == r && f[1] == c) {
                if (f[2] < flameDurMs) { f[2] = flameDurMs; }
                return;
            }
        }
        _flames.add([r, c, flameDurMs]);
    }

    function tick(dtMs) {
        var keep = [];
        for (var i = 0; i < _flames.size(); i++) {
            var f = _flames[i];
            f[2] = f[2] - dtMs;
            if (f[2] > 0) { keep.add(f); }
        }
        _flames = keep;
    }
}
