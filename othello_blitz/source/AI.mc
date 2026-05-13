using Toybox.Math;

// AI opponent.
//
// Single-ply greedy heuristic — safe on all hardware.
//
// Evaluation layers (highest priority first):
//   1. Always grab an available corner immediately.
//   2. Position weight * 3  (corners +120, X-squares −36, edges +60, …)
//   3. X-square penalty: −30 when the adjacent corner is still empty.
//   4. Corner-exposure penalty: −60 per corner handed to opponent.
//   5. Flip count × 2 (secondary territorial gain).
//   6. Edge-stability proxy: own edge/corner pieces − opp edge/corner pieces (×5).
//      Replaces full mobility count — O(28) vs O(64×8×8=4096) per candidate.
//   7. Small random noise for tie-breaking.
//
// Full _countMobility was removed (O(64×isValidAt) per candidate × 64 candidates
// = ~1M ops / turn — trips the watchdog on real hardware).

class AI {
    hidden var _board;
    hidden var _wt;   // int[64] — position weight table

    function initialize(board) {
        _board = board;
        _wt    = new [64];

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

    // Returns flat index of the best move for 'aiColor', or -1 to pass.
    function chooseMove(aiColor) {
        // Always take an available corner immediately.
        if (_board.cells[0]  == 0 && _board.isValidAt(0, 0, aiColor)) { return 0;  }
        if (_board.cells[7]  == 0 && _board.isValidAt(7, 0, aiColor)) { return 7;  }
        if (_board.cells[56] == 0 && _board.isValidAt(0, 7, aiColor)) { return 56; }
        if (_board.cells[63] == 0 && _board.isValidAt(7, 7, aiColor)) { return 63; }

        var opp       = (aiColor == 1) ? 2 : 1;
        var bestScore = -999999;
        var bestMove  = -1;
        var i = 0;
        while (i < 64) {
            if (_board.cells[i] != 0) { i = i + 1; continue; }
            var mx = i % 8; var my = i / 8;
            if (!_board.isValidAt(mx, my, aiColor)) { i = i + 1; continue; }
            var score = _evalMove(i, mx, my, aiColor, opp);
            if (score > bestScore) { bestScore = score; bestMove = i; }
            i = i + 1;
        }
        return bestMove;
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

        score = score + Math.rand() % 3;
        return score;
    }
}
