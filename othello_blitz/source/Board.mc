// Board — 8×8 Othello/Reversi board.
//
// cells[y*8+x]: 0 = empty, DISC_BLACK = 1, DISC_WHITE = 2
//
// Core API:
//   isValidAt(x,y,col)       – fast O(8*8) validity check, no side effects
//   hasValidMoves(col)       – any valid move exists for 'col'?
//   collectFlips(x,y,col)    – fills flipBuf[0..flipCount-1], no board change
//   placeDisc(x,y,col)       – places disc, populates flipBuf (flips NOT applied yet)
//   applyFlips(col)          – commits flipBuf to cells (call after animation)

class Board {
    var cells;       // int[64]
    var flipBuf;     // int[64] — flip indices from last placeDisc/collectFlips
    var flipCount;   // valid entries in flipBuf
    var blackCount;  // black discs on board (kept in sync)
    var whiteCount;  // white discs on board

    function initialize() {
        cells      = new [64];
        flipBuf    = new [64];
        flipCount  = 0;
        blackCount = 0; whiteCount = 0;
        newGame();
    }

    function newGame() {
        var i = 0;
        while (i < 64) { cells[i] = 0; i = i + 1; }
        // Standard starting position
        cells[27] = DISC_WHITE;  // (3,3)
        cells[28] = DISC_BLACK;  // (4,3)
        cells[35] = DISC_BLACK;  // (3,4)
        cells[36] = DISC_WHITE;  // (4,4)
        blackCount = 2; whiteCount = 2;
        flipCount  = 0;
    }

    // ── Quick validity check (no side effects) ────────────────────────────
    function isValidAt(x, y, col) {
        if (cells[y * 8 + x] != 0) { return false; }
        var opp = (col == 1) ? 2 : 1;
        return (_qd(x, y, col, opp, -1, -1) || _qd(x, y, col, opp,  0, -1) ||
                _qd(x, y, col, opp,  1, -1) || _qd(x, y, col, opp, -1,  0) ||
                _qd(x, y, col, opp,  1,  0) || _qd(x, y, col, opp, -1,  1) ||
                _qd(x, y, col, opp,  0,  1) || _qd(x, y, col, opp,  1,  1));
    }

    function hasValidMoves(col) {
        var i = 0;
        while (i < 64) {
            if (cells[i] == 0 && isValidAt(i % 8, i / 8, col)) { return true; }
            i = i + 1;
        }
        return false;
    }

    // Returns true if (dx,dy) scan from (x,y) has at least one flippable opponent disc.
    hidden function _qd(x, y, col, opp, dx, dy) {
        var cx = x + dx; var cy = y + dy;
        var cnt = 0;
        while (cx >= 0 && cx <= 7 && cy >= 0 && cy <= 7) {
            var v = cells[cy * 8 + cx];
            if      (v == opp) { cnt = cnt + 1; }
            else if (v == col) { if (cnt > 0) { return true; } return false; }
            else               { return false; }  // empty — breaks chain
            cx = cx + dx; cy = cy + dy;
        }
        return false;
    }

    // ── Flip collection ──────────────────────────────────────────────────
    // Populates flipBuf/flipCount for placing 'col' at (x,y).
    // Does NOT modify cells.  Returns flipCount (0 = invalid move).
    function collectFlips(x, y, col) {
        flipCount = 0;
        if (cells[y * 8 + x] != 0) { return 0; }
        var opp = (col == 1) ? 2 : 1;
        _cd(x, y, col, opp, -1, -1); _cd(x, y, col, opp,  0, -1); _cd(x, y, col, opp,  1, -1);
        _cd(x, y, col, opp, -1,  0);                                _cd(x, y, col, opp,  1,  0);
        _cd(x, y, col, opp, -1,  1); _cd(x, y, col, opp,  0,  1); _cd(x, y, col, opp,  1,  1);
        return flipCount;
    }

    // Collect flips in one direction; roll back if no own-disc anchor is found.
    hidden function _cd(x, y, col, opp, dx, dy) {
        var cx = x + dx; var cy = y + dy;
        var ts = flipCount;  // rollback point
        while (cx >= 0 && cx <= 7 && cy >= 0 && cy <= 7) {
            var v = cells[cy * 8 + cx];
            if (v == opp) {
                flipBuf[flipCount] = cy * 8 + cx;
                flipCount = flipCount + 1;
            } else if (v == col) {
                if (flipCount > ts) { return; }  // committed — success
                flipCount = ts; return;            // adjacent own disc — no chain
            } else {
                flipCount = ts; return;            // empty — roll back
            }
            cx = cx + dx; cy = cy + dy;
        }
        flipCount = ts;  // hit edge without anchor — roll back
    }

    // Place disc of 'col' at (x,y).  Populates flipBuf but does NOT flip yet.
    // Returns false if the move is invalid.
    function placeDisc(x, y, col) {
        if (collectFlips(x, y, col) == 0) { return false; }
        cells[y * 8 + x] = col;
        if (col == DISC_BLACK) { blackCount = blackCount + 1; }
        else                   { whiteCount = whiteCount + 1; }
        return true;
    }

    // Apply stored flipBuf to cells (call once animation is complete).
    function applyFlips(col) {
        var i = 0;
        while (i < flipCount) { cells[flipBuf[i]] = col; i = i + 1; }
        if (col == DISC_BLACK) {
            blackCount = blackCount + flipCount;
            whiteCount = whiteCount - flipCount;
        } else {
            whiteCount = whiteCount + flipCount;
            blackCount = blackCount - flipCount;
        }
    }
}
