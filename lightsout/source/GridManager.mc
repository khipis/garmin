// ═══════════════════════════════════════════════════════════════
// GridManager.mc — n×n Lights Out grid.
//
// Storage: `cells` is a flat Number[n*n] of 0/1 where 1 means the
// light is ON.  All gameplay operations are O(1) or O(n²).
//
// toggle(r, c)
//   Flip cell (r,c) and the four orthogonal neighbours (a "press").
//   Out-of-bounds neighbours are ignored.  Returns true if the
//   press was applied.
//
// isAllOff()
//   True when every cell is 0 (the win condition).
//
// snapshot() / restore(s)
//   Copy the entire grid; used by the controller to "save" the
//   level start state for the restart button.
// ═══════════════════════════════════════════════════════════════

class GridManager {
    var n;
    var cells;

    function initialize() {
        n     = 4;
        cells = [];
        resize(n);
    }

    function resize(n_) {
        n = n_;
        cells = new [n * n];
        for (var i = 0; i < n * n; i++) { cells[i] = 0; }
    }

    function idx(r, c) { return r * n + c; }
    function inBounds(r, c) { return r >= 0 && c >= 0 && r < n && c < n; }
    function isOn(r, c)     { return cells[idx(r, c)] != 0; }

    // The Lights Out "press": flip self + 4 orthogonal neighbours.
    function toggle(r, c) {
        if (!inBounds(r, c)) { return false; }
        _flip(r,     c);
        _flip(r - 1, c);
        _flip(r + 1, c);
        _flip(r,     c - 1);
        _flip(r,     c + 1);
        return true;
    }

    hidden function _flip(r, c) {
        if (!inBounds(r, c)) { return; }
        var i = idx(r, c);
        cells[i] = (cells[i] != 0) ? 0 : 1;
    }

    function isAllOff() {
        for (var i = 0; i < n * n; i++) {
            if (cells[i] != 0) { return false; }
        }
        return true;
    }

    function onCount() {
        var k = 0;
        for (var i = 0; i < n * n; i++) {
            if (cells[i] != 0) { k = k + 1; }
        }
        return k;
    }

    function snapshot() {
        var s = new [n * n];
        for (var i = 0; i < n * n; i++) { s[i] = cells[i]; }
        return s;
    }

    function restore(s) {
        for (var i = 0; i < n * n; i++) { cells[i] = s[i]; }
    }
}
