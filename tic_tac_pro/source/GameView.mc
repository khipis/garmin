using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.Math;

// ── Module-level constants ─────────────────────────────────────────────────
const MARK_NONE = 0;
const MARK_X    = 1;   // human player
const MARK_O    = 2;   // AI

const GS_PLAY   = 0;   // human's turn
const GS_AI     = 1;   // 300 ms AI thinking pause, then AI moves
const GS_OVER   = 2;

const OVER_NONE  = 0;
const OVER_XWIN  = 1;
const OVER_OWIN  = 2;
const OVER_DRAW  = 3;

// ── Grid size — change GRID_N to 7 for a 7×7 board ────────────────────────
const GRID_N  = 5;   // 5×5 board
const WIN_LEN = 4;   // need 4 in a row to win

// ── GameView ───────────────────────────────────────────────────────────────
class GameView extends WatchUi.View {

    // ── Layout ────────────────────────────────────────────────────────────
    hidden var _sw, _sh;
    hidden var _boardX, _boardY;  // top-left pixel of the grid
    hidden var _cell;             // pixels per cell

    // ── Board state ───────────────────────────────────────────────────────
    hidden var _cells;       // int[GRID_N * GRID_N]
    hidden var _moveCount;   // marks placed so far
    hidden var _winLine;     // int[WIN_LEN] — filled when a win is detected

    // ── Cursor ────────────────────────────────────────────────────────────
    hidden var _curX, _curY;

    // ── Game flow ─────────────────────────────────────────────────────────
    hidden var _state;
    hidden var _overType;    // OVER_* constant

    // ── Session score ─────────────────────────────────────────────────────
    hidden var _scoreX, _scoreO;

    // ── Timer ─────────────────────────────────────────────────────────────
    hidden var _timer;

    function initialize() {
        View.initialize();
        _cells   = new [GRID_N * GRID_N];
        _winLine = new [WIN_LEN];
        _scoreX  = 0; _scoreO = 0;
        _timer   = null;
        _startGame();
    }

    function onLayout(dc) {
        _sw = dc.getWidth(); _sh = dc.getHeight();

        // Board occupies 69% of screen width, centred with slight downward shift for HUD.
        var bsz = _sw * 69 / 100;
        _cell   = bsz / GRID_N;
        _boardX = (_sw - GRID_N * _cell) / 2;
        _boardY = (_sh - GRID_N * _cell) / 2 + _sh * 4 / 100;

        _timer = new Timer.Timer();
        _timer.start(method(:gameTick), 300, true);
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); }
    }

    // ── Public input API ──────────────────────────────────────────────────

    function moveCursor(dx, dy) {
        if (_state != GS_PLAY) { return; }
        _curX = _curX + dx; _curY = _curY + dy;
        if (_curX < 0)      { _curX = 0; }
        if (_curX >= GRID_N){ _curX = GRID_N - 1; }
        if (_curY < 0)      { _curY = 0; }
        if (_curY >= GRID_N){ _curY = GRID_N - 1; }
    }

    function doAction() {
        if (_state == GS_OVER)  { _startGame(); return; }
        if (_state != GS_PLAY)  { return; }
        if (_cells[_curY * GRID_N + _curX] != MARK_NONE) { return; }  // cell occupied

        _place(_curX, _curY, MARK_X);

        if (_checkWin(MARK_X)) {
            _overType = OVER_XWIN; _scoreX = _scoreX + 1; _state = GS_OVER; return;
        }
        if (_moveCount == GRID_N * GRID_N) {
            _overType = OVER_DRAW; _state = GS_OVER; return;
        }
        _state = GS_AI;  // hand off to AI (fires on next timer tick)
    }

    // ── 300 ms timer tick ─────────────────────────────────────────────────
    function gameTick() {
        if (_state == GS_AI) {
            _aiMove();
            if (_checkWin(MARK_O)) {
                _overType = OVER_OWIN; _scoreO = _scoreO + 1; _state = GS_OVER;
            } else if (_moveCount == GRID_N * GRID_N) {
                _overType = OVER_DRAW; _state = GS_OVER;
            } else {
                _state = GS_PLAY;
            }
            WatchUi.requestUpdate();
        }
    }

    // ── Game management ───────────────────────────────────────────────────

    hidden function _startGame() {
        var i = 0;
        while (i < GRID_N * GRID_N) { _cells[i] = MARK_NONE; i = i + 1; }
        i = 0;
        while (i < WIN_LEN) { _winLine[i] = -1; i = i + 1; }
        _moveCount = 0;
        _curX = GRID_N / 2; _curY = GRID_N / 2;  // start cursor at centre
        _state    = GS_PLAY;
        _overType = OVER_NONE;
    }

    hidden function _place(x, y, mark) {
        _cells[y * GRID_N + x] = mark;
        _moveCount = _moveCount + 1;
    }

    // ── Win detection ─────────────────────────────────────────────────────
    // Returns true if 'col' has WIN_LEN in a row; also populates _winLine.
    hidden function _checkWin(col) {
        var N = GRID_N; var W = WIN_LEN;

        // Horizontal
        var r = 0;
        while (r < N) {
            var c = 0;
            while (c <= N - W) {
                if (_testLine(col, c, r, 1, 0)) { return true; }
                c = c + 1;
            }
            r = r + 1;
        }
        // Vertical
        var cc = 0;
        while (cc < N) {
            var rr = 0;
            while (rr <= N - W) {
                if (_testLine(col, cc, rr, 0, 1)) { return true; }
                rr = rr + 1;
            }
            cc = cc + 1;
        }
        // Diagonal ↘
        var rd = 0;
        while (rd <= N - W) {
            var cd = 0;
            while (cd <= N - W) {
                if (_testLine(col, cd, rd, 1, 1)) { return true; }
                cd = cd + 1;
            }
            rd = rd + 1;
        }
        // Diagonal ↙  (x starts at W-1, goes right; direction dx=-1)
        var ra = 0;
        while (ra <= N - W) {
            var ca = W - 1;
            while (ca < N) {
                if (_testLine(col, ca, ra, -1, 1)) { return true; }
                ca = ca + 1;
            }
            ra = ra + 1;
        }
        return false;
    }

    // Check WIN_LEN cells starting at (x,y) going (dx,dy). Store result in _winLine.
    hidden function _testLine(col, x, y, dx, dy) {
        var k = 0;
        while (k < WIN_LEN) {
            if (_cells[(y + k * dy) * GRID_N + (x + k * dx)] != col) { return false; }
            k = k + 1;
        }
        k = 0;
        while (k < WIN_LEN) {
            _winLine[k] = (y + k * dy) * GRID_N + (x + k * dx);
            k = k + 1;
        }
        return true;
    }

    // ── AI ────────────────────────────────────────────────────────────────

    hidden function _aiMove() {
        // 1. Win
        var move = _findThreat(MARK_O);
        if (move >= 0) { _place(move % GRID_N, move / GRID_N, MARK_O); return; }

        // 2. Block player's winning move
        move = _findThreat(MARK_X);
        if (move >= 0) { _place(move % GRID_N, move / GRID_N, MARK_O); return; }

        // 3. Best scored empty cell (positional + line-extension heuristic)
        move = _bestScoredMove();
        if (move >= 0) { _place(move % GRID_N, move / GRID_N, MARK_O); }
    }

    // Find any empty cell where placing 'col' would immediately win.
    hidden function _findThreat(col) {
        var i = 0;
        while (i < GRID_N * GRID_N) {
            if (_cells[i] == MARK_NONE) {
                _cells[i] = col;
                var wins = _checkWin(col);
                _cells[i] = MARK_NONE;
                if (wins) { return i; }
            }
            i = i + 1;
        }
        return -1;
    }

    // Score-based fallback: centre preference + line-extension bonus.
    hidden function _bestScoredMove() {
        var best = -9999; var move = -1;
        var cx = GRID_N / 2; var cy = GRID_N / 2;
        var i = 0;
        while (i < GRID_N * GRID_N) {
            if (_cells[i] != MARK_NONE) { i = i + 1; continue; }
            var score = _scoreCell(i, cx, cy);
            if (score > best) { best = score; move = i; }
            i = i + 1;
        }
        return move;
    }

    hidden function _scoreCell(idx, cx, cy) {
        var x = idx % GRID_N; var y = idx / GRID_N;

        // Distance from centre (lower = better)
        var dx = x - cx; if (dx < 0) { dx = -dx; }
        var dy = y - cy; if (dy < 0) { dy = -dy; }
        var score = (GRID_N - dx - dy) * 2;

        // Extension bonus: count own pieces in each axis through this cell
        score = score + _axisScore(x, y, MARK_O, 1,  0);
        score = score + _axisScore(x, y, MARK_O, 0,  1);
        score = score + _axisScore(x, y, MARK_O, 1,  1);
        score = score + _axisScore(x, y, MARK_O, 1, -1);

        // Small random noise to break exact ties
        score = score + Math.rand() % 3;
        return score;
    }

    // Count consecutive 'col' marks in both directions along (dx,dy) from (x,y).
    // Returns a bonus based on how long the resulting line would be.
    hidden function _axisScore(x, y, col, dx, dy) {
        var cnt = 0;
        // Forward
        var cx2 = x + dx; var cy2 = y + dy;
        while (cx2 >= 0 && cx2 < GRID_N && cy2 >= 0 && cy2 < GRID_N &&
               _cells[cy2 * GRID_N + cx2] == col) {
            cnt = cnt + 1; cx2 = cx2 + dx; cy2 = cy2 + dy;
        }
        // Backward
        cx2 = x - dx; cy2 = y - dy;
        while (cx2 >= 0 && cx2 < GRID_N && cy2 >= 0 && cy2 < GRID_N &&
               _cells[cy2 * GRID_N + cx2] == col) {
            cnt = cnt + 1; cx2 = cx2 - dx; cy2 = cy2 - dy;
        }
        // Bonus: 3-in-a-row ≫ 2-in-a-row ≫ 1-in-a-row
        if (cnt >= 3) { return 18; }
        if (cnt >= 2) { return  8; }
        if (cnt >= 1) { return  3; }
        return 0;
    }

    // ── Rendering ─────────────────────────────────────────────────────────
    function onUpdate(dc) {
        dc.setColor(0x080810, 0x080810);
        dc.clear();

        _drawBoard(dc);
        _drawHUD(dc);

        if (_state == GS_OVER) { _drawGameOver(dc); }
    }

    // ── Board ─────────────────────────────────────────────────────────────
    hidden function _drawBoard(dc) {
        var bsz = GRID_N * _cell;

        // Grid lines (all GRID_N+1 lines each axis → shows outer border)
        dc.setColor(0x3A3A5A, Graphics.COLOR_TRANSPARENT);
        var li = 0;
        while (li <= GRID_N) {
            var lx = _boardX + li * _cell;
            var ly = _boardY + li * _cell;
            dc.drawLine(lx, _boardY,       lx, _boardY + bsz);
            dc.drawLine(_boardX, ly, _boardX + bsz, ly);
            li = li + 1;
        }

        // Marks and cursor
        var i = 0;
        while (i < GRID_N * GRID_N) {
            var gx = i % GRID_N; var gy = i / GRID_N;
            var px = _boardX + gx * _cell + _cell / 2;
            var py = _boardY + gy * _cell + _cell / 2;

            // Win-line highlight (drawn behind the mark)
            if (_overType == OVER_XWIN || _overType == OVER_OWIN) {
                if (_inWinLine(i)) {
                    dc.setColor(0x002200, Graphics.COLOR_TRANSPARENT);
                    dc.fillRectangle(_boardX + gx * _cell + 1, _boardY + gy * _cell + 1,
                                     _cell - 2, _cell - 2);
                }
            }

            if (_cells[i] == MARK_X) { _drawX(dc, px, py); }
            if (_cells[i] == MARK_O) { _drawO(dc, px, py); }
            i = i + 1;
        }

        // Win line stroke (through the four winning cells)
        if (_overType == OVER_XWIN || _overType == OVER_OWIN) {
            var w0 = _winLine[0]; var w3 = _winLine[WIN_LEN - 1];
            if (w0 >= 0 && w3 >= 0) {
                var lx1 = _boardX + (w0 % GRID_N) * _cell + _cell / 2;
                var ly1 = _boardY + (w0 / GRID_N) * _cell + _cell / 2;
                var lx2 = _boardX + (w3 % GRID_N) * _cell + _cell / 2;
                var ly2 = _boardY + (w3 / GRID_N) * _cell + _cell / 2;
                dc.setColor(0x00FF44, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(lx1,     ly1,     lx2,     ly2);
                dc.drawLine(lx1 + 1, ly1,     lx2 + 1, ly2);
                dc.drawLine(lx1,     ly1 + 1, lx2,     ly2 + 1);
                dc.drawLine(lx1 - 1, ly1,     lx2 - 1, ly2);
                dc.drawLine(lx1,     ly1 - 1, lx2,     ly2 - 1);
            }
        }

        // Cursor (player turn only)
        if (_state == GS_PLAY) {
            var cpx = _boardX + _curX * _cell;
            var cpy = _boardY + _curY * _cell;
            var occupied = (_cells[_curY * GRID_N + _curX] != MARK_NONE);
            var cc = occupied ? 0xFF6600 : 0xFFFF00;
            dc.setColor(cc, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(cpx + 2, cpy + 2, _cell - 4, _cell - 4, 4);
            dc.drawRoundedRectangle(cpx + 3, cpy + 3, _cell - 6, _cell - 6, 3);
        }
    }

    hidden function _inWinLine(idx) {
        var k = 0;
        while (k < WIN_LEN) {
            if (_winLine[k] == idx) { return true; }
            k = k + 1;
        }
        return false;
    }

    // Draw X at pixel centre (px, py) in blue.
    hidden function _drawX(dc, px, py) {
        var hc = _cell * 33 / 100;
        dc.setColor(0x00AAFF, Graphics.COLOR_TRANSPARENT);
        // Two diagonals, each drawn twice for 2px thickness
        dc.drawLine(px - hc,     py - hc,     px + hc,     py + hc);
        dc.drawLine(px - hc + 1, py - hc,     px + hc,     py + hc - 1);
        dc.drawLine(px + hc,     py - hc,     px - hc,     py + hc);
        dc.drawLine(px + hc - 1, py - hc,     px - hc,     py + hc - 1);
    }

    // Draw O at pixel centre (px, py) in red-orange.
    hidden function _drawO(dc, px, py) {
        var r = _cell * 33 / 100;
        dc.setColor(0xFF4422, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(px, py, r);
        dc.drawCircle(px, py, r - 1);
        dc.drawCircle(px, py, r - 2);
    }

    // ── HUD ───────────────────────────────────────────────────────────────
    hidden function _drawHUD(dc) {
        var hudCY = _boardY / 2;
        var txtY  = hudCY - 7;

        // Session score — left and right
        dc.setColor(0x00AAFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_sw / 2 - _sw * 22 / 100, txtY, Graphics.FONT_XTINY,
                    "X " + _scoreX.format("%d"), Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(0xFF4422, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_sw / 2 + _sw * 22 / 100, txtY, Graphics.FONT_XTINY,
                    _scoreO.format("%d") + " O", Graphics.TEXT_JUSTIFY_RIGHT);

        // Turn indicator — centre
        if (_state == GS_PLAY) {
            dc.setColor(0x44FF44, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_sw / 2, txtY, Graphics.FONT_XTINY,
                        "YOUR TURN", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (_state == GS_AI) {
            dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_sw / 2, txtY, Graphics.FONT_XTINY,
                        "AI...", Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Hint below board
        var hintY = _boardY + GRID_N * _cell + 8;
        if (hintY < _sh - 14) {
            dc.setColor(0x222233, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_sw / 2, hintY, Graphics.FONT_XTINY,
                        "BACK = exit", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── Game-over overlay ─────────────────────────────────────────────────
    hidden function _drawGameOver(dc) {
        var bw = _sw * 52 / 100; var bh = _sh * 28 / 100;
        if (bw < 130) { bw = 130; } if (bh < 86) { bh = 86; }
        var bx = _sw / 2 - bw / 2; var by = _sh / 2 - bh / 2;

        dc.setColor(0x050508, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bx, by, bw, bh, 8);
        dc.setColor(0x3A3A5A, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(bx, by, bw, bh, 8);

        var cx = _sw / 2;
        var msg = ""; var msgCol = 0xCCCCCC;
        if      (_overType == OVER_XWIN) { msg = "YOU WIN!";  msgCol = 0x00AAFF; }
        else if (_overType == OVER_OWIN) { msg = "AI WINS!";  msgCol = 0xFF4422; }
        else                              { msg = "DRAW!";     msgCol = 0xCCCC00; }

        dc.setColor(msgCol, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + 8, Graphics.FONT_SMALL, msg, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x555566, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + 36, Graphics.FONT_XTINY,
                    "YOU " + _scoreX.format("%d") + " : " + _scoreO.format("%d") + " AI",
                    Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x2A2A44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + bh - 14, Graphics.FONT_XTINY,
                    "SELECT = new game", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
