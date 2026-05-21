using Toybox.Math;

// AI opponent — iterative (no recursion).
//
// Difficulty:
//   DIFF_EASY (0) — single-ply scored move + random noise.
//   DIFF_MED  (1) — single-ply scored move, no noise (always best static eval).
//   DIFF_HARD (2) — iterative 2-ply minimax with corner-pass shortcut.
//                   Top-K shortlisted candidates only (avoids watchdog).
//
// All searches are iterative (no recursion). 2-ply walks every legal AI move,
// then for each — every legal opponent reply, scores the resulting position
// with the same static evaluator, and picks the AI move minimising opponent's
// best reply (minimax).

class AI {
    hidden var _board;
    hidden var _wt;       // int[64] — position weight table
    hidden var _diff;     // difficulty 0..2
    // Scratch storage used during 2-ply analysis (no allocations per move).
    hidden var _saveCells;      // int[64] — snapshot of cells before AI ply
    hidden var _moveBuf;        // int[64] — AI candidate moves (flat indices)
    hidden var _moveScore;      // int[64] — static score of each candidate
    hidden var _aiFlipSave;     // int[64] — flips applied by AI ply (for undo)
    hidden var _aiFlipSaveCnt;  // count

    function initialize(board) {
        _board = board;
        _wt    = new [64];
        _diff  = 1;
        _saveCells     = new [64];
        _moveBuf       = new [64];
        _moveScore     = new [64];
        _aiFlipSave    = new [64];
        _aiFlipSaveCnt = 0;

        // Row 0
        _wt[0]=40;  _wt[1]=-12; _wt[2]=20;  _wt[3]=20;
        _wt[4]=20;  _wt[5]=20;  _wt[6]=-12; _wt[7]=40;
        // Row 1
        _wt[8]=-12;  _wt[9]=-20; _wt[10]=-5; _wt[11]=-5;
        _wt[12]=-5;  _wt[13]=-5; _wt[14]=-20; _wt[15]=-12;
        // Row 2
        _wt[16]=20;  _wt[17]=-5;  _wt[18]=10; _wt[19]=0;
        _wt[20]=0;   _wt[21]=10;  _wt[22]=-5; _wt[23]=20;
        // Row 3
        _wt[24]=20;  _wt[25]=-5;  _wt[26]=0;  _wt[27]=10;
        _wt[28]=10;  _wt[29]=0;   _wt[30]=-5; _wt[31]=20;
        // Row 4 (mirror of row 3)
        _wt[32]=20;  _wt[33]=-5;  _wt[34]=0;  _wt[35]=10;
        _wt[36]=10;  _wt[37]=0;   _wt[38]=-5; _wt[39]=20;
        // Row 5 (mirror of row 2)
        _wt[40]=20;  _wt[41]=-5;  _wt[42]=10; _wt[43]=0;
        _wt[44]=0;   _wt[45]=10;  _wt[46]=-5; _wt[47]=20;
        // Row 6 (mirror of row 1)
        _wt[48]=-12; _wt[49]=-20; _wt[50]=-5; _wt[51]=-5;
        _wt[52]=-5;  _wt[53]=-5;  _wt[54]=-20; _wt[55]=-12;
        // Row 7 (mirror of row 0)
        _wt[56]=40;  _wt[57]=-12; _wt[58]=20; _wt[59]=20;
        _wt[60]=20;  _wt[61]=20;  _wt[62]=-12; _wt[63]=40;
    }

    function setDifficulty(d) { _diff = d; }

    // Returns flat index of the best move for 'aiColor', or -1 to pass.
    function chooseMove(aiColor) {
        // Always take an available corner immediately.
        if (_board.cells[0]  == 0 && _board.isValidAt(0, 0, aiColor)) { return 0;  }
        if (_board.cells[7]  == 0 && _board.isValidAt(7, 0, aiColor)) { return 7;  }
        if (_board.cells[56] == 0 && _board.isValidAt(0, 7, aiColor)) { return 56; }
        if (_board.cells[63] == 0 && _board.isValidAt(7, 7, aiColor)) { return 63; }

        var opp = (aiColor == 1) ? 2 : 1;

        // Collect candidate moves + 1-ply static scores (every difficulty needs this).
        var nCand = _collectCandidates(aiColor, opp);
        if (nCand == 0) { return -1; }

        // EASY/MED — single-ply pick using FULL eval (corner exposure + edge stability).
        if (_diff < 2) {
            return _pickBestFullEval(nCand, aiColor, opp);
        }

        // HARD — 2-ply iterative minimax over the top-K shortlisted candidates.
        //
        // K = 3 (was 5) and _collectCandidates uses _quickEval (weights+flips only)
        // for shortlisting. Corner exposure is NOT lost: 2-ply's _bestOppReply has
        // a corner-grab early exit that returns +200 if AI's move hands a corner,
        // making such moves auto-rejected by the (own − opp) delta.
        //
        // Cost budget: _collectCandidates ~2.8K + 3 × bestOppReply ~12.4K + setup
        // ≈ 16K ops/turn — well under the watchdog on slow devices.
        var topK = (nCand < 3) ? nCand : 3;
        _partialSortDesc(nCand, topK);
        return _twoPlySearch(aiColor, opp, topK);
    }

    // Collect all legal moves with CHEAP 1-ply scores (weights + flips only).
    // Used as a fast shortlist for the 2-ply refinement which adds back the
    // full corner/edge analysis via its own deeper-look heuristics.
    hidden function _collectCandidates(aiColor, opp) {
        var n = 0;
        var i = 0;
        while (i < 64) {
            if (_board.cells[i] == 0) {
                var mx = i % 8; var my = i / 8;
                if (_board.isValidAt(mx, my, aiColor)) {
                    _moveBuf[n]   = i;
                    _moveScore[n] = _quickEval(i, mx, my, aiColor);
                    n = n + 1;
                }
            }
            i = i + 1;
        }
        return n;
    }

    // Easy/Med picker — uses the FULL _evalMove (with corner exposure + edge
    // stability) since there's no 2-ply refinement to catch bad exposure.
    // Re-scores the candidates collected by _collectCandidates with full eval.
    hidden function _pickBestFullEval(nCand, aiColor, opp) {
        var bestS = -999999; var bestI = -1;
        var i = 0;
        while (i < nCand) {
            var idx = _moveBuf[i];
            var mx  = idx % 8; var my = idx / 8;
            var s   = _evalMove(idx, mx, my, aiColor, opp);
            if (s > bestS) { bestS = s; bestI = idx; }
            i = i + 1;
        }
        return bestI;
    }

    // Pick highest static score (EASY may add noise via _evalMove).
    hidden function _pickBestStatic(nCand) {
        var bestS = -999999; var bestI = -1;
        var i = 0;
        while (i < nCand) {
            if (_moveScore[i] > bestS) { bestS = _moveScore[i]; bestI = _moveBuf[i]; }
            i = i + 1;
        }
        return bestI;
    }

    // Iterative 2-ply: for each top-K AI move, simulate; enumerate opponent
    // replies; score each; AI move's value = own static − best opponent.
    // No recursion — two flat loops with manual apply/undo via snapshot.
    hidden function _twoPlySearch(aiColor, opp, topK) {
        var best     = -999999;
        var bestMove = _moveBuf[0];

        // Snapshot cells before any simulation.
        var s = 0; while (s < 64) { _saveCells[s] = _board.cells[s]; s = s + 1; }

        var k = 0;
        while (k < topK) {
            var m  = _moveBuf[k];
            var mx = m % 8; var my = m / 8;

            // Apply AI move physically (mutates _board.cells; flips collected).
            _board.collectFlips(mx, my, aiColor);
            var fc = _board.flipCount;
            _aiFlipSaveCnt = fc;
            var fi = 0; while (fi < fc) { _aiFlipSave[fi] = _board.flipBuf[fi]; fi = fi + 1; }
            _board.cells[m] = aiColor;
            fi = 0; while (fi < fc) { _board.cells[_aiFlipSave[fi]] = aiColor; fi = fi + 1; }

            var worstOpp = _bestOppReply(aiColor, opp);

            // Undo: restore from snapshot (fast & correct).
            var r = 0; while (r < 64) { _board.cells[r] = _saveCells[r]; r = r + 1; }

            // AI move's value: own static eval − worst opponent score.
            var v = _moveScore[k] - worstOpp;
            if (v > best) { best = v; bestMove = m; }
            k = k + 1;
        }
        return bestMove;
    }

    // Find max opp-quick-eval over all opp replies on the current (post-AI) board.
    //
    // Performance: uses _quickEval (no corner-isValidAt, no edge-stability) to
    // stay under the watchdog. The full _evalMove was costing ~300 ops per call
    // and being invoked up to 12×10=120 times → ~36k ops just here. Quick eval
    // drops that to ~60 ops/call ≈ 7k ops total.
    //
    // Early-exit: if opponent can grab any corner, we already know this AI move
    // is a disaster — return a huge positive (worst for AI) without scanning more.
    //
    // If opponent has no moves, return -200 (good for AI — opp wastes a turn).
    hidden function _bestOppReply(aiColor, opp) {
        // Fast corner-grab early exit: corners worth ~3*40 = 120 in weight alone.
        if (_board.cells[0]  == 0 && _board.isValidAt(0, 0, opp)) { return 200; }
        if (_board.cells[7]  == 0 && _board.isValidAt(7, 0, opp)) { return 200; }
        if (_board.cells[56] == 0 && _board.isValidAt(0, 7, opp)) { return 200; }
        if (_board.cells[63] == 0 && _board.isValidAt(7, 7, opp)) { return 200; }

        var maxOpp = -200;
        var any    = false;
        var j = 0;
        while (j < 64) {
            if (_board.cells[j] == 0) {
                var ox = j % 8; var oy = j / 8;
                if (_board.isValidAt(ox, oy, opp)) {
                    any = true;
                    var s = _quickEval(j, ox, oy, opp);
                    if (s > maxOpp) { maxOpp = s; }
                }
            }
            j = j + 1;
        }
        if (!any) { return -200; }
        return maxOpp;
    }

    // Cheap inner-ply evaluator — weights + flip count only. ~10 ops + collectFlips.
    // No move application, no corner exposure check, no edge-stability. Used only
    // inside the 2-ply opponent reply scan where speed matters more than accuracy.
    hidden function _quickEval(idx, x, y, col) {
        var score = _wt[idx] * 3;
        // X-square penalty: adjacent corner still empty → dangerous
        if (idx == 9)  { if (_board.cells[0]  == 0) { score = score - 30; } }
        if (idx == 14) { if (_board.cells[7]  == 0) { score = score - 30; } }
        if (idx == 49) { if (_board.cells[56] == 0) { score = score - 30; } }
        if (idx == 54) { if (_board.cells[63] == 0) { score = score - 30; } }
        _board.collectFlips(x, y, col);
        score = score + _board.flipCount * 2;
        return score;
    }

    // Partial selection sort: bring top-K (by _moveScore) to front of _moveBuf.
    // O(K*nCand) — fast for K≤10.
    hidden function _partialSortDesc(nCand, k) {
        var lim = (k < nCand) ? k : nCand;
        var i = 0;
        while (i < lim) {
            var bestJ = i;
            var bestS = _moveScore[i];
            var j = i + 1;
            while (j < nCand) {
                if (_moveScore[j] > bestS) { bestS = _moveScore[j]; bestJ = j; }
                j = j + 1;
            }
            if (bestJ != i) {
                var t = _moveBuf[i];   _moveBuf[i]   = _moveBuf[bestJ];   _moveBuf[bestJ]   = t;
                var u = _moveScore[i]; _moveScore[i] = _moveScore[bestJ]; _moveScore[bestJ] = u;
            }
            i = i + 1;
        }
    }

    // Edge-stability proxy: own vs opp pieces on the 28 edge/border cells.
    // Edge pieces are harder to flip → approximates stable mobility advantage.
    // Cost: 28 array reads — O(28) vs O(64×8×8) for full mobility scan.
    hidden function _edgeStability(col, opp) {
        var own = 0; var opp2 = 0;
        var ei = 0;
        // Top row (0..7) and bottom row (56..63)
        while (ei < 8) {
            var tv = _board.cells[ei]; var bv = _board.cells[56 + ei];
            if (tv == col) { own = own + 1; } else if (tv == opp) { opp2 = opp2 + 1; }
            if (bv == col) { own = own + 1; } else if (bv == opp) { opp2 = opp2 + 1; }
            ei = ei + 1;
        }
        // Left col (8,16,24,32,40,48) and right col (15,23,31,39,47,55) — skip corners
        ei = 1;
        while (ei <= 6) {
            var lv = _board.cells[ei * 8]; var rv = _board.cells[ei * 8 + 7];
            if (lv == col) { own = own + 1; } else if (lv == opp) { opp2 = opp2 + 1; }
            if (rv == col) { own = own + 1; } else if (rv == opp) { opp2 = opp2 + 1; }
            ei = ei + 1;
        }
        return own - opp2;
    }

    // Evaluate placing 'col' at (x, y).
    // Watchdog budget: ~200 ops per candidate × 64 candidates = ~12 800 ops/turn.
    hidden function _evalMove(idx, x, y, col, opp) {
        var score = _wt[idx] * 3;

        // X-square penalty: adjacent corner still empty → dangerous
        if (idx == 9)  { if (_board.cells[0]  == 0) { score = score - 30; } }
        if (idx == 14) { if (_board.cells[7]  == 0) { score = score - 30; } }
        if (idx == 49) { if (_board.cells[56] == 0) { score = score - 30; } }
        if (idx == 54) { if (_board.cells[63] == 0) { score = score - 30; } }

        // Collect flips for the simulated move
        _board.collectFlips(x, y, col);
        var flipSaved = _board.flipCount;
        score = score + flipSaved * 2;

        // Apply move temporarily
        _board.cells[y * 8 + x] = col;
        var fi = 0;
        while (fi < flipSaved) { _board.cells[_board.flipBuf[fi]] = col; fi = fi + 1; }

        // Corner-exposure penalty: −60 per corner we hand to the opponent
        if (_board.cells[0]  == 0 && _board.isValidAt(0, 0, opp)) { score = score - 60; }
        if (_board.cells[7]  == 0 && _board.isValidAt(7, 0, opp)) { score = score - 60; }
        if (_board.cells[56] == 0 && _board.isValidAt(0, 7, opp)) { score = score - 60; }
        if (_board.cells[63] == 0 && _board.isValidAt(7, 7, opp)) { score = score - 60; }

        // Edge-stability proxy (O(28) — replaces full mobility scan)
        score = score + _edgeStability(col, opp) * 5;

        // Undo move
        _board.cells[y * 8 + x] = 0;
        fi = 0;
        while (fi < flipSaved) { _board.cells[_board.flipBuf[fi]] = opp; fi = fi + 1; }

        // Easy: large noise so AI sometimes blunders.
        // Med/Hard: tiny tie-breaker only.
        if (_diff == 0) { score = score + Math.rand() % 25; }
        else            { score = score + Math.rand() % 3;  }
        return score;
    }
}
