// ═══════════════════════════════════════════════════════════════
// GridManager.mc — Active Kakuro grid + per-cell metadata.
//
// Storage layout (flat row-major Number arrays of size n*n):
//
//   white[i]   1 if the cell at i is a white input cell, else 0
//   sol[i]     the puzzle solution digit (1..9) for white cells, 0 else.
//              Used only by the hint system; gameplay does NOT compare
//              the player's grid against `sol` — completion is decided
//              purely from the rule-set (see ValidationEngine).
//   val[i]     the player's current digit (0 = empty, 1..9 = filled)
//   hSum[i]    horizontal clue at this cell (-1 if none).  Set only
//              on black cells immediately to the LEFT of a run.
//   vSum[i]    vertical clue at this cell (-1 if none).  Set only on
//              black cells immediately ABOVE a run.
//
// We pre-compute runs once after loadPuzzle():
//
//   runs[r] = [ [memberCellIdx,...], clueSum, axis ]
//
// `axis` is 0 for horizontal, 1 for vertical.  `clueSum` is the
// expected sum.  The list of member cells is in scan order.  Each
// white cell stores indices into runs[] for its row-run and col-run.
//
//   rowRun[i]  index into runs[] for the horizontal run containing i,
//              or -1 if cell i is black.
//   colRun[i]  same, for the vertical run.
//
// All of this is O(n²) computed once at puzzle load; gameplay just
// reads & validates incrementally.
// ═══════════════════════════════════════════════════════════════

class GridManager {
    var n;             // grid dimension
    var white;         // flat n*n
    var sol;           // flat n*n
    var val;           // flat n*n
    var hSum;          // flat n*n
    var vSum;          // flat n*n
    var rowRun;        // flat n*n; -1 for black
    var colRun;        // flat n*n; -1 for black
    var runs;          // Array of run records: [memberIdxList, clueSum, axis]

    function initialize() {
        n = 4;
        _allocate(n);
    }

    hidden function _allocate(n_) {
        n      = n_;
        var sz = n * n;
        white  = new [sz];
        sol    = new [sz];
        val    = new [sz];
        hSum   = new [sz];
        vSum   = new [sz];
        rowRun = new [sz];
        colRun = new [sz];
        for (var i = 0; i < sz; i++) {
            white[i]  = 0;
            sol[i]    = 0;
            val[i]    = 0;
            hSum[i]   = -1;
            vSum[i]   = -1;
            rowRun[i] = -1;
            colRun[i] = -1;
        }
        runs = [];
    }

    function idx(r, c) { return r * n + c; }

    function isWhite(r, c)  { return white[idx(r, c)] != 0; }
    function getVal(r, c)   { return val[idx(r, c)]; }
    function getSol(r, c)   { return sol[idx(r, c)]; }
    function getHSum(r, c)  { return hSum[idx(r, c)]; }
    function getVSum(r, c)  { return vSum[idx(r, c)]; }

    function inBounds(r, c) {
        return r >= 0 && c >= 0 && r < n && c < n;
    }

    function setVal(r, c, v) {
        if (!isWhite(r, c)) { return false; }
        if (v < 0 || v > 9) { return false; }
        val[idx(r, c)] = v;
        return true;
    }

    function clearVal(r, c) { return setVal(r, c, 0); }

    // Reset all white cells to 0 (used by "restart puzzle").
    function clearAll() {
        for (var i = 0; i < n * n; i++) {
            if (white[i] != 0) { val[i] = 0; }
        }
    }

    // True when every white cell has a digit (1..9).
    function isFilled() {
        for (var i = 0; i < n * n; i++) {
            if (white[i] != 0 && val[i] == 0) { return false; }
        }
        return true;
    }

    // Count empty white cells (used for HUD).
    function emptyCount() {
        var c = 0;
        for (var i = 0; i < n * n; i++) {
            if (white[i] != 0 && val[i] == 0) { c = c + 1; }
        }
        return c;
    }

    // ── Puzzle loading ───────────────────────────────────────────
    //
    // `solFlat` is a flat Number[n*n] from KKPuzzles.getSol(i).  We
    // copy the solution, mark non-zero cells as white, and walk
    // the grid to discover runs.
    function loadPuzzle(n_, solFlat) {
        _allocate(n_);
        for (var i = 0; i < n * n; i++) {
            var v = solFlat[i];
            if (v > 0) { white[i] = 1; sol[i] = v; }
            else        { white[i] = 0; sol[i] = 0; }
        }
        _computeRuns();
        clearAll();
    }

    // Discover horizontal & vertical runs and stamp clue sums on the
    // black cells that introduce them.
    hidden function _computeRuns() {
        runs = [];

        // Horizontal scan.
        for (var r = 0; r < n; r++) {
            var c = 0;
            while (c < n) {
                while (c < n && white[idx(r, c)] == 0) { c = c + 1; }
                if (c >= n) { break; }
                var startC = c;
                var members = [];
                var s = 0;
                while (c < n && white[idx(r, c)] != 0) {
                    var ci = idx(r, c);
                    members.add(ci);
                    s = s + sol[ci];
                    c = c + 1;
                }
                var runId = runs.size();
                runs.add([members, s, 0]);
                for (var k = 0; k < members.size(); k++) {
                    rowRun[members[k]] = runId;
                }
                // Stamp horizontal sum on the cell to the LEFT of the run
                // (which is guaranteed black or out-of-bounds; if out of
                // bounds we just skip — no clue cell to anchor on).
                if (startC > 0) { hSum[idx(r, startC - 1)] = s; }
            }
        }

        // Vertical scan.
        for (var col = 0; col < n; col++) {
            var rr = 0;
            while (rr < n) {
                while (rr < n && white[idx(rr, col)] == 0) { rr = rr + 1; }
                if (rr >= n) { break; }
                var startR = rr;
                var members = [];
                var s = 0;
                while (rr < n && white[idx(rr, col)] != 0) {
                    var ci = idx(rr, col);
                    members.add(ci);
                    s = s + sol[ci];
                    rr = rr + 1;
                }
                var runId = runs.size();
                runs.add([members, s, 1]);
                for (var k = 0; k < members.size(); k++) {
                    colRun[members[k]] = runId;
                }
                if (startR > 0) { vSum[idx(startR - 1, col)] = s; }
            }
        }
    }

    // Step the cursor in (dr, dc) and stop on the first white cell
    // we encounter (wrapping at grid edges).  Returns [r,c] of new
    // cursor — never lands on a black cell.
    function nextWhite(r, c, dr, dc) {
        for (var step = 0; step < n * n; step++) {
            var nr = ((r + dr) + n) % n;
            var nc = ((c + dc) + n) % n;
            if (white[idx(nr, nc)] != 0) { return [nr, nc]; }
            r = nr; c = nc;
        }
        return [r, c];
    }

    // Find the next white cell in scan order (for SELECT advancing).
    function nextWhiteScan(r, c) {
        var ci = idx(r, c);
        for (var k = 1; k < n * n; k++) {
            var i = (ci + k) % (n * n);
            if (white[i] != 0) { return [i / n, i % n]; }
        }
        return [r, c];
    }
}
