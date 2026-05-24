// ═══════════════════════════════════════════════════════════════
// GridManager.mc — n×n tile map for the Bomber clone.
//
// Layout (classic Bomberman):
//   Border cells   → indestructible walls.
//   Interior cells where (r%2==0 && c%2==0) → indestructible grid
//                    posts.  This produces the trademark "corridor"
//                    feel and guarantees the player always has at
//                    least one safe direction.
//   Other interior → breakable blocks (~55 % density) or empty.
//
// Hidden power-ups:
//   When the map is generated we secretly tag ~12 % of breakable
//   blocks with a power-up (one of BT_PU_*).  The tag is stored in
//   `hidden[]` — when a bomb destroys that block we promote
//   `hidden[i]` into `tiles[i]` so the player can step on it to
//   collect.
//
// Spawn helpers:
//   playerSpawn() → fixed (1,1).
//   enemySpawns(n) → up to 3 corner-ish cells, well separated from
//                    the player and guaranteed empty.
//
// Movement queries:
//   isWalkable(r,c, ghost) → walls always block; blocks blocked
//   unless `ghost` is true (the ghost power-up effect).
// ═══════════════════════════════════════════════════════════════

class GridManager {
    var n;
    var tiles;
    var pups;     // hidden power-up tag for each cell (0 = none)

    function initialize() {
        n     = 9;
        tiles = [];
        pups  = [];
    }

    function idx(r, c) { return r * n + c; }
    function inBounds(r, c) { return r >= 0 && c >= 0 && r < n && c < n; }
    function tileAt(r, c)   { return tiles[idx(r, c)]; }

    function setTile(r, c, v) {
        if (!inBounds(r, c)) { return; }
        tiles[idx(r, c)] = v;
    }

    // Used by ExplosionSystem when a flame reaches a tile.  Returns
    // true if the tile was destroyed (i.e. the flame should continue
    // — but ExplosionSystem still stops the flame on the next tile).
    function damageTile(r, c) {
        if (!inBounds(r, c)) { return false; }
        var i = idx(r, c);
        var v = tiles[i];
        if (v == BT_BLOCK) {
            var pu = pups[i];
            tiles[i] = (pu > 0) ? pu : BT_EMPTY;
            pups[i]  = 0;
            return true;
        }
        if (v >= BT_PU_BOMB && v <= BT_PU_GHOST) {
            // Power-ups in the flame are simply lost.
            tiles[i] = BT_EMPTY;
            return true;
        }
        return false;
    }

    // Walkability for movement.  Power-up cells ARE walkable
    // (they're picked up on entry).
    function isWalkable(r, c, ghost) {
        if (!inBounds(r, c)) { return false; }
        var v = tiles[idx(r, c)];
        if (v == BT_WALL)  { return false; }
        if (v == BT_BLOCK) { return ghost; }
        return true;
    }

    // ── Generation ─────────────────────────────────────────────
    function generate(n_, blockDensityPct, rndSeed) {
        n = n_;
        var sz = n * n;
        tiles = new [sz];
        pups  = new [sz];
        for (var i = 0; i < sz; i++) { tiles[i] = BT_EMPTY; pups[i] = 0; }

        // 1) Border walls.
        for (var r = 0; r < n; r++) {
            tiles[idx(r, 0)]     = BT_WALL;
            tiles[idx(r, n - 1)] = BT_WALL;
        }
        for (var c = 0; c < n; c++) {
            tiles[idx(0, c)]     = BT_WALL;
            tiles[idx(n - 1, c)] = BT_WALL;
        }
        // 2) Grid posts at even/even (classic Bomberman).
        for (var r = 2; r < n - 1; r += 2) {
            for (var c = 2; c < n - 1; c += 2) {
                tiles[idx(r, c)] = BT_WALL;
            }
        }

        // 3) Compute safe cells (player + enemy spawns + their L-shapes).
        var safe = new [sz];
        for (var i = 0; i < sz; i++) { safe[i] = 0; }
        _markSafe(safe, 1, 1);
        var es = enemySpawns(n, 3);
        for (var i = 0; i < es.size(); i++) {
            _markSafe(safe, es[i][0], es[i][1]);
        }

        // 4) Fill non-safe interior cells with blocks (pseudo-random).
        var state = rndSeed;
        if (state == 0) { state = 1; }
        var blockSlots = [];
        for (var r = 1; r < n - 1; r++) {
            for (var c = 1; c < n - 1; c++) {
                var ii = idx(r, c);
                if (tiles[ii] != BT_EMPTY) { continue; }
                if (safe[ii] != 0)         { continue; }
                state = (state * 1103515245 + 12345) & 0x7FFFFFFF;
                if ((state % 100) < blockDensityPct) {
                    tiles[ii] = BT_BLOCK;
                    blockSlots.add(ii);
                }
            }
        }

        // 5) Distribute power-ups among ~12 % of blocks (capped
        //    to 6 to keep things sane on the small map).
        var puCount = blockSlots.size() * 12 / 100;
        if (puCount > 6) { puCount = 6; }
        if (puCount < 2) { puCount = 2; }
        var puTypes = [BT_PU_BOMB, BT_PU_RANGE, BT_PU_SHIELD, BT_PU_GHOST];
        for (var k = 0; k < puCount; k++) {
            if (blockSlots.size() == 0) { break; }
            state = (state * 1103515245 + 12345) & 0x7FFFFFFF;
            var pick = state % blockSlots.size();
            var blkI = blockSlots[pick];
            blockSlots.remove(blockSlots[pick]);
            state = (state * 1103515245 + 12345) & 0x7FFFFFFF;
            pups[blkI] = puTypes[state % puTypes.size()];
        }
    }

    hidden function _markSafe(safe, r, c) {
        _markOne(safe, r,     c);
        _markOne(safe, r + 1, c);
        _markOne(safe, r,     c + 1);
        _markOne(safe, r - 1, c);
        _markOne(safe, r,     c - 1);
    }
    hidden function _markOne(safe, r, c) {
        if (!inBounds(r, c)) { return; }
        safe[idx(r, c)] = 1;
    }

    // Up to 3 enemy spawn cells.  We hand-pick them so they're far
    // from the player and never on the same tile.
    static function enemySpawns(n, want) {
        var cells = [[n - 2, n - 2], [1, n - 2], [n - 2, 1]];
        var out = [];
        for (var i = 0; i < want && i < cells.size(); i++) {
            out.add(cells[i]);
        }
        return out;
    }
}
