// ═══════════════════════════════════════════════════════════════
// GridManager.mc — Akari board state.
//
// Two parallel flat arrays of length n*n:
//
//   cells[i]   board geometry (constant for the lifetime of a puzzle)
//     0       white cell — player can place a bulb here
//     1       wall (no number / no constraint)
//     2..6    wall with number k  (k = value - 2,  range 0..4)
//
//   marks[i]   player input (mutable)
//     AK_NONE 0   empty white cell
//     AK_BULB 1   player-placed bulb
//     AK_X    2   player "no-bulb" hint mark
//
// solution[i]  reference solution from the puzzle pack (used only by
//              the optional error-highlight and hint features).
//
// Cycle order on tap/SEL: NONE → BULB → X → NONE.  Long-hold sets
// X directly (helpful when the player KNOWS a cell can't be a bulb
// but doesn't want to step through BULB first).
// ═══════════════════════════════════════════════════════════════

const AK_NONE = 0;
const AK_BULB = 1;
const AK_X    = 2;

class GridManager {
    var n;
    var cells;
    var marks;
    var solution;

    function initialize() {
        n        = 6;
        cells    = [];
        marks    = [];
        solution = [];
    }

    function load(rec) {
        n        = rec[0];
        cells    = rec[1];
        solution = rec[2];
        marks = new [n * n];
        for (var i = 0; i < n * n; i++) { marks[i] = AK_NONE; }
    }

    function idx(r, c) { return r * n + c; }
    function inBounds(r, c) { return r >= 0 && c >= 0 && r < n && c < n; }

    function isWall(r, c)   { return cells[idx(r, c)] != 0; }
    function wallNumber(r, c) {
        var v = cells[idx(r, c)];
        if (v < 2) { return -1; }     // no number
        return v - 2;
    }
    function isWhite(r, c)  { return cells[idx(r, c)] == 0; }
    function markAt(r, c)   { return marks[idx(r, c)]; }
    function solutionAt(r, c) { return solution[idx(r, c)]; }

    // Cycle: NONE → BULB → X → NONE.
    function cycle(r, c) {
        if (!inBounds(r, c) || !isWhite(r, c)) { return; }
        var i = idx(r, c);
        var v = marks[i] + 1;
        if (v > AK_X) { v = AK_NONE; }
        marks[i] = v;
    }

    function setMark(r, c, v) {
        if (!inBounds(r, c) || !isWhite(r, c)) { return; }
        marks[idx(r, c)] = v;
    }

    function clearMark(r, c) {
        if (!inBounds(r, c) || !isWhite(r, c)) { return; }
        marks[idx(r, c)] = AK_NONE;
    }

    function snapshot() {
        var s = new [n * n];
        for (var i = 0; i < n * n; i++) { s[i] = marks[i]; }
        return s;
    }
    function restore(s) {
        for (var i = 0; i < n * n; i++) { marks[i] = s[i]; }
    }
}
