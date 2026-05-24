// ═══════════════════════════════════════════════════════════════
// Player.mc — Pac-Man.
//
// Tile-based position with a "nextDir" queued direction so a
// swipe doesn't have to land perfectly on a corner.  Mouth phase
// animates between 0/1/2/3 across ticks for the chomp loop.
// ═══════════════════════════════════════════════════════════════

const DIR_U = 0;
const DIR_R = 1;
const DIR_D = 2;
const DIR_L = 3;

class Player {
    var r;
    var c;
    var dir;        // current heading
    var nextDir;    // queued heading (applied when legal)
    var mouthPhase; // 0..3 chomp frame

    function initialize() {
        r = 9; c = 6;
        dir = DIR_L; nextDir = DIR_L;
        mouthPhase = 0;
    }

    function setSpawn(rc) {
        r = rc[0]; c = rc[1];
        dir = DIR_L; nextDir = DIR_L;
        mouthPhase = 0;
    }

    static function delta(d) {
        if (d == DIR_U) { return [-1,  0]; }
        if (d == DIR_R) { return [ 0,  1]; }
        if (d == DIR_D) { return [ 1,  0]; }
        return            [ 0, -1];
    }

    function setNextDir(d) { nextDir = d; }

    function tickAnim() { mouthPhase = (mouthPhase + 1) % 4; }
}
