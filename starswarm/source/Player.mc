// ═══════════════════════════════════════════════════════════════
// Player.mc — Star fighter at the bottom of the playfield.
//
// Position is stored as a Float column (`col`) so the ship glides
// smoothly between integer cells; row is fixed to the bottom lane.
// Movement is queued: each button-press nudges `targetCol` by ±1,
// and the controller's tick lerps `col` toward it so the ship
// looks alive even when the player is mashing.
//
// Shooting uses a simple "cooldown" gate — `fireCool` counts down
// each tick.  Below 0 → the player may fire again.
// ═══════════════════════════════════════════════════════════════

const SS_BOARD_COLS = 9;
const SS_BOARD_ROWS = 12;

class Player {
    var col;         // float — actual position (interpolated)
    var targetCol;   // float — where the ship is heading
    var row;         // fixed at bottom row
    var alive;
    var fireCool;    // ticks until next shot allowed

    function initialize() {
        col       = (SS_BOARD_COLS - 1) / 2.0;
        targetCol = col;
        row       = SS_BOARD_ROWS - 1;
        alive     = true;
        fireCool  = 0;
    }

    function spawn() {
        col       = (SS_BOARD_COLS - 1) / 2.0;
        targetCol = col;
        alive     = true;
        fireCool  = 0;
    }

    function nudge(dir) {
        var nt = targetCol + dir;
        if (nt < 0)                  { nt = 0; }
        if (nt > SS_BOARD_COLS - 1)  { nt = SS_BOARD_COLS - 1; }
        targetCol = nt;
    }

    // Lerp col → targetCol at SLIDE_STEP per tick.  This produces a
    // brief glide so a single keypress is clearly visible.
    function tickGlide() {
        var SLIDE_STEP = 0.35;
        var d = targetCol - col;
        if (d > SLIDE_STEP)  { col = col + SLIDE_STEP; }
        else if (d < -SLIDE_STEP) { col = col - SLIDE_STEP; }
        else                  { col = targetCol; }
        if (fireCool > 0) { fireCool = fireCool - 1; }
    }

    // True if the ship may fire (cooldown elapsed AND <2 active shots
    // is enforced by ProjectileSystem).
    function canFire() { return fireCool <= 0; }

    // Caller invokes after a successful fire to set the cooldown.
    function markFired() { fireCool = 2; }

    // Integer column for collision against grid-aligned actors.
    function intCol() {
        var c = (col + 0.5).toNumber();
        if (c < 0)                   { c = 0; }
        if (c >= SS_BOARD_COLS)      { c = SS_BOARD_COLS - 1; }
        return c;
    }
}
