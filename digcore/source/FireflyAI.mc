// ═══════════════════════════════════════════════════════════════
// FireflyAI.mc — Cave-fly that hunts the miner.
//
// Classic Boulder-Dash fireflies follow the left-hand rule: try
// to turn left first, then continue straight, then right, and as
// a last resort turn around.  This produces the characteristic
// "wall-hugging" patrol around any open cavity.
//
// State:
//   r, c   – grid cell
//   dir    – current heading (DC_DIR_*)
//   alive  – set to false when crushed by a falling rock/diamond
// ═══════════════════════════════════════════════════════════════

class Firefly {
    var r;
    var c;
    var dir;
    var alive;

    function initialize(r0, c0, d0) {
        r = r0; c = c0; dir = d0; alive = true;
    }

    // Returns the direction that's 90° counter-clockwise of `d`.
    static function turnLeft(d)  { return (d + 3) % 4; }
    // Returns the direction that's 90° clockwise of `d`.
    static function turnRight(d) { return (d + 1) % 4; }
    // Opposite direction.
    static function turnAround(d){ return (d + 2) % 4; }

    // True if the firefly may step into (r,c).  It only walks through
    // empty cells — it can't dig dirt, push rocks, or pass through
    // walls/bricks.  The player tile is technically "empty" in the
    // grid so contact is resolved by the controller (player dies).
    static function passable(grid, r, c) {
        if (!grid.inBounds(r, c)) { return false; }
        return grid.get(r, c) == TC_EMPTY;
    }

    // Walk one step using the left-hand-rule.
    function step(grid) {
        if (!alive) { return; }

        // Probe directions in left-hand-rule order.
        var probe = [turnLeft(dir), dir, turnRight(dir), turnAround(dir)];
        for (var i = 0; i < probe.size(); i++) {
            var d   = probe[i];
            var de  = GridManager.dirDelta(d);
            var nr  = r + de[0];
            var nc  = c + de[1];
            if (passable(grid, nr, nc)) {
                dir = d;
                r = nr; c = nc;
                return;
            }
        }
        // Completely walled in — just rotate so the sprite still
        // animates.  Rare in practice.
        dir = turnAround(dir);
    }
}
