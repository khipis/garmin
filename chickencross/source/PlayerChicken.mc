// ═══════════════════════════════════════════════════════════════
// PlayerChicken.mc — The chicken: where she is and where she faces.
//
// Position is stored in tile coordinates, with `colFloat` carrying
// the sub-tile drift when the chicken is riding a log.  `col` is
// recomputed from `colFloat` whenever a discrete action is taken
// (button press, collision check) so all gameplay logic still
// operates on integer cells.
// ═══════════════════════════════════════════════════════════════

const DIR_U2 = 0;
const DIR_R2 = 1;
const DIR_L2 = 2;

class PlayerChicken {
    var row;
    var col;
    var colFloat;     // = col + sub-tile drift while on a log
    var facing;
    var maxRow;       // highest row reached this life (used for score)

    function initialize() {
        row = 0; col = BOARD_COLS / 2;
        colFloat = col + 0.0;
        facing = DIR_U2;
        maxRow = 0;
    }

    function spawn() {
        row = 0; col = BOARD_COLS / 2;
        colFloat = col + 0.0;
        facing = DIR_U2;
        maxRow = 0;
    }

    // Snap `colFloat` to the nearest integer column.  Called after a
    // discrete move (button press) so the chicken always lands on a
    // tile centre even if she was drifting on a log.
    function snapCol() {
        var c = (colFloat + 0.5).toNumber();
        if (c < 0)                { c = 0; }
        if (c >= BOARD_COLS)      { c = BOARD_COLS - 1; }
        col = c;
        colFloat = col + 0.0;
    }

    // Apply a discrete step.  Returns false if the move is blocked
    // by the playfield edge (vertical), or clamps in horizontal.
    function step(dRow, dCol) {
        var nr = row + dRow;
        if (nr < 0) { return false; }
        if (nr >= BOARD_ROWS) { nr = BOARD_ROWS - 1; }
        row = nr;
        if (row > maxRow) { maxRow = row; }
        // Set facing for the animation.
        if      (dRow > 0) { facing = DIR_U2; }
        else if (dCol > 0) { facing = DIR_R2; }
        else if (dCol < 0) { facing = DIR_L2; }
        // Horizontal step: clamp inside playfield.
        var nc = col + dCol;
        if (nc < 0)             { nc = 0; }
        if (nc >= BOARD_COLS)   { nc = BOARD_COLS - 1; }
        col = nc;
        colFloat = col + 0.0;
        return true;
    }
}
