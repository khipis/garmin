using Toybox.Math;

// AI opponent.
//
// Single-ply greedy heuristic — safe on all hardware.
//
// Evaluation layers (highest priority first):
//   1. Always grab an available corner immediately.
//   2. Position weight * 3  (corners +40*3, X-squares −20*3, edges +20*3, …)
//   3. X-square penalty: −25 when the adjacent corner is still empty.
//   4. Flip count (secondary positional gain).
//   5. Corner-exposure penalty: −50 for each corner a simulated move hands to the opponent.
//   6. Small random noise for tie-breaking.
// Mobility counting removed — too expensive for AI vs AI on real hardware.

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

    // Full evaluation for placing 'col' at (x, y).
    // Temporarily applies the move to measure opponent mobility and corner exposure,
    // then restores the board.  Uses _board.flipBuf directly — isValidAt is read-only
    // and never corrupts flipBuf, so no extra buffer is needed.
    hidden function _evalMove(idx, x, y, col, opp) {
        var score = _wt[idx] * 3;

        // X-square penalty: (1,1),(6,1),(1,6),(6,6) → indices 9,14,49,54.
        // Penalise only when the diagonally-adjacent corner is still empty.
        if (idx == 9)  { if (_board.cells[0]  == 0) { score = score - 25; } }
        if (idx == 14) { if (_board.cells[7]  == 0) { score = score - 25; } }
        if (idx == 49) { if (_board.cells[56] == 0) { score = score - 25; } }
        if (idx == 54) { if (_board.cells[63] == 0) { score = score - 25; } }

        // Flip count — secondary mobility gain.
        _board.collectFlips(x, y, col);
        var flipSaved = _board.flipCount;
        score = score + flipSaved;

        // Apply move temporarily (direct cell writes — no counter updates needed).
        _board.cells[y * 8 + x] = col;
        var fi = 0;
        while (fi < flipSaved) { _board.cells[_board.flipBuf[fi]] = col; fi = fi + 1; }

        // Corner-exposure penalty: each corner that becomes available to the opponent.
        if (_board.cells[0]  == 0 && _board.isValidAt(0, 0, opp)) { score = score - 50; }
        if (_board.cells[7]  == 0 && _board.isValidAt(7, 0, opp)) { score = score - 50; }
        if (_board.cells[56] == 0 && _board.isValidAt(0, 7, opp)) { score = score - 50; }
        if (_board.cells[63] == 0 && _board.isValidAt(7, 7, opp)) { score = score - 50; }

        // Undo move (flipBuf is unchanged since isValidAt is read-only).
        _board.cells[y * 8 + x] = 0;
        fi = 0;
        while (fi < flipSaved) { _board.cells[_board.flipBuf[fi]] = opp; fi = fi + 1; }

        score = score + Math.rand() % 3;
        return score;
    }
}
