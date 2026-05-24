// ═══════════════════════════════════════════════════════════════
// Player.mc — The cannon at the bottom of the screen.
//
// PixelInvaders is grid-based — the player sits on a single row
// and steps one cell left/right per button press.  We add a tiny
// glide via `colFloat` so the movement isn't jarringly snappy:
// each press moves the integer `col` immediately (responsive)
// while `colFloat` lerps to it (animated).
//
// Hit-tests use `col` (the discrete cell), not `colFloat`, so the
// player can't "phase through" an enemy bullet between cells.
// ═══════════════════════════════════════════════════════════════

const PI_BOARD_COLS  = 9;
const PI_BOARD_ROWS  = 12;
const PI_PLAYER_ROW  = PI_BOARD_ROWS - 1;

class Player {
    var col;            // integer cell — used for collision
    var colFloat;       // float — used for drawing
    var alive;
    var blinkTicks;     // brief invul + flash after respawn

    function initialize() {
        col       = PI_BOARD_COLS / 2;
        colFloat  = col + 0.0;
        alive     = true;
        blinkTicks = 0;
    }

    function spawn() {
        col       = PI_BOARD_COLS / 2;
        colFloat  = col + 0.0;
        alive     = true;
        blinkTicks = 35;   // ~2.8 s grace
    }

    // Move ±1 cell, wrapping around the playfield.  When a wrap
    // happens we snap `colFloat` to the new column so the cannon
    // doesn't dramatically slide across the entire screen — it
    // teleports to the other side instead.
    function nudge(d) {
        var nc      = col + d;
        var wrapped = false;
        if (nc < 0)                 { nc = PI_BOARD_COLS - 1; wrapped = true; }
        if (nc > PI_BOARD_COLS - 1) { nc = 0;                  wrapped = true; }
        col = nc;
        if (wrapped) { colFloat = col + 0.0; }
    }

    // Lerp colFloat → col (small step, snappy feel).
    function tickGlide() {
        var SLIDE = 0.5;
        var d = col - colFloat;
        if (d > SLIDE)       { colFloat = colFloat + SLIDE; }
        else if (d < -SLIDE) { colFloat = colFloat - SLIDE; }
        else                  { colFloat = col + 0.0; }
        if (blinkTicks > 0) { blinkTicks = blinkTicks - 1; }
    }

    function isInvulnerable() { return blinkTicks > 0; }
}
