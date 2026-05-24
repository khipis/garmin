// ═══════════════════════════════════════════════════════════════
// Player.mc — Miner state and one-cell move logic.
// ═══════════════════════════════════════════════════════════════

class Player {
    var r;
    var c;
    var facing;
    var diamonds;
    var alive;

    function initialize() {
        r = 1; c = 1;
        facing = DC_DIR_R;
        diamonds = 0;
        alive = true;
    }

    function spawnAt(rc) {
        r = rc[0]; c = rc[1];
        facing = DC_DIR_R;
        diamonds = 0;
        alive = true;
    }

    // Try to move one cell in direction `d`.  Returns a short tag:
    //   "move"   stepped onto empty/dug a dirt tile
    //   "gem"    collected a diamond
    //   "push"   pushed a rock sideways
    //   "exit"   stepped onto the open exit
    //   "block"  movement refused (wall / closed exit / firefly tile)
    function tryMove(grid, d) {
        facing = d;
        var de = GridManager.dirDelta(d);
        var nr = r + de[0]; var nc = c + de[1];
        var t  = grid.get(nr, nc);

        if (t == TC_WALL || t == TC_BRICK) { return "block"; }

        if (t == TC_EMPTY) {
            r = nr; c = nc;
            return "move";
        }
        if (t == TC_DIRT) {
            grid.set(nr, nc, TC_EMPTY);
            r = nr; c = nc;
            return "move";
        }
        if (t == TC_DIAMOND) {
            grid.set(nr, nc, TC_EMPTY);
            r = nr; c = nc;
            diamonds = diamonds + 1;
            return "gem";
        }
        if (t == TC_EXIT) {
            r = nr; c = nc;
            return "exit";
        }
        if (t == TC_ROCK) {
            // Push only horizontally and only if the cell beyond is
            // empty.  Once pushed, the rock takes the cell next to us
            // and physics will let it fall on the next settle pass.
            if (d == DC_DIR_L || d == DC_DIR_R) {
                var br = nr;
                var bc = nc + (d == DC_DIR_R ? 1 : -1);
                if (grid.get(br, bc) == TC_EMPTY) {
                    grid.set(br, bc, TC_ROCK);
                    grid.set(nr, nc, TC_EMPTY);
                    r = nr; c = nc;
                    return "push";
                }
            }
            return "block";
        }
        return "block";
    }
}
