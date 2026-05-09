using Toybox.Math;

// AI opponent (plays as White).
//
// Evaluation = position_weight * 3 + flip_count + small_random_noise
//
// Position weights encode classic Othello strategy:
//   Corners (+40) > edges (+20) > inner edges (-5/+10) > C-squares (-12) > X-squares (-20)
//
// No lookahead — pure single-ply greedy heuristic, runs in O(64 × 8 × 8) per move.

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
        var bestScore = -999999;
        var bestMove  = -1;
        var i = 0;
        while (i < 64) {
            if (_board.cells[i] != 0) { i = i + 1; continue; }
            var mx = i % 8; var my = i / 8;
            if (!_board.isValidAt(mx, my, aiColor)) { i = i + 1; continue; }
            var score = _evalMove(i, mx, my, aiColor);
            if (score > bestScore) { bestScore = score; bestMove = i; }
            i = i + 1;
        }
        return bestMove;
    }

    // Score = position_weight (dominant) + flip_count (secondary) + noise
    hidden function _evalMove(idx, x, y, col) {
        var score = _wt[idx] * 3;
        _board.collectFlips(x, y, col);      // sets _board.flipCount
        score = score + _board.flipCount;
        score = score + Math.rand() % 3;     // tie-breaking noise
        return score;
    }
}
