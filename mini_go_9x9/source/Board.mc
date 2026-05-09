// Board — 9×9 Go board with full capture logic and Japanese territory scoring.
//
// grid[y*9+x]: 0=empty, 1=BLACK, 2=WHITE
//
// All BFS (flood-fill) operations use a generation counter instead of clearing
// the visited[] array on every call — critical for AI performance.

class Board {
    var grid;       // int[81] — current board state
    var prevGrid;   // int[81] — board before last placeStone (ko detection)
    var capBlack;   // black stones removed from board (captured by White)
    var capWhite;   // white stones removed from board (captured by Black)

    // Final scores (populated by calcScore after game ends)
    var scoreBlack;
    var scoreWhite;

    // ── BFS scratch buffers — pre-allocated, reused every call ───────────────
    hidden var _vis;    // int[81] — generation when each cell was last visited
    hidden var _gen;    // current BFS generation counter (monotonically increasing)
    hidden var _grp;    // int[81] — group members from the last _bfs call
    hidden var _grpSz;  // number of entries in _grp
    hidden var _stk;    // int[81] — BFS stack

    function initialize() {
        grid     = new [81]; prevGrid = new [81];
        _vis     = new [81]; _grp    = new [81]; _stk = new [81];
        _gen     = 0; _grpSz = 0;
        scoreBlack = 0; scoreWhite = 0;
        newGame();
    }

    function newGame() {
        var i = 0;
        while (i < 81) {
            grid[i] = 0; prevGrid[i] = 0; _vis[i] = -1;
            i = i + 1;
        }
        capBlack = 0; capWhite = 0;
        scoreBlack = 0; scoreWhite = 0;
        _gen = 0;
    }

    // ── BFS: find all stones connected to 'start' of colour 'col'. ───────────
    // Returns: liberty count.
    // Fills:   _grp[0.._grpSz-1] with group member indices.
    // Uses generation counter — O(group_size), no array clear needed.
    hidden function _bfs(start, col) {
        _gen   = _gen + 1;
        var sTop = 0; _grpSz = 0; var libs = 0;
        _vis[start] = _gen;
        _stk[sTop]  = start; sTop = sTop + 1;

        while (sTop > 0) {
            sTop = sTop - 1;
            var idx = _stk[sTop];
            _grp[_grpSz] = idx; _grpSz = _grpSz + 1;
            var bx = idx % 9; var by = idx / 9;

            var nbN = idx - 9; var nbS = idx + 9;
            var nbW = idx - 1; var nbE = idx + 1;

            if (by > 0 && _vis[nbN] != _gen) {
                _vis[nbN] = _gen;
                if      (grid[nbN] == 0)   { libs = libs + 1; }
                else if (grid[nbN] == col) { _stk[sTop] = nbN; sTop = sTop + 1; }
            }
            if (by < 8 && _vis[nbS] != _gen) {
                _vis[nbS] = _gen;
                if      (grid[nbS] == 0)   { libs = libs + 1; }
                else if (grid[nbS] == col) { _stk[sTop] = nbS; sTop = sTop + 1; }
            }
            if (bx > 0 && _vis[nbW] != _gen) {
                _vis[nbW] = _gen;
                if      (grid[nbW] == 0)   { libs = libs + 1; }
                else if (grid[nbW] == col) { _stk[sTop] = nbW; sTop = sTop + 1; }
            }
            if (bx < 8 && _vis[nbE] != _gen) {
                _vis[nbE] = _gen;
                if      (grid[nbE] == 0)   { libs = libs + 1; }
                else if (grid[nbE] == col) { _stk[sTop] = nbE; sTop = sTop + 1; }
            }
        }
        return libs;
    }

    // Public: library count for whatever stone is at idx (used by AI).
    function getGroupLiberties(idx) {
        var col = grid[idx];
        if (col == 0) { return 0; }
        return _bfs(idx, col);
    }

    // Remove opponent group at 'nb' if it has zero liberties.
    hidden function _captureIfDead(nb, opp) {
        if (grid[nb] != opp) { return; }
        if (_bfs(nb, opp) == 0) {
            var i = 0;
            while (i < _grpSz) { grid[_grp[i]] = 0; i = i + 1; }
            if (opp == 1) { capBlack = capBlack + _grpSz; }
            else          { capWhite = capWhite + _grpSz; }
        }
    }

    // Place stone of colour 'col' at (x,y).
    // Handles: capture, suicide check, simple ko.
    // Returns true on success, false if move is illegal.
    function placeStone(x, y, col) {
        if (x < 0 || x > 8 || y < 0 || y > 8) { return false; }
        var idx = y * 9 + x;
        if (grid[idx] != 0) { return false; }

        // Save board for ko check
        var i = 0;
        while (i < 81) { prevGrid[i] = grid[i]; i = i + 1; }

        grid[idx] = col;
        var opp = (col == 1) ? 2 : 1;

        // Capture any adjacent opponent groups with zero liberties
        if (y > 0) { _captureIfDead(idx - 9, opp); }
        if (y < 8) { _captureIfDead(idx + 9, opp); }
        if (x > 0) { _captureIfDead(idx - 1, opp); }
        if (x < 8) { _captureIfDead(idx + 1, opp); }

        // Suicide: if placed group still has no liberties → illegal
        if (_bfs(idx, col) == 0) {
            i = 0;
            while (i < 81) { grid[i] = prevGrid[i]; i = i + 1; }
            return false;
        }

        // Simple ko: board must differ from position before this move
        var ko = true; i = 0;
        while (i < 81 && ko) {
            if (grid[i] != prevGrid[i]) { ko = false; }
            i = i + 1;
        }
        if (ko) {
            i = 0;
            while (i < 81) { grid[i] = prevGrid[i]; i = i + 1; }
            return false;
        }

        return true;
    }

    // Japanese scoring: territory + captures.  Komi = 7 for White.
    // Populates scoreBlack and scoreWhite.
    function calcScore() {
        var bTerr = 0; var wTerr = 0;

        // Single pass: generate two generation ids —
        //   vGen: marks any cell that has been globally assigned to a region
        //   rGen: local tag for the current region's BFS queue
        _gen = _gen + 1;
        var vGen = _gen;

        var i = 0;
        while (i < 81) {
            if (grid[i] != 0 || _vis[i] == vGen) { i = i + 1; continue; }

            _gen = _gen + 1;
            var rGen = _gen;
            var sTop = 0; var regSz = 0;
            var hasB = 0; var hasW = 0;

            _vis[i] = rGen; _stk[sTop] = i; sTop = sTop + 1;

            while (sTop > 0) {
                sTop = sTop - 1;
                var idx = _stk[sTop];
                _vis[idx] = vGen;   // globally consumed by this calcScore call
                regSz = regSz + 1;
                var tx = idx % 9; var ty = idx / 9;

                var tN = idx - 9; var tS = idx + 9;
                var tW = idx - 1; var tE = idx + 1;

                if (ty > 0) {
                    if      (grid[tN] == 0 && _vis[tN] != rGen && _vis[tN] != vGen) {
                        _vis[tN] = rGen; _stk[sTop] = tN; sTop = sTop + 1;
                    } else if (grid[tN] == 1) { hasB = 1; }
                    else if  (grid[tN] == 2) { hasW = 1; }
                }
                if (ty < 8) {
                    if      (grid[tS] == 0 && _vis[tS] != rGen && _vis[tS] != vGen) {
                        _vis[tS] = rGen; _stk[sTop] = tS; sTop = sTop + 1;
                    } else if (grid[tS] == 1) { hasB = 1; }
                    else if  (grid[tS] == 2) { hasW = 1; }
                }
                if (tx > 0) {
                    if      (grid[tW] == 0 && _vis[tW] != rGen && _vis[tW] != vGen) {
                        _vis[tW] = rGen; _stk[sTop] = tW; sTop = sTop + 1;
                    } else if (grid[tW] == 1) { hasB = 1; }
                    else if  (grid[tW] == 2) { hasW = 1; }
                }
                if (tx < 8) {
                    if      (grid[tE] == 0 && _vis[tE] != rGen && _vis[tE] != vGen) {
                        _vis[tE] = rGen; _stk[sTop] = tE; sTop = sTop + 1;
                    } else if (grid[tE] == 1) { hasB = 1; }
                    else if  (grid[tE] == 2) { hasW = 1; }
                }
            }

            if      (hasB == 1 && hasW == 0) { bTerr = bTerr + regSz; }
            else if (hasW == 1 && hasB == 0) { wTerr = wTerr + regSz; }
            i = i + 1;
        }

        // Japanese scoring: territory + opponent captures + komi
        scoreBlack = bTerr + capWhite;
        scoreWhite = wTerr + capBlack + 7;
    }
}
