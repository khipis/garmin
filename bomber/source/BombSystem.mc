// ═══════════════════════════════════════════════════════════════
// BombSystem.mc — Active bombs and their countdown timers.
//
// Each bomb is stored as a flat [r, c, msLeft, range] entry in
// `_bombs[]`.  We keep them as plain arrays to avoid per-tick
// class allocation on Monkey C VMs (helps the watchdog).
//
// Tick semantics:
//   tick(dtMs)  decrements each bomb's `msLeft` by dtMs.  Bombs
//               whose counter drops ≤ 0 are appended to `_pending`
//               and removed from the active list.
//   drainExploded()  returns the pending list (and clears it) so
//                    ExplosionSystem can ignite them in one shot —
//                    this naturally handles chain-reactions when
//                    a flame reaches another bomb (see igniteAt()).
// ═══════════════════════════════════════════════════════════════

class BombSystem {
    var _bombs;
    var _pending;
    var fuseMs;
    var defaultRange;

    function initialize() {
        _bombs       = [];
        _pending     = [];
        fuseMs       = 2000;
        defaultRange = 2;
    }

    function reset() {
        _bombs   = [];
        _pending = [];
    }

    function count() { return _bombs.size(); }

    function hasBombAt(r, c) {
        for (var i = 0; i < _bombs.size(); i++) {
            var b = _bombs[i];
            if (b[0] == r && b[1] == c) { return true; }
        }
        return false;
    }

    // Place a bomb if there isn't already one on that tile and the
    // owner hasn't exceeded its budget.  Returns true if placed.
    function place(r, c, ownedCount, maxBombs, range) {
        if (hasBombAt(r, c))         { return false; }
        if (ownedCount >= maxBombs)  { return false; }
        _bombs.add([r, c, fuseMs, range]);
        return true;
    }

    // Chain-reaction trigger — when a flame reaches a bomb we want
    // it to detonate immediately on the next tick boundary rather
    // than continuing its fuse.
    function igniteAt(r, c) {
        for (var i = 0; i < _bombs.size(); i++) {
            var b = _bombs[i];
            if (b[0] == r && b[1] == c) {
                b[2] = 0;
                return true;
            }
        }
        return false;
    }

    function tick(dtMs) {
        var keep = [];
        for (var i = 0; i < _bombs.size(); i++) {
            var b = _bombs[i];
            b[2] = b[2] - dtMs;
            if (b[2] <= 0) {
                _pending.add(b);
            } else {
                keep.add(b);
            }
        }
        _bombs = keep;
    }

    function drainExploded() {
        var out = _pending;
        _pending = [];
        return out;
    }

    // Iteration helpers for the UI (read-only).
    function each() { return _bombs; }
}
