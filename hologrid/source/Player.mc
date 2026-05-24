// ═══════════════════════════════════════════════════════════════
// Player.mc — Hologrid runner state.
//
// Pure data; movement legality is verified by GameController.
// ═══════════════════════════════════════════════════════════════

class Player {
    var r;
    var c;
    var facing;
    var alive;

    function initialize() {
        r = 1; c = 1; facing = HG_DIR_R; alive = true;
    }
    function spawnAt(rc) {
        r = rc[0]; c = rc[1]; facing = HG_DIR_R; alive = true;
    }
}
