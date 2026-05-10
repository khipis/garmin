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
const GS_MENU = 10;
const GS_PLAY = 0;
const GS_AI   = 1;   // 350 ms pause, then AI moves
const GS_OVER = 2;

const OVER_NONE  = 0;
const OVER_PWIN  = 1;
const OVER_AIWIN = 2;
const OVER_DRAW  = 3;

// ── Menu options ───────────────────────────────────────────────────────────
const CF_MODE_PVAI = 0;
const CF_MODE_PVP  = 1;
const CF_MODE_AIAI = 2;
const CF_DIFF_EASY = 0;
const CF_DIFF_MED  = 1;
const CF_DIFF_HARD = 2;

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

    // ── Pre-game menu ─────────────────────────────────────────────────────
    hidden var _cfMode, _cfDiff, _menuSel;
    hidden var _playerFirst;

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
        _cfMode  = CF_MODE_PVAI;
        _cfDiff  = CF_DIFF_MED;
        _menuSel = 0;
        _playerFirst = true;
        _startGame();
        _state   = GS_MENU;   // override to show menu first
    }

    function onLayout(dc) {
        _sw = dc.getWidth();
        _sh = dc.getHeight();

        // ~65 % of screen width — fits safely inside round-watch inscribed square.
        _cell = _sw * 58 / 100 / COLS;
        if (_cell < 26) { _cell = 26; }
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

    // dir: -1 = left/up (menu: backward), +1 = right/down (menu: forward).
    // Wraps at board edges.
    function moveColumn(dir) {
        if (_state == GS_MENU) {
            if (dir < 0) { _menuSel = (_menuSel + 3) % 4; }
            else if (dir > 0) { _menuSel = (_menuSel + 1) % 4; }
            return;
        }
        if (_state != GS_PLAY) { return; }
        _curCol = _curCol + dir;
        if (_curCol < 0)     { _curCol = COLS - 1; }   // wrap left → right
        if (_curCol >= COLS) { _curCol = 0; }           // wrap right → left
    }

    // BACK: menu → pop app, in-game → return to menu
    function doBack() {
        if (_state == GS_MENU) { return false; }
        _state = GS_MENU; _menuSel = 0;
        return true;
    }

    function doAction() {
        if (_state == GS_MENU) {
            if (_menuSel == 0) {
                _cfMode = (_cfMode + 1) % 3;
            } else if (_menuSel == 1) {
                if (_cfMode != CF_MODE_PVP) { _cfDiff = (_cfDiff + 1) % 3; }
            } else if (_menuSel == 2) {
                if (_cfMode == CF_MODE_PVAI) { _playerFirst = !_playerFirst; }
            } else {
                _startGame();
            }
            return;
        }
        if (_state == GS_OVER) { _state = GS_MENU; _menuSel = 0; return; }
        if (_state != GS_PLAY) { return; }
        if (_cfMode == CF_MODE_AIAI) { return; }  // AiAI: no human input
        var r = _dropRow(_curCol);
        if (r < 0) { return; }
        _dropDisc(_curCol, r, MARK_P);
        if (_checkWin(MARK_P)) {
            _overType = OVER_PWIN; _scoreP = _scoreP + 1; _state = GS_OVER; return;
        }
        if (_moveCount == COLS * ROWS) { _overType = OVER_DRAW; _state = GS_OVER; return; }
        _state = GS_AI;
    }

    // ── Timer tick ────────────────────────────────────────────────────────
    function gameTick() as Void {
        if (_state != GS_AI && (_state != GS_PLAY || _cfMode != CF_MODE_AIAI)) { return; }
        if (_state == GS_AI) {
            _aiDropFor(MARK_AI, MARK_P);
            if (_checkWin(MARK_AI)) {
                _overType = OVER_AIWIN; _scoreAI = _scoreAI + 1; _state = GS_OVER;
            } else if (_moveCount == COLS * ROWS) {
                _overType = OVER_DRAW; _state = GS_OVER;
            } else {
                _state = GS_PLAY;
            }
        } else {
            _aiDropFor(MARK_P, MARK_AI);
            if (_checkWin(MARK_P)) {
                _overType = OVER_PWIN; _scoreP = _scoreP + 1; _state = GS_OVER;
            } else if (_moveCount == COLS * ROWS) {
                _overType = OVER_DRAW; _state = GS_OVER;
            } else {
                _state = GS_AI;
            }
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
        _overType  = OVER_NONE;
        if (_cfMode == CF_MODE_PVAI && !_playerFirst) {
            _state = GS_AI;
        } else {
            _state = GS_PLAY;
        }
    }

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
    hidden function _checkWin(mark) {
        var r = 0;
        while (r < ROWS) {
            var c = 0;
            while (c <= COLS - WIN_LEN) {
                if (_testLine(mark, c, r, 1, 0)) { return true; }
                c = c + 1;
            }
            r = r + 1;
        }
        var c2 = 0;
        while (c2 < COLS) {
            var r2 = 0;
            while (r2 <= ROWS - WIN_LEN) {
                if (_testLine(mark, c2, r2, 0, 1)) { return true; }
                r2 = r2 + 1;
            }
            c2 = c2 + 1;
        }
        var r3 = 0;
        while (r3 <= ROWS - WIN_LEN) {
            var c3 = 0;
            while (c3 <= COLS - WIN_LEN) {
                if (_testLine(mark, c3, r3, 1, 1)) { return true; }
                c3 = c3 + 1;
            }
            r3 = r3 + 1;
        }
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
    //
    // Watchdog safety: worst-case ops per tick ≈ 1 600.
    //   _findWinningCol × 2: 2 × 7 × _checkWinAt(~16 ops) ≈ 224
    //   _findForkCol × 2:    2 × 7 × _countThreats(7 × 16) ≈ 1 568
    //   _bestScoredColFor:   7 × (_axisLen+_openEndsFor, ≤56 ops) ≈ 392
    // Total ≈ 1 792 ops — safe on all devices.

    // Generic AI drop for given mark (allows AiAI: Red=MARK_P, Yellow=MARK_AI).
    hidden function _aiDropFor(mark, opp) {
        // Step 1: take the win
        var col = _findWinningCol(mark);
        if (col >= 0) { _dropDisc(col, _dropRow(col), mark); return; }

        // Step 2: block opponent win
        col = _findWinningCol(opp);
        if (col >= 0) { _dropDisc(col, _dropRow(col), mark); return; }

        // Steps 2.5 / 3: fork creation and fork blocking (Med / Hard only)
        if (_cfDiff != CF_DIFF_EASY) {
            col = _findForkCol(mark);
            if (col >= 0) { _dropDisc(col, _dropRow(col), mark); return; }
            col = _findForkCol(opp);
            if (col >= 0) { _dropDisc(col, _dropRow(col), mark); return; }
        }

        // Step 4: positional scoring with open-3 awareness
        col = _bestScoredColFor(mark, opp);
        if (col >= 0) { _dropDisc(col, _dropRow(col), mark); return; }

        var c = 0;
        while (c < COLS) {
            if (_dropRow(c) >= 0) { _dropDisc(c, _dropRow(c), mark); return; }
            c = c + 1;
        }
    }

    hidden function _aiDrop() { _aiDropFor(MARK_AI, MARK_P); }

    // Returns a column where 'mark' would create ≥2 simultaneous winning threats (fork).
    hidden function _findForkCol(mark) {
        var c = 0;
        while (c < COLS) {
            var r = _dropRow(c);
            if (r >= 0) {
                _cells[r * COLS + c] = mark;
                var threats = _countThreats(mark);
                _cells[r * COLS + c] = MARK_NONE;
                if (threats >= 2) { return c; }
            }
            c = c + 1;
        }
        return -1;
    }

    // Fast win check: only tests the 4 axes through (c, r).
    // _cells[r*COLS+c] must already be set to 'mark'.
    hidden function _checkWinAt(mark, c, r) {
        if (_axisLen(c, r, mark, 1,  0) + 1 >= WIN_LEN) { return true; }
        if (_axisLen(c, r, mark, 0,  1) + 1 >= WIN_LEN) { return true; }
        if (_axisLen(c, r, mark, 1,  1) + 1 >= WIN_LEN) { return true; }
        if (_axisLen(c, r, mark, 1, -1) + 1 >= WIN_LEN) { return true; }
        return false;
    }

    // Counts the number of columns where 'mark' would win immediately.
    // Uses _checkWinAt (~16 ops) instead of full _checkWin (~276 ops).
    hidden function _countThreats(mark) {
        var cnt = 0;
        var c = 0;
        while (c < COLS) {
            var r = _dropRow(c);
            if (r >= 0) {
                _cells[r * COLS + c] = mark;
                if (_checkWinAt(mark, c, r)) { cnt = cnt + 1; }
                _cells[r * COLS + c] = MARK_NONE;
            }
            c = c + 1;
        }
        return cnt;
    }

    hidden function _findWinningCol(mark) {
        var c = 0;
        while (c < COLS) {
            var r = _dropRow(c);
            if (r >= 0) {
                _cells[r * COLS + c] = mark;
                var wins = _checkWinAt(mark, c, r);
                _cells[r * COLS + c] = MARK_NONE;
                if (wins) { return c; }
            }
            c = c + 1;
        }
        return -1;
    }

    hidden function _bestScoredColFor(mark, opp) {
        var best = -9999; var move = -1;
        var c = 0;
        while (c < COLS) {
            var score = _scoreColFor(c, mark, opp);
            if (score > best) { best = score; move = c; }
            c = c + 1;
        }
        return move;
    }

    hidden function _bestScoredCol() { return _bestScoredColFor(MARK_AI, MARK_P); }

    hidden function _scoreColFor(col, mark, opp) {
        var r = _dropRow(col);
        if (r < 0) { return -9999; }

        var mid = COLS / 2;
        var dd = col - mid; if (dd < 0) { dd = -dd; }
        var score = (mid - dd + 1) * 3;

        _cells[r * COLS + col] = mark;
        var h  = _axisLen(col, r, mark, 1,  0);
        var v  = _axisLen(col, r, mark, 0,  1);
        var d1 = _axisLen(col, r, mark, 1,  1);
        var d2 = _axisLen(col, r, mark, 1, -1);
        var oh  = _openEndsFor(col, r, 1,  0, mark);
        var ov  = _openEndsFor(col, r, 0,  1, mark);
        var od1 = _openEndsFor(col, r, 1,  1, mark);
        var od2 = _openEndsFor(col, r, 1, -1, mark);
        _cells[r * COLS + col] = MARK_NONE;

        var noise = (_cfDiff == CF_DIFF_EASY) ? 18
                    : ((_cfDiff == CF_DIFF_HARD) ? 2 : 5);

        score = score + _axisScore(h,  oh);
        score = score + _axisScore(v,  ov);
        score = score + _axisScore(d1, od1);
        score = score + _axisScore(d2, od2);

        score = score + Math.rand() % noise;
        return score;
    }

    hidden function _scoreCol(col) { return _scoreColFor(col, MARK_AI, MARK_P); }

    // Score for an axis given chain length (excluding placed piece) and open end count.
    hidden function _axisScore(len, open) {
        if (len >= 3)               { return 20; }
        if (len >= 2 && open >= 2)  { return 32; }  // double-open three — near-win
        if (len >= 2 && open >= 1)  { return 16; }  // half-open three
        if (len >= 2)               { return 4;  }  // blocked three — harmless
        if (len >= 1 && open >= 1)  { return 8;  }  // open two
        if (len >= 1)               { return 3;  }  // blocked two
        return 0;
    }

    // Count open (empty) ends of the chain passing through (col, row) in direction (dc, dr).
    // Assumes _cells[row*COLS+col] is already set to 'mark'.
    hidden function _openEndsFor(col, row, dc, dr, mark) {
        var open = 0;
        var cc = col + dc; var rr = row + dr;
        while (cc >= 0 && cc < COLS && rr >= 0 && rr < ROWS &&
               _cells[rr * COLS + cc] == mark) {
            cc = cc + dc; rr = rr + dr;
        }
        if (cc >= 0 && cc < COLS && rr >= 0 && rr < ROWS &&
            _cells[rr * COLS + cc] == MARK_NONE) { open = open + 1; }

        cc = col - dc; rr = row - dr;
        while (cc >= 0 && cc < COLS && rr >= 0 && rr < ROWS &&
               _cells[rr * COLS + cc] == mark) {
            cc = cc - dc; rr = rr - dr;
        }
        if (cc >= 0 && cc < COLS && rr >= 0 && rr < ROWS &&
            _cells[rr * COLS + cc] == MARK_NONE) { open = open + 1; }

        return open;
    }

    hidden function _openEnds(col, row, dc, dr) {
        return _openEndsFor(col, row, dc, dr, MARK_AI);
    }

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
        if (_state == GS_MENU) { _drawMenu(dc); return; }
        dc.setColor(0x060610, 0x060610);
        dc.clear();
        _drawBoard(dc);
        _drawSelector(dc);
        _drawHUD(dc);
        if (_state == GS_OVER) { _drawGameOver(dc); }
    }

    // ── Pre-game menu ─────────────────────────────────────────────────────
    hidden function _drawMenu(dc) {
        dc.setColor(0x060610, 0x060610);
        dc.clear();
        var hw = _sw / 2;
        dc.setColor(0x06060E, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(hw, _sh / 2, _sw / 2 - 1);

        dc.setColor(0xFF2200, Graphics.COLOR_TRANSPARENT);
        dc.drawText(hw, _sh * 11 / 100, Graphics.FONT_SMALL, "CONNECT FOUR", Graphics.TEXT_JUSTIFY_CENTER);

        var modeStr = (_cfMode == CF_MODE_PVAI) ? "P vs AI"
                      : ((_cfMode == CF_MODE_PVP) ? "P vs P" : "AI vs AI");
        var diffStr = (_cfDiff == CF_DIFF_EASY) ? "Easy"
                      : ((_cfDiff == CF_DIFF_MED) ? "Med" : "Hard");
        var sideStr = _playerFirst ? "Side: Red" : "Side: Yel";
        var rows = ["Mode: " + modeStr, "Diff: " + diffStr, sideStr, "START"];
        var nR   = 4;
        var rowH = _sh * 10 / 100;
        if (rowH < 22) { rowH = 22; }
        if (rowH > 30) { rowH = 30; }
        var rowW = _sw * 74 / 100;
        var rowX = (_sw - rowW) / 2;
        var gap  = 6;
        var tot  = nR * rowH + (nR - 1) * gap;
        var rowY0 = (_sh - tot) / 2 + rowH;
        var i = 0;
        while (i < nR) {
            var ry      = rowY0 + i * (rowH + gap);
            var sel     = (i == _menuSel);
            var isStart = (i == nR - 1);
            dc.setColor(sel ? (isStart ? 0x3A0000 : 0x0A2040) : 0x06060E,
                        Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(rowX, ry, rowW, rowH, 5);
            dc.setColor(sel ? (isStart ? 0xFF2200 : 0x4499FF) : 0x1A2A3A,
                        Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(rowX, ry, rowW, rowH, 5);
            if (sel) {
                dc.setColor(isStart ? 0xFF2200 : 0x4499FF, Graphics.COLOR_TRANSPARENT);
                var ay = ry + rowH / 2;
                dc.fillPolygon([[rowX + 5, ay - 4], [rowX + 5, ay + 4], [rowX + 11, ay]]);
            }
            var dimmed = (i == 1 && _cfMode == CF_MODE_PVP)
                         || (i == 2 && _cfMode != CF_MODE_PVAI);
            dc.setColor(dimmed ? 0x445566
                        : (sel ? (isStart ? 0xFF8866 : 0xAADDFF) : 0x556677),
                        Graphics.COLOR_TRANSPARENT);
            dc.drawText(hw, ry + (rowH - 14) / 2,
                        Graphics.FONT_XTINY, rows[i], Graphics.TEXT_JUSTIFY_CENTER);
            i = i + 1;
        }
        dc.setColor(0x334455, Graphics.COLOR_TRANSPARENT);
        dc.drawText(hw, _sh - 14, Graphics.FONT_XTINY,
                    "UP/DN sel  SELECT set/start", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Board ─────────────────────────────────────────────────────────────
    hidden function _drawBoard(dc) {
        var bw = COLS * _cell;
        var bh = ROWS * _cell;

        dc.setColor(0x0A1850, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(_boardX - 3, _boardY - 3, bw + 6, bh + 6, 6);

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
                    dc.setColor(0xFF2200, Graphics.COLOR_TRANSPARENT);
                    dc.fillCircle(px, py, _rad);
                } else if (mark == MARK_AI) {
                    dc.setColor(0xFFCC00, Graphics.COLOR_TRANSPARENT);
                    dc.fillCircle(px, py, _rad);
                } else if (c == _curCol && r == ghostR) {
                    dc.setColor(0x3A0808, Graphics.COLOR_TRANSPARENT);
                    dc.fillCircle(px, py, _rad);
                    dc.setColor(0xFF3311, Graphics.COLOR_TRANSPARENT);
                    dc.drawCircle(px, py, _rad);
                } else {
                    dc.setColor(0x101028, Graphics.COLOR_TRANSPARENT);
                    dc.fillCircle(px, py, _rad);
                }

                if (inWin) {
                    dc.setColor(0x00FF55, Graphics.COLOR_TRANSPARENT);
                    dc.drawCircle(px, py, _rad + 2);
                    dc.drawCircle(px, py, _rad + 3);
                }

                c = c + 1;
            }
            r = r + 1;
        }

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

    // ── Column selector ───────────────────────────────────────────────────
    hidden function _drawSelector(dc) {
        if (_state == GS_OVER) { return; }
        var ay = _boardY - 11;
        var c = 0;
        while (c < COLS) {
            var px = _boardX + c * _cell + _cell / 2;
            if (c == _curCol && _state == GS_PLAY) {
                dc.setColor(0xFF2200, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(px, ay, 5);
                dc.drawLine(px - 4, ay + 6, px, ay + 11);
                dc.drawLine(px + 4, ay + 6, px, ay + 11);
            } else if (_dropRow(c) < 0) {
                dc.setColor(0x2A2A3A, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(px, ay, 3);
            }
            c = c + 1;
        }
    }

    // ── HUD ───────────────────────────────────────────────────────────────
    hidden function _drawHUD(dc) {
        var ty = _sh * 4 / 100;
        var isAiAi = (_cfMode == CF_MODE_AIAI);

        dc.setColor(0xFF2200, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_sw / 2 - _sw * 22 / 100, ty, Graphics.FONT_XTINY,
                    (isAiAi ? "RED " : "YOU ") + _scoreP.format("%d"),
                    Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(0xFFCC00, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_sw / 2 + _sw * 22 / 100, ty, Graphics.FONT_XTINY,
                    _scoreAI.format("%d") + (isAiAi ? " YEL" : " AI"),
                    Graphics.TEXT_JUSTIFY_RIGHT);

        if (_state == GS_PLAY) {
            dc.setColor(isAiAi ? 0xFF6644 : 0x44FF44, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_sw / 2, ty, Graphics.FONT_XTINY,
                        isAiAi ? "RED..." : "YOUR TURN", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (_state == GS_AI) {
            dc.setColor(0x555566, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_sw / 2, ty, Graphics.FONT_XTINY,
                        isAiAi ? "YEL..." : "AI...", Graphics.TEXT_JUSTIFY_CENTER);
        }

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
        var isAiAi = (_cfMode == CF_MODE_AIAI);
        var msg = ""; var msgCol = 0xCCCCCC;
        if      (_overType == OVER_PWIN)  { msg = isAiAi ? "RED WINS!" : "YOU WIN!";  msgCol = 0xFF2200; }
        else if (_overType == OVER_AIWIN) { msg = isAiAi ? "YEL WINS!" : "AI WINS!";  msgCol = 0xFFCC00; }
        else                               { msg = "DRAW!";                             msgCol = 0xCCCC00; }

        dc.setColor(msgCol, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + 8, Graphics.FONT_SMALL, msg, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x555566, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + 38, Graphics.FONT_XTINY,
                    "YOU " + _scoreP.format("%d") + " : " + _scoreAI.format("%d") + " AI",
                    Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x2A2A44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + bh - 14, Graphics.FONT_XTINY,
                    "SELECT = menu", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
