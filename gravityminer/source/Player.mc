// ═══════════════════════════════════════════════════════════════
// Player.mc — Miner state.
//
// Holds cell position, facing direction (for rendering hint), and
// the simple alive flag.  Movement logic lives in GameController
// so this stays a pure data carrier.
// ═══════════════════════════════════════════════════════════════

class Player {
    var r;
    var c;
    var facing;
    var alive;

    function initialize() {
        r = 0; c = 4; facing = GM_DIR_R; alive = true;
    }

    function spawnAt(rr, cc) {
        r = rr; c = cc; facing = GM_DIR_R; alive = true;
    }
}
