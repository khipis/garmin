using Toybox.Math;

// AI opponent (plays as White).
//
// Strategy (heuristics, no full tree search):
//   1. Capture opponent groups with exactly 1 liberty (atari).
//   2. Save own groups with exactly 1 liberty.
//   3. Score all empty intersections by heuristic; pick the best.
//      Heuristic: centre preference + neighbour analysis +
//                 territory influence + self-atari penalty + random noise.
//
// Watchdog safety: 81 cells × _evalMove(4 × _scoreNb(getGroupLiberties~81 ops)
//   + 25 influence scan + _estLibsAfterPlace(4 × getGroupLiberties)) ≈ 81 × 673 ≈ 54K ops.
// All decisions are O(81) or O(81 × 25) — fast enough for 30 FPS.

class AI {
    hidden var _board;  // reference to the shared Board instance
    hidden var _diff;   // 0=Easy  1=Med  2=Hard

    function initialize(board) {
        _board = board;
        _diff  = 1;
    }

    function setDiff(d) { _diff = d; }

    // Returns grid index of best move for 'aiColor', or -1 to pass.
    // Hard: first check for immediate captures (atari captures) — highest priority.
    function chooseMove(aiColor) {
        var opp        = (aiColor == 1) ? 2 : 1;
        var bestScore  = -9999;
        var bestMove   = -1;

        // Phase 0 (Hard only): urgent capture — take any opp group in atari.
        // Only attempt if self-atari estimate > 0 (not suicide after the capture).
        if (_diff == 2) {
            var i = 0;
            while (i < 81) {
                if (_board.grid[i] == 0) {
                    var x = i % 9; var y = i / 9;
                    var captures = false;
                    if (y > 0    && _board.grid[i - 9] == opp && _board.getGroupLiberties(i - 9) == 1) { captures = true; }
                    if (y < 8    && _board.grid[i + 9] == opp && _board.getGroupLiberties(i + 9) == 1) { captures = true; }
                    if (x > 0    && _board.grid[i - 1] == opp && _board.getGroupLiberties(i - 1) == 1) { captures = true; }
                    if (x < 8    && _board.grid[i + 1] == opp && _board.getGroupLiberties(i + 1) == 1) { captures = true; }
                    if (captures) {
                        var libs = _estLibsAfterPlace(i, aiColor);
                        if (libs > 0) { return i; }
                    }
                }
                i = i + 1;
            }
            // Phase 0b: save own group in atari.
            i = 0;
            while (i < 81) {
                if (_board.grid[i] == 0) {
                    var x = i % 9; var y = i / 9;
                    var savesAtari = false;
                    if (y > 0    && _board.grid[i - 9] == aiColor && _board.getGroupLiberties(i - 9) == 1) { savesAtari = true; }
                    if (y < 8    && _board.grid[i + 9] == aiColor && _board.getGroupLiberties(i + 9) == 1) { savesAtari = true; }
                    if (x > 0    && _board.grid[i - 1] == aiColor && _board.getGroupLiberties(i - 1) == 1) { savesAtari = true; }
                    if (x < 8    && _board.grid[i + 1] == aiColor && _board.getGroupLiberties(i + 1) == 1) { savesAtari = true; }
                    if (savesAtari) {
                        var libs = _estLibsAfterPlace(i, aiColor);
                        if (libs >= 2) { return i; }
                    }
                }
                i = i + 1;
            }
        }

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
        // Stronger centre weight for Hard, and bonus for 3-3 points (joseki positions)
        var centreW = (_diff == 2) ? 12 : 8;
        var score = centreW - (dx + dy);

        // ── Neighbour analysis (all 4 directions) ────────────────────────
        var adjOwn = 0;
        if (y > 0) {
            score = score + _scoreNb(idx - 9, aiColor, opp);
            if (_board.grid[idx - 9] == aiColor) { adjOwn++; }
        }
        if (y < 8) {
            score = score + _scoreNb(idx + 9, aiColor, opp);
            if (_board.grid[idx + 9] == aiColor) { adjOwn++; }
        }
        if (x > 0) {
            score = score + _scoreNb(idx - 1, aiColor, opp);
            if (_board.grid[idx - 1] == aiColor) { adjOwn++; }
        }
        if (x < 8) {
            score = score + _scoreNb(idx + 1, aiColor, opp);
            if (_board.grid[idx + 1] == aiColor) { adjOwn++; }
        }

        // ── Good-shape bonus: connected to own group with breathing room ─
        if (adjOwn >= 1) {
            var openN = 0;
            var gsc;
            if (y > 0) { gsc = _board.grid[idx - 9]; if (gsc == 0 || gsc == aiColor) { openN++; } }
            if (y < 8) { gsc = _board.grid[idx + 9]; if (gsc == 0 || gsc == aiColor) { openN++; } }
            if (x > 0) { gsc = _board.grid[idx - 1]; if (gsc == 0 || gsc == aiColor) { openN++; } }
            if (x < 8) { gsc = _board.grid[idx + 1]; if (gsc == 0 || gsc == aiColor) { openN++; } }
            if (openN >= 3) { score = score + 3; }
        }

        // ── Territory influence: own vs opponent within Manhattan ≤ 2 ────
        var ownNear = 0; var oppNear = 0;
        var minX = x - 2; if (minX < 0) { minX = 0; }
        var maxX = x + 2; if (maxX > 8) { maxX = 8; }
        var minY = y - 2; if (minY < 0) { minY = 0; }
        var maxY = y + 2; if (maxY > 8) { maxY = 8; }
        var iy = minY;
        while (iy <= maxY) {
            var ix = minX;
            while (ix <= maxX) {
                var mdy = iy - y; if (mdy < 0) { mdy = -mdy; }
                var mdx = ix - x; if (mdx < 0) { mdx = -mdx; }
                if (mdy + mdx > 0 && mdy + mdx <= 2) {
                    var v = _board.grid[iy * 9 + ix];
                    if      (v == aiColor) { ownNear++; }
                    else if (v == opp)     { oppNear++; }
                }
                ix = ix + 1;
            }
            iy = iy + 1;
        }
        var infBonus = (_diff == 2) ? 6 : 3;
        score = score + (ownNear - oppNear) * infBonus;

        // ── Self-atari penalty ───────────────────────────────────────────
        var estLibs = _estLibsAfterPlace(idx, aiColor);
        if (estLibs <= 0) {
            score = score - 999;  // absolute suicide — never do this
        } else if (estLibs == 1) {
            var penalty = (_diff == 2) ? -30 : -15;
            score = score + penalty;
        }

        // ── Opponent atari threat bonus ──────────────────────────────────
        // Placing here puts opp groups in atari (1 liberty) — large bonus.
        if (y > 0    && _board.grid[idx - 9] == opp && _board.getGroupLiberties(idx - 9) == 2) { score = score + 8; }
        if (y < 8    && _board.grid[idx + 9] == opp && _board.getGroupLiberties(idx + 9) == 2) { score = score + 8; }
        if (x > 0    && _board.grid[idx - 1] == opp && _board.getGroupLiberties(idx - 1) == 2) { score = score + 8; }
        if (x < 8    && _board.grid[idx + 1] == opp && _board.getGroupLiberties(idx + 1) == 2) { score = score + 8; }

        // Small random noise: breaks ties, adds variety
        var noiseRange = (_diff == 2) ? 2 : 4;
        score = score + Math.rand() % noiseRange;
        return score;
    }

    // Bonus for placing adjacent to the stone at 'nb'.
    hidden function _scoreNb(nb, aiColor, opp) {
        var c = _board.grid[nb];
        if (c == 0) { return 0; }

        var libs = _board.getGroupLiberties(nb);
        if (c == opp) {
            var capBonus = (_diff == 2) ? 40 : 20;
            if (libs == 1) { return capBonus; }  // capture (opponent in atari)
            if (libs == 2) { return  4; }         // threaten opponent
            return 2;                              // adjacent to opponent
        }
        // c == aiColor
        if (libs == 1) { return 8; }   // save own group (in atari)
        if (libs == 2) { return 3; }   // strengthen own group
        return 1;                       // extend territory
    }

    // Estimate liberties of the group after placing aiColor at idx.
    // Direct empty neighbours + merged group libs − 1 per adjacent own stone.
    // Overestimates slightly when groups share liberties — conservative for
    // penalty purposes (we only penalise when estimate ≤ 1).
    hidden function _estLibsAfterPlace(idx, aiColor) {
        var x = idx % 9; var y = idx / 9;
        var libs = 0;
        var nb; var c; var gl;
        if (y > 0) {
            nb = idx - 9; c = _board.grid[nb];
            if (c == 0) { libs++; }
            else if (c == aiColor) { gl = _board.getGroupLiberties(nb); if (gl > 1) { libs = libs + gl - 1; } }
        }
        if (y < 8) {
            nb = idx + 9; c = _board.grid[nb];
            if (c == 0) { libs++; }
            else if (c == aiColor) { gl = _board.getGroupLiberties(nb); if (gl > 1) { libs = libs + gl - 1; } }
        }
        if (x > 0) {
            nb = idx - 1; c = _board.grid[nb];
            if (c == 0) { libs++; }
            else if (c == aiColor) { gl = _board.getGroupLiberties(nb); if (gl > 1) { libs = libs + gl - 1; } }
        }
        if (x < 8) {
            nb = idx + 1; c = _board.grid[nb];
            if (c == 0) { libs++; }
            else if (c == aiColor) { gl = _board.getGroupLiberties(nb); if (gl > 1) { libs = libs + gl - 1; } }
        }
        return libs;
    }
}
