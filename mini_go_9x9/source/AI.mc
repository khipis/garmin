using Toybox.Math;

// AI opponent (plays as White).
//
// Strategy (simple heuristics, no full tree search):
//   1. Capture any opponent group with exactly 1 liberty.
//   2. Save own groups with exactly 1 liberty.
//   3. Score all empty intersections by heuristic; pick the best.
//      Heuristic: centre preference + neighbour analysis + small random noise.
//
// All decisions are O(81) or O(81 × group_size) — fast enough for 30 FPS.

class AI {
    hidden var _board;  // reference to the shared Board instance

    function initialize(board) {
        _board = board;
    }

    // Returns grid index of best move for 'aiColor', or -1 to pass.
    function chooseMove(aiColor) {
        var opp        = (aiColor == 1) ? 2 : 1;
        var bestScore  = -9999;
        var bestMove   = -1;

        var i = 0;
        while (i < 81) {
            if (_board.grid[i] != 0) { i = i + 1; continue; }
            var s = _evalMove(i, aiColor, opp);
            if (s > bestScore) { bestScore = s; bestMove = i; }
            i = i + 1;
        }
        return bestMove;
    }

    // Score a candidate empty intersection for 'aiColor'.
    hidden function _evalMove(idx, aiColor, opp) {
        var x = idx % 9; var y = idx / 9;

        // ── Centre preference (Manhattan distance from centre 4,4) ───────
        var dx = x - 4; if (dx < 0) { dx = -dx; }
        var dy = y - 4; if (dy < 0) { dy = -dy; }
        var score = 8 - dx - dy;

        // ── Neighbour analysis (all 4 directions) ────────────────────────
        if (y > 0) { score = score + _scoreNb(idx - 9, aiColor, opp); }
        if (y < 8) { score = score + _scoreNb(idx + 9, aiColor, opp); }
        if (x > 0) { score = score + _scoreNb(idx - 1, aiColor, opp); }
        if (x < 8) { score = score + _scoreNb(idx + 1, aiColor, opp); }

        // Small random noise: breaks ties, adds variety
        score = score + Math.rand() % 4;
        return score;
    }

    // Bonus for placing adjacent to the stone at 'nb'.
    hidden function _scoreNb(nb, aiColor, opp) {
        var c = _board.grid[nb];
        if (c == 0) { return 0; }  // empty neighbour

        var libs = _board.getGroupLiberties(nb);
        if (c == opp) {
            if (libs == 1) { return 12; }  // capture (opponent in atari)
            if (libs == 2) { return  4; }  // threaten opponent
            return 2;                       // adjacent to opponent
        }
        // c == aiColor
        if (libs == 1) { return 8; }   // save own group (in atari)
        if (libs == 2) { return 3; }   // strengthen own group
        return 1;                       // extend territory
    }
}
