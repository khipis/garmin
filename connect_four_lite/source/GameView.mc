using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.Math;

// ── Board dimensions ───────────────────────────────────────────────────────
const COLS    = 7;
const ROWS    = 6;
const WIN_LEN = 4;

// ── Cell marks ────────────────────────────────────────────────────────────
const MARK_NONE = 0;
const MARK_P    = 1;   // human (red)
const MARK_AI   = 2;   // AI    (yellow)

// ── Game states ────────────────────────────────────────────────────────────
const GS_PLAY = 0;
const GS_AI   = 1;   // 350 ms pause, then AI moves
const GS_OVER = 2;

const OVER_NONE  = 0;
const OVER_PWIN  = 1;
const OVER_AIWIN = 2;
const OVER_DRAW  = 3;

// ── GameView ───────────────────────────────────────────────────────────────
class GameView extends WatchUi.View {

    // ── Layout ────────────────────────────────────────────────────────────
    hidden var _sw, _sh;
    hidden var _boardX, _boardY;  // top-left pixel of the grid
    hidden var _cell;             // pixels per cell
    hidden var _rad;              // disc radius

    // ── Board ─────────────────────────────────────────────────────────────
    hidden var _cells;       // int[COLS * ROWS] — row-major, row 0 = top
    hidden var _moveCount;
    hidden var _winLine;     // int[WIN_LEN] — winning cell indices

    // ── UI state ──────────────────────────────────────────────────────────
    hidden var _curCol;      // selected column (0-6)
    hidden var _state;       // GS_*
    hidden var _overType;    // OVER_*

    // ── Session score ─────────────────────────────────────────────────────
    hidden var _scoreP, _scoreAI;

    // ── Timer ─────────────────────────────────────────────────────────────
    hidden var _timer;

    // ─────────────────────────────────────────────────────────────────────
    function initialize() {
        View.initialize();
        _cells   = new [COLS * ROWS];
        _winLine = new [WIN_LEN];
        _scoreP  = 0;
        _scoreAI = 0;
        _timer   = null;
        _startGame();
    }

    function onLayout(dc) {
        _sw = dc.getWidth();
        _sh = dc.getHeight();

        // Board occupies ~70 % of screen width; cap to leave safe margins.
        _cell = _sw * 70 / 100 / COLS;
        if (_cell < 28) { _cell = 28; }
        _rad  = _cell / 2 - 2;

        // Centre board, shifted slightly down for column-selector + score HUD above.
        _boardX = (_sw - COLS * _cell) / 2;
        _boardY = (_sh - ROWS * _cell) / 2 + _sh * 4 / 100;

        _timer = new Timer.Timer();
        _timer.start(method(:gameTick), 350, true);
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); }
    }

    // ── Public input API ──────────────────────────────────────────────────

    // dir: -1 = left, +1 = right
    function moveColumn(dir) {
        if (_state != GS_PLAY) { return; }
        _curCol = _curCol + dir;
        if (_curCol < 0)     { _curCol = 0; }
        if (_curCol >= COLS) { _curCol = COLS - 1; }
    }

    function doAction() {
        if (_state == GS_OVER) { _startGame(); return; }
        if (_state != GS_PLAY) { return; }
        var r = _dropRow(_curCol);
        if (r < 0) { return; }           // column full — silently ignore
        _dropDisc(_curCol, r, MARK_P);
        if (_checkWin(MARK_P)) {
            _overType = OVER_PWIN; _scoreP = _scoreP + 1; _state = GS_OVER; return;
        }
        if (_moveCount == COLS * ROWS) { _overType = OVER_DRAW; _state = GS_OVER; return; }
        _state = GS_AI;                  // hand off; AI fires on next timer tick
    }

    // ── Timer tick ────────────────────────────────────────────────────────
    function gameTick() {
        if (_state != GS_AI) { return; }
        _aiDrop();
        if (_checkWin(MARK_AI)) {
            _overType = OVER_AIWIN; _scoreAI = _scoreAI + 1; _state = GS_OVER;
        } else if (_moveCount == COLS * ROWS) {
            _overType = OVER_DRAW; _state = GS_OVER;
        } else {
            _state = GS_PLAY;
        }
        WatchUi.requestUpdate();
    }

    // ── Game management ───────────────────────────────────────────────────

    hidden function _startGame() {
        var i = 0;
        while (i < COLS * ROWS) { _cells[i] = MARK_NONE; i = i + 1; }
        i = 0;
        while (i < WIN_LEN) { _winLine[i] = -1; i = i + 1; }
        _moveCount = 0;
        _curCol    = COLS / 2;
        _state     = GS_PLAY;
        _overType  = OVER_NONE;
    }

    // Returns the landing row for column 'col', or -1 if full.
    hidden function _dropRow(col) {
        var r = ROWS - 1;
        while (r >= 0) {
            if (_cells[r * COLS + col] == MARK_NONE) { return r; }
            r = r - 1;
        }
        return -1;
    }

    hidden function _dropDisc(col, row, mark) {
        _cells[row * COLS + col] = mark;
        _moveCount = _moveCount + 1;
    }

    // ── Win detection ─────────────────────────────────────────────────────
    // Scans all 69 length-4 windows. Populates _winLine when found.
    hidden function _checkWin(mark) {
        // Horizontal: rows 0-5, start cols 0-3
        var r = 0;
        while (r < ROWS) {
            var c = 0;
            while (c <= COLS - WIN_LEN) {
                if (_testLine(mark, c, r, 1, 0)) { return true; }
                c = c + 1;
            }
            r = r + 1;
        }
        // Vertical: cols 0-6, start rows 0-2
        var c2 = 0;
        while (c2 < COLS) {
            var r2 = 0;
            while (r2 <= ROWS - WIN_LEN) {
                if (_testLine(mark, c2, r2, 0, 1)) { return true; }
                r2 = r2 + 1;
            }
            c2 = c2 + 1;
        }
        // Diagonal ↘: rows 0-2, cols 0-3
        var r3 = 0;
        while (r3 <= ROWS - WIN_LEN) {
            var c3 = 0;
            while (c3 <= COLS - WIN_LEN) {
                if (_testLine(mark, c3, r3, 1, 1)) { return true; }
                c3 = c3 + 1;
            }
            r3 = r3 + 1;
        }
        // Diagonal ↙: rows 0-2, cols 3-6  (dx=-1, start x >= WIN_LEN-1)
        var r4 = 0;
        while (r4 <= ROWS - WIN_LEN) {
            var c4 = WIN_LEN - 1;
            while (c4 < COLS) {
                if (_testLine(mark, c4, r4, -1, 1)) { return true; }
                c4 = c4 + 1;
            }
            r4 = r4 + 1;
        }
        return false;
    }

    // Tests WIN_LEN cells from (c,r) in direction (dc,dr); stores indices in _winLine.
    hidden function _testLine(mark, c, r, dc, dr) {
        var k = 0;
        while (k < WIN_LEN) {
            if (_cells[(r + k * dr) * COLS + (c + k * dc)] != mark) { return false; }
            k = k + 1;
        }
        k = 0;
        while (k < WIN_LEN) {
            _winLine[k] = (r + k * dr) * COLS + (c + k * dc);
            k = k + 1;
        }
        return true;
    }

    // ── AI ────────────────────────────────────────────────────────────────

    hidden function _aiDrop() {
        // 1. Win immediately
        var col = _findWinningCol(MARK_AI);
        if (col >= 0) { _dropDisc(col, _dropRow(col), MARK_AI); return; }

        // 2. Block player's immediate win
        col = _findWinningCol(MARK_P);
        if (col >= 0) { _dropDisc(col, _dropRow(col), MARK_AI); return; }

        // 3. Best scored column (centre + line-extension heuristic)
        col = _bestScoredCol();
        if (col >= 0) { _dropDisc(col, _dropRow(col), MARK_AI); return; }

        // 4. Any valid column (safety fallback)
        var c = 0;
        while (c < COLS) {
            if (_dropRow(c) >= 0) { _dropDisc(c, _dropRow(c), MARK_AI); return; }
            c = c + 1;
        }
    }

    // Returns the first column where 'mark' can win immediately, or -1.
    hidden function _findWinningCol(mark) {
        var c = 0;
        while (c < COLS) {
            var r = _dropRow(c);
            if (r >= 0) {
                _cells[r * COLS + c] = mark;
                var wins = _checkWin(mark);
                _cells[r * COLS + c] = MARK_NONE;
                if (wins) { return c; }
            }
            c = c + 1;
        }
        return -1;
    }

    // Score each valid column; return the highest-scoring one.
    hidden function _bestScoredCol() {
        var best = -9999; var move = -1;
        var c = 0;
        while (c < COLS) {
            var score = _scoreCol(c);
            if (score > best) { best = score; move = c; }
            c = c + 1;
        }
        return move;
    }

    hidden function _scoreCol(col) {
        var r = _dropRow(col);
        if (r < 0) { return -9999; }

        // Centre-column preference (col 3 = max score)
        var mid = COLS / 2;
        var dd = col - mid; if (dd < 0) { dd = -dd; }
        var score = (mid - dd + 1) * 3;   // 12, 9, 6, 3 across cols 3→2→1→0/6

        // Temporarily place AI disc, measure how many consecutive same-colour
        // discs exist in each axis (not counting the placed disc itself).
        _cells[r * COLS + col] = MARK_AI;
        var h  = _axisLen(col, r, MARK_AI, 1,  0);
        var v  = _axisLen(col, r, MARK_AI, 0,  1);
        var d1 = _axisLen(col, r, MARK_AI, 1,  1);
        var d2 = _axisLen(col, r, MARK_AI, 1, -1);
        _cells[r * COLS + col] = MARK_NONE;

        if (h  >= 3) { score = score + 20; } else if (h  >= 2) { score = score + 8; } else if (h  >= 1) { score = score + 3; }
        if (v  >= 3) { score = score + 20; } else if (v  >= 2) { score = score + 8; } else if (v  >= 1) { score = score + 3; }
        if (d1 >= 3) { score = score + 20; } else if (d1 >= 2) { score = score + 8; } else if (d1 >= 1) { score = score + 3; }
        if (d2 >= 3) { score = score + 20; } else if (d2 >= 2) { score = score + 8; } else if (d2 >= 1) { score = score + 3; }

        score = score + Math.rand() % 4;
        return score;
    }

    // Count consecutive 'mark' discs in both directions along (dc,dr),
    // starting from the neighbours of (col, row) — does NOT count (col, row) itself.
    hidden function _axisLen(col, row, mark, dc, dr) {
        var cnt = 0;
        var cc = col + dc; var rr = row + dr;
        while (cc >= 0 && cc < COLS && rr >= 0 && rr < ROWS &&
               _cells[rr * COLS + cc] == mark) {
            cnt = cnt + 1; cc = cc + dc; rr = rr + dr;
        }
        cc = col - dc; rr = row - dr;
        while (cc >= 0 && cc < COLS && rr >= 0 && rr < ROWS &&
               _cells[rr * COLS + cc] == mark) {
            cnt = cnt + 1; cc = cc - dc; rr = rr - dr;
        }
        return cnt;
    }

    // ── Rendering ─────────────────────────────────────────────────────────
    function onUpdate(dc) {
        dc.setColor(0x060610, 0x060610);
        dc.clear();
        _drawBoard(dc);
        _drawSelector(dc);
        _drawHUD(dc);
        if (_state == GS_OVER) { _drawGameOver(dc); }
    }

    // ── Board ─────────────────────────────────────────────────────────────
    hidden function _drawBoard(dc) {
        var bw = COLS * _cell;
        var bh = ROWS * _cell;

        // Board frame / background
        dc.setColor(0x0A1850, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(_boardX - 3, _boardY - 3, bw + 6, bh + 6, 6);

        // Pre-compute ghost (drop-preview) row once to avoid 42 _dropRow calls.
        var ghostR = -1;
        if (_state == GS_PLAY) { ghostR = _dropRow(_curCol); }

        var r = 0;
        while (r < ROWS) {
            var c = 0;
            while (c < COLS) {
                var px = _boardX + c * _cell + _cell / 2;
                var py = _boardY + r * _cell + _cell / 2;
                var mark = _cells[r * COLS + c];
                var inWin = (_overType == OVER_PWIN || _overType == OVER_AIWIN) &&
                            _inWinLine(r * COLS + c);

                if (mark == MARK_P) {
                    // Player disc — red
                    dc.setColor(0xFF2200, Graphics.COLOR_TRANSPARENT);
                    dc.fillCircle(px, py, _rad);
                } else if (mark == MARK_AI) {
                    // AI disc — yellow
                    dc.setColor(0xFFCC00, Graphics.COLOR_TRANSPARENT);
                    dc.fillCircle(px, py, _rad);
                } else if (c == _curCol && r == ghostR) {
                    // Drop-preview ghost: dark-red fill with red outline
                    dc.setColor(0x3A0808, Graphics.COLOR_TRANSPARENT);
                    dc.fillCircle(px, py, _rad);
                    dc.setColor(0xFF3311, Graphics.COLOR_TRANSPARENT);
                    dc.drawCircle(px, py, _rad);
                } else {
                    // Empty slot
                    dc.setColor(0x101028, Graphics.COLOR_TRANSPARENT);
                    dc.fillCircle(px, py, _rad);
                }

                // Bright ring around each winning disc
                if (inWin) {
                    dc.setColor(0x00FF55, Graphics.COLOR_TRANSPARENT);
                    dc.drawCircle(px, py, _rad + 2);
                    dc.drawCircle(px, py, _rad + 3);
                }

                c = c + 1;
            }
            r = r + 1;
        }

        // Diagonal win line stroke (5 parallel lines for thickness)
        if (_overType == OVER_PWIN || _overType == OVER_AIWIN) {
            var w0 = _winLine[0]; var w3 = _winLine[WIN_LEN - 1];
            if (w0 >= 0 && w3 >= 0) {
                var lx1 = _boardX + (w0 % COLS) * _cell + _cell / 2;
                var ly1 = _boardY + (w0 / COLS) * _cell + _cell / 2;
                var lx2 = _boardX + (w3 % COLS) * _cell + _cell / 2;
                var ly2 = _boardY + (w3 / COLS) * _cell + _cell / 2;
                dc.setColor(0x00FF55, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(lx1 - 2, ly1,     lx2 - 2, ly2);
                dc.drawLine(lx1 - 1, ly1,     lx2 - 1, ly2);
                dc.drawLine(lx1,     ly1,     lx2,     ly2);
                dc.drawLine(lx1 + 1, ly1,     lx2 + 1, ly2);
                dc.drawLine(lx1,     ly1 - 1, lx2,     ly2 - 1);
                dc.drawLine(lx1,     ly1 + 1, lx2,     ly2 + 1);
            }
        }
    }

    hidden function _inWinLine(idx) {
        var k = 0;
        while (k < WIN_LEN) { if (_winLine[k] == idx) { return true; } k = k + 1; }
        return false;
    }

    // ── Column selector (active column indicator + full-column markers) ────
    hidden function _drawSelector(dc) {
        if (_state == GS_OVER) { return; }
        var ay = _boardY - 11;     // y of the indicator row
        var c = 0;
        while (c < COLS) {
            var px = _boardX + c * _cell + _cell / 2;
            if (c == _curCol && _state == GS_PLAY) {
                // Filled red disc — shows which column will receive the drop
                dc.setColor(0xFF2200, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(px, ay, 5);
                // Short pointer lines down toward the board
                dc.drawLine(px - 4, ay + 6, px, ay + 11);
                dc.drawLine(px + 4, ay + 6, px, ay + 11);
            } else if (_dropRow(c) < 0) {
                // Full column: tiny dim dot
                dc.setColor(0x2A2A3A, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(px, ay, 3);
            }
            c = c + 1;
        }
    }

    // ── HUD ───────────────────────────────────────────────────────────────
    hidden function _drawHUD(dc) {
        var ty = _sh * 4 / 100;      // text baseline near top

        // Session score — player (red) left, AI (yellow) right
        dc.setColor(0xFF2200, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_sw / 2 - _sw * 22 / 100, ty, Graphics.FONT_XTINY,
                    "YOU " + _scoreP.format("%d"), Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(0xFFCC00, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_sw / 2 + _sw * 22 / 100, ty, Graphics.FONT_XTINY,
                    _scoreAI.format("%d") + " AI", Graphics.TEXT_JUSTIFY_RIGHT);

        // Turn indicator — centre
        if (_state == GS_PLAY) {
            dc.setColor(0x44FF44, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_sw / 2, ty, Graphics.FONT_XTINY,
                        "YOUR TURN", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (_state == GS_AI) {
            dc.setColor(0x555566, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_sw / 2, ty, Graphics.FONT_XTINY,
                        "AI...", Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Hint below board (only when enough space)
        var hintY = _boardY + ROWS * _cell + 8;
        if (hintY < _sh - 12) {
            dc.setColor(0x1A1A2A, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_sw / 2, hintY, Graphics.FONT_XTINY,
                        "BACK = exit", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── Game-over overlay ─────────────────────────────────────────────────
    hidden function _drawGameOver(dc) {
        var bw = _sw * 54 / 100; var bh = _sh * 29 / 100;
        if (bw < 145) { bw = 145; } if (bh < 88) { bh = 88; }
        var bx = _sw / 2 - bw / 2; var by = _sh / 2 - bh / 2;

        dc.setColor(0x040408, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bx, by, bw, bh, 8);
        dc.setColor(0x3A3A5A, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(bx, by, bw, bh, 8);

        var cx = _sw / 2;
        var msg = ""; var msgCol = 0xCCCCCC;
        if      (_overType == OVER_PWIN)  { msg = "YOU WIN!";  msgCol = 0xFF2200; }
        else if (_overType == OVER_AIWIN) { msg = "AI WINS!";  msgCol = 0xFFCC00; }
        else                               { msg = "DRAW!";     msgCol = 0xCCCC00; }

        dc.setColor(msgCol, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + 8, Graphics.FONT_SMALL, msg, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x555566, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + 38, Graphics.FONT_XTINY,
                    "YOU " + _scoreP.format("%d") + " : " + _scoreAI.format("%d") + " AI",
                    Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x2A2A44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + bh - 14, Graphics.FONT_XTINY,
                    "SELECT = new game", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
