// ═══════════════════════════════════════════════════════════════
// CollisionSystem.mc — Tile-grid collision helpers.
// ═══════════════════════════════════════════════════════════════

class CollisionSystem {

    static function isWall(grid, n, r, c) {
        if (r < 0 || r >= n || c < 0 || c >= n) { return true; }
        return grid[r * n + c] == TILE_WALL;
    }

    // Returns the tile constant at the player's cell, then clears it
    // to FLOOR if it was a pellet/power.  Returns -1 on out-of-bounds.
    static function consume(grid, n, player) {
        var i = player.r * n + player.c;
        var t = grid[i];
        if (t == TILE_PELLET || t == TILE_POWER) {
            grid[i] = TILE_FLOOR;
        }
        return t;
    }

    // Returns the ghost index that's standing on Pac-Man, or -1.
    // (We need the index so the controller can either kill the ghost
    // in frightened mode or kill the player.)
    static function ghostOnPlayer(ghosts, player) {
        for (var i = 0; i < ghosts.size(); i++) {
            var g = ghosts[i];
            if (!g.isActive()) { continue; }
            if (g.r == player.r && g.c == player.c) { return i; }
        }
        return -1;
    }
}
