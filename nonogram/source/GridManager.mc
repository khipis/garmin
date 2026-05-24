// ═══════════════════════════════════════════════════════════════
// GridManager.mc — Nonogram board + clue storage.
//
// Cell tri-state:
//   NG_EMPTY  (0)  no input
//   NG_FILL   (1)  player filled this cell
//   NG_X      (2)  player marked "cannot be filled" (helper note)
//
// load(puzzleRec)
//   Accepts a puzzle record produced by NGPuzzles:
//     [n, solutionFlat, rowClues, rowOffs, colClues, colOffs]
//
// snapshot()/restore(s)
//   Used by the controller's "restart" feature.
//
// Row/column clue accessors flatten the (varying-length) clue lists
// into a single Number[] with prefix-sum offsets — saves on heap
// allocation on Monkey C VMs.
// ═══════════════════════════════════════════════════════════════

const NG_EMPTY = 0;
const NG_FILL  = 1;
const NG_X     = 2;

class GridManager {
    var n;
    var cells;
    var solution;
    var rowClues;
    var rowOffs;
    var colClues;
    var colOffs;

    function initialize() {
        n         = 5;
        cells     = [];
        solution  = [];
        rowClues  = [];
        rowOffs   = [];
        colClues  = [];
        colOffs   = [];
    }

    function load(rec) {
        n        = rec[0];
        solution = rec[1];
        rowClues = rec[2];
        rowOffs  = rec[3];
        colClues = rec[4];
        colOffs  = rec[5];
        cells = new [n * n];
        for (var i = 0; i < n * n; i++) { cells[i] = NG_EMPTY; }
    }

    function idx(r, c) { return r * n + c; }
    function inBounds(r, c) { return r >= 0 && c >= 0 && r < n && c < n; }
    function getCell(r, c)  { return cells[idx(r, c)]; }

    // 3-state cycle: EMPTY → FILL → X → EMPTY.
    function cycle(r, c) {
        if (!inBounds(r, c)) { return; }
        var i = idx(r, c);
        var v = cells[i] + 1;
        if (v > NG_X) { v = NG_EMPTY; }
        cells[i] = v;
    }

    function clear(r, c) {
        if (!inBounds(r, c)) { return; }
        cells[idx(r, c)] = NG_EMPTY;
    }

    function snapshot() {
        var s = new [n * n];
        for (var i = 0; i < n * n; i++) { s[i] = cells[i]; }
        return s;
    }
    function restore(s) {
        for (var i = 0; i < n * n; i++) { cells[i] = s[i]; }
    }

    // Helpers for the UI when rendering clue strips.
    function rowClueCount(r) { return rowOffs[r + 1] - rowOffs[r]; }
    function rowClueAt(r, k) { return rowClues[rowOffs[r] + k]; }
    function colClueCount(c) { return colOffs[c + 1] - colOffs[c]; }
    function colClueAt(c, k) { return colClues[colOffs[c] + k]; }

    // For win/hint logic.
    function solutionAt(r, c) { return solution[idx(r, c)]; }
}
