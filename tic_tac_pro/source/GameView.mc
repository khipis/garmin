using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.Math;

// ── Constants ─────────────────────────────────────────────────────────────────
const MARK_NONE = 0;
const MARK_X    = 1;
const MARK_O    = 2;

const GS_PLAY    = 0;
const GS_AI      = 1;
const GS_OVER    = 2;
const GS_AI_FORK  = 5;   // fork search spread across multiple timer ticks
const GS_AI_SCORE = 6;   // heuristic scored move (separate tick after fork)
const GS_MENU     = 10;

const FORK_BATCH  = 16;  // outer iterations per tick — fast enough for grids ≤5x5

const OVER_NONE = 0;
const OVER_XWIN = 1;
const OVER_OWIN = 2;
const OVER_DRAW = 3;

const MODE_PVAI = 0;
const MODE_PVP  = 1;
const MODE_AIAI = 2;

const DIFF_EASY = 0;
const DIFF_MED  = 1;
const DIFF_HARD = 2;

// ── GameView ───────────────────────────────────────────────────────────────────
class GameView extends WatchUi.View {

    // ── Layout ────────────────────────────────────────────────────────────
    hidden var _sw, _sh;
    hidden var _boardX, _boardY;
    hidden var _cell;

    // ── Board state ───────────────────────────────────────────────────────
    hidden var _cells;       // new [7*7] = 49 max
    hidden var _moveCount;
    hidden var _winLine;     // new [4]
    hidden var _gridN;       // 3..7
    hidden var _winLen;      // 3 or 4

    // ── Cursor ────────────────────────────────────────────────────────────
    hidden var _curX, _curY;

    // ── Game flow ─────────────────────────────────────────────────────────
    hidden var _state;
    hidden var _overType;

    // ── Session score ─────────────────────────────────────────────────────
    hidden var _scoreX, _scoreO;

    // ── Mode / difficulty / menu ──────────────────────────────────────────
    hidden var _mode;
    hidden var _diff;
    hidden var _menuSel;
    hidden var _playerFirst;

    // ── Timer ─────────────────────────────────────────────────────────────
    hidden var _timer;

    // ── Multi-tick 2-ply search state ────────────────────────────────────
    hidden var _aiForkMark;    // mark being checked this phase
    hidden var _aiForkAiMk;    // mark the AI is actually playing
    hidden var _aiForkPhase;   // 0 = 2-ply search, 1 = unused (legacy)
    hidden var _aiForkI;       // outer-loop cursor
    hidden var _aiForkResult;  // best move index found (-1 = none yet)
    hidden var _aiForkBest;    // best score found so far

    // ─────────────────────────────────────────────────────────────────────
    function initialize() {
        View.initialize();
        _cells   = new [7 * 7];
        _winLine = new [4];
        _scoreX  = 0;
        _scoreO  = 0;
        _gridN   = 5;
        _winLen  = 4;
        _mode        = MODE_PVAI;
        _diff        = DIFF_MED;
        _menuSel     = 0;
        _playerFirst = true;
        _sw          = 0;
        _sh      = 0;
        _timer   = null;
        _startGame();
        _state   = GS_MENU;
    }

    function onLayout(dc) {
        _sw = dc.getWidth();
        _sh = dc.getHeight();
        _calcLayout();
        _timer = new Timer.Timer();
        _timer.start(method(:gameTick), 300, true);
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); }
    }

    // ── Layout helper ─────────────────────────────────────────────────────
    hidden function _calcLayout() {
        if (_sw == 0) { return; }
        var minDim = (_sw < _sh) ? _sw : _sh;
        _cell   = minDim * 68 / (100 * _gridN);
        _boardX = (_sw - _gridN * _cell) / 2;
        _boardY = (_sh - _gridN * _cell) / 2 - _sh * 3 / 100;
        if (_boardY < 18) { _boardY = 18; }
    }

    // ── Public input API ──────────────────────────────────────────────────

    // advance cursor in reading order: right → next row → wrap
    // onNextPage (DOWN button): move RIGHT in current row, wrap to col=0
    function advanceCursor() {
        if (_state == GS_MENU) {
            _menuSel = (_menuSel + 1) % 5;
            WatchUi.requestUpdate();
            return;
        }
        if (_mode == MODE_AIAI) { return; }
        if (_state != GS_PLAY && !(_state == GS_AI && _mode == MODE_PVP)) { return; }
        _curX = (_curX + 1) % _gridN;
        WatchUi.requestUpdate();
    }

    // onPreviousPage (UP button): move DOWN in current column, wrap to row=0
    function retreatCursor() {
        if (_state == GS_MENU) {
            _menuSel = (_menuSel + 4) % 5;
            WatchUi.requestUpdate();
            return;
        }
        if (_mode == MODE_AIAI) { return; }
        if (_state != GS_PLAY && !(_state == GS_AI && _mode == MODE_PVP)) { return; }
        _curY = (_curY + 1) % _gridN;
        WatchUi.requestUpdate();
    }

    // move cursor up/down one row, same column, wrapping
    function moveCursorRow(delta) {
        if (_state == GS_MENU) {
            _menuSel = (_menuSel + 5 + delta) % 5;
            WatchUi.requestUpdate();
            return;
        }
        if (_mode == MODE_AIAI) { return; }
        if (_state != GS_PLAY && !(_state == GS_AI && _mode == MODE_PVP)) { return; }
        _curY = _curY + delta;
        if (_curY < 0)        { _curY = _gridN - 1; }
        if (_curY >= _gridN)  { _curY = 0; }
        WatchUi.requestUpdate();
    }

    // BACK: menu → pop app, in-game → return to menu
    function doBack() {
        if (_state == GS_MENU) { return false; }
        _state = GS_MENU; _menuSel = 0;
        return true;
    }

    function doAction() {
        if (_state == GS_MENU)  { _menuAction(); WatchUi.requestUpdate(); return; }
        if (_state == GS_OVER)  { _state = GS_MENU; _menuSel = 0; WatchUi.requestUpdate(); return; }
        if (_mode == MODE_AIAI) { return; }

        // PvP: GS_AI = O's turn (P2 places O)
        if (_state == GS_AI && _mode == MODE_PVP) {
            if (_cells[_curY * _gridN + _curX] != MARK_NONE) { return; }
            _place(_curX, _curY, MARK_O);
            if (_checkWin(MARK_O)) {
                _overType = OVER_OWIN; _scoreO = _scoreO + 1; _state = GS_OVER;
                WatchUi.requestUpdate(); return;
            }
            if (_moveCount == _gridN * _gridN) {
                _overType = OVER_DRAW; _state = GS_OVER;
                WatchUi.requestUpdate(); return;
            }
            _state = GS_PLAY;
            WatchUi.requestUpdate();
            return;
        }

        // PvAI player goes second: GS_AI = player's turn (player places O)
        if (_state == GS_AI && _mode == MODE_PVAI && !_playerFirst) {
            if (_cells[_curY * _gridN + _curX] != MARK_NONE) { return; }
            _place(_curX, _curY, MARK_O);
            if (_checkWin(MARK_O)) {
                _overType = OVER_OWIN; _scoreO = _scoreO + 1; _state = GS_OVER;
                WatchUi.requestUpdate(); return;
            }
            if (_moveCount == _gridN * _gridN) {
                _overType = OVER_DRAW; _state = GS_OVER;
                WatchUi.requestUpdate(); return;
            }
            _state = GS_PLAY;
            WatchUi.requestUpdate();
            return;
        }

        if (_state != GS_PLAY) { return; }
        if (_cells[_curY * _gridN + _curX] != MARK_NONE) { return; }

        _place(_curX, _curY, MARK_X);
        if (_checkWin(MARK_X)) {
            _overType = OVER_XWIN; _scoreX = _scoreX + 1; _state = GS_OVER;
            WatchUi.requestUpdate(); return;
        }
        if (_moveCount == _gridN * _gridN) {
            _overType = OVER_DRAW; _state = GS_OVER;
            WatchUi.requestUpdate(); return;
        }
        _state = GS_AI;
        WatchUi.requestUpdate();
    }

    // ── Menu action ───────────────────────────────────────────────────────
    hidden function _menuAction() {
        if (_menuSel == 0) {
            _mode = (_mode + 1) % 3;
        } else if (_menuSel == 1) {
            if (_mode != MODE_PVP) { _diff = (_diff + 1) % 3; }
        } else if (_menuSel == 2) {
            _gridN = _gridN + 1;
            if (_gridN > 7) { _gridN = 3; }
            _winLen = (_gridN == 3) ? 3 : 4;
        } else if (_menuSel == 3) {
            if (_mode == MODE_PVAI) { _playerFirst = !_playerFirst; }
        } else {
            _startGame();
        }
    }

    // ── 300 ms timer tick ─────────────────────────────────────────────────
    function gameTick() as Void {
        if (_state == GS_AI && (_mode == MODE_PVAI || _mode == MODE_AIAI)) {
            if (!(_mode == MODE_PVAI && !_playerFirst)) {
                _aiStart(MARK_O);
            }
        } else if (_state == GS_AI_FORK) {
            _aiForkStep();
        } else if (_state == GS_AI_SCORE) {
            _aiScoreTick();
        } else if (_state == GS_PLAY && _mode == MODE_AIAI) {
            _aiStart(MARK_X);
        } else if (_state == GS_PLAY && _mode == MODE_PVAI && !_playerFirst) {
            _aiStart(MARK_X);
        }
        WatchUi.requestUpdate();
    }

    // Fast path: immediate win/block + Easy move. Med/Hard → 2-ply GS_AI_FORK.
    hidden function _aiStart(mark) {
        var opp = (mark == MARK_X) ? MARK_O : MARK_X;
        var move = _findThreat(mark);
        if (move >= 0) { _aiFinish(move, mark); return; }
        move = _findThreat(opp);
        if (move >= 0) { _aiFinish(move, mark); return; }
        if (_diff == DIFF_EASY) {
            if (Math.rand() % 10 < 4) { move = _randomMove(); }
            else { move = _bestScoredMove(mark); }
            if (move >= 0) { _aiFinish(move, mark); }
            return;
        }
        // Med/Hard: for 3×3 perfect minimax runs in one tick (at most 60 leaf nodes).
        // For larger grids: 2-ply threat-aware search spread across ticks.
        _aiForkAiMk  = mark;
        _aiForkI     = 0;
        _aiForkResult = -1;
        _aiForkBest  = -999999;
        _state = GS_AI_FORK;
    }

    // Processes FORK_BATCH outer iterations per tick.
    // For 3×3: runs full negamax per candidate (fast, terminates in 1-2 ticks).
    // For 4×7: 2-ply — simulate my move, count opp winning replies + opp best score.
    // Batch size adapts: 3×3=9 in one go; larger grids batched at FORK_BATCH/2.
    hidden function _aiForkStep() {
        var mark  = _aiForkAiMk;
        var opp   = (mark == MARK_X) ? MARK_O : MARK_X;
        var total = _gridN * _gridN;
        var is3   = (_gridN == 3);
        var batch = is3 ? total : (FORK_BATCH / 2 + 1);
        var done  = 0;
        while (_aiForkI < total && done < batch) {
            if (_cells[_aiForkI] == MARK_NONE) {
                var ix = _aiForkI % _gridN; var iy = _aiForkI / _gridN;
                _cells[_aiForkI] = mark;
                _moveCount = _moveCount + 1;
                var sc;
                if (_checkWinAt(mark, ix, iy)) {
                    // Immediate win — take it right now
                    _cells[_aiForkI] = MARK_NONE;
                    _moveCount = _moveCount - 1;
                    _aiFinish(_aiForkI, mark);
                    return;
                } else if (_moveCount == total) {
                    sc = 0;  // draw
                } else if (is3) {
                    // Full minimax for 3×3 — never watchdogs (≤60 leaf nodes from here)
                    sc = -_negamax3(opp, mark, -1000, 1000);
                } else {
                    // 2-ply: penalise moves that leave opp with winning replies
                    var myHeur = _scoreCell(_aiForkI, mark);
                    var oppWins = 0; var oppBest = -99999; var j = 0;
                    while (j < total) {
                        if (_cells[j] == MARK_NONE) {
                            // Fast: check opp winning
                            _cells[j] = opp;
                            var oppWin = _checkWinAt(opp, j % _gridN, j / _gridN);
                            if (oppWin) {
                                oppWins = oppWins + 1;
                            } else {
                                var os = _scoreCell(j, opp);
                                if (os > oppBest) { oppBest = os; }
                            }
                            _cells[j] = MARK_NONE;
                        }
                        j = j + 1;
                    }
                    // Heavy penalty if opp can win, otherwise use 2-ply difference
                    if (oppWins >= 2) {
                        sc = myHeur - 5000;         // creates fork for opp — very bad
                    } else if (oppWins == 1) {
                        sc = myHeur - 2000;         // leaves forced loss
                    } else {
                        var oppPenalty = (oppBest == -99999) ? 0 : oppBest;
                        sc = myHeur * 4 - oppPenalty * 3;
                    }
                }
                _cells[_aiForkI] = MARK_NONE;
                _moveCount = _moveCount - 1;
                if (sc > _aiForkBest) { _aiForkBest = sc; _aiForkResult = _aiForkI; }
            }
            _aiForkI = _aiForkI + 1;
            done = done + 1;
        }
        if (_aiForkI >= total) {
            if (_aiForkResult >= 0) { _aiFinish(_aiForkResult, mark); }
            else { _state = GS_AI_SCORE; }
        }
    }

    // Full negamax with alpha-beta for 3×3 boards only.
    // Positive score = good for 'mark'. Called after placing mark on board.
    // Safe: max tree depth 7 (8 cells remain), alpha-beta prunes heavily.
    hidden function _negamax3(mark, opp, alpha, beta) {
        var move = _findThreat(mark);
        if (move >= 0) {
            _cells[move] = mark; _moveCount = _moveCount + 1;
            _cells[move] = MARK_NONE; _moveCount = _moveCount - 1;
            return 900;  // opponent already won last move? shouldn't reach here
        }
        if (_moveCount == _gridN * _gridN) { return 0; }
        var best = -9999; var i = 0;
        while (i < 9) {
            if (_cells[i] == MARK_NONE) {
                var ix = i % _gridN; var iy = i / _gridN;
                _cells[i] = mark; _moveCount = _moveCount + 1;
                var sc;
                if (_checkWinAt(mark, ix, iy)) {
                    sc = 900 - _moveCount;
                } else if (_moveCount == 9) {
                    sc = 0;
                } else {
                    sc = -_negamax3(opp, mark, -beta, -alpha);
                }
                _cells[i] = MARK_NONE; _moveCount = _moveCount - 1;
                if (sc > best)  { best  = sc; }
                if (sc > alpha) { alpha = sc; }
                if (alpha >= beta) { break; }
            }
            i = i + 1;
        }
        return best;
    }

    // Separate tick: heuristic scored move after fork phases complete.
    hidden function _aiScoreTick() {
        var move = _bestScoredMove(_aiForkAiMk);
        if (move < 0) { move = _randomMove(); }
        if (move >= 0) { _aiFinish(move, _aiForkAiMk); }
        else { _state = (_aiForkAiMk == MARK_O) ? GS_PLAY : GS_AI; }
    }

    // Apply a move and update game state.
    // Uses fast _checkWinAt first (O(W*4)) to detect win, then full _checkWin
    // only when confirmed — to populate _winLine for display.
    hidden function _aiFinish(move, mark) {
        var mx = move % _gridN;
        var my = move / _gridN;
        _place(mx, my, mark);
        if (_checkWinAt(mark, mx, my)) {
            _checkWin(mark);  // populate _winLine for highlighting
            if (mark == MARK_X) { _overType = OVER_XWIN; _scoreX = _scoreX + 1; }
            else                { _overType = OVER_OWIN; _scoreO = _scoreO + 1; }
            _state = GS_OVER;
        } else if (_moveCount == _gridN * _gridN) {
            _overType = OVER_DRAW; _state = GS_OVER;
        } else {
            _state = (mark == MARK_O) ? GS_PLAY : GS_AI;
        }
    }

    // ── Game management ───────────────────────────────────────────────────
    hidden function _startGame() {
        _calcLayout();
        var total = _gridN * _gridN;
        var i = 0;
        while (i < total) { _cells[i] = MARK_NONE; i = i + 1; }
        i = 0;
        while (i < 4) { _winLine[i] = -1; i = i + 1; }
        _moveCount = 0;
        _curX      = _gridN / 2;
        _curY      = _gridN / 2;
        _overType  = OVER_NONE;
        if (_mode == MODE_PVAI && !_playerFirst) {
            _state = GS_AI;
        } else {
            _state = GS_PLAY;
        }
    }

    hidden function _place(x, y, mark) {
        _cells[y * _gridN + x] = mark;
        _moveCount = _moveCount + 1;
    }

    // ── Win detection ─────────────────────────────────────────────────────
    hidden function _checkWin(col) {
        var N = _gridN; var W = _winLen;
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
        // Diagonal ↙
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

    hidden function _testLine(col, x, y, dx, dy) {
        var k = 0;
        while (k < _winLen) {
            if (_cells[(y + k * dy) * _gridN + (x + k * dx)] != col) { return false; }
            k = k + 1;
        }
        k = 0;
        while (k < _winLen) {
            _winLine[k] = (y + k * dy) * _gridN + (x + k * dx);
            k = k + 1;
        }
        return true;
    }

    // ── AI ────────────────────────────────────────────────────────────────
    // O(N²·W): try each empty cell; fast-check axes through that cell only.
    hidden function _findThreat(col) {
        var total = _gridN * _gridN;
        var i = 0;
        while (i < total) {
            if (_cells[i] == MARK_NONE) {
                _cells[i] = col;
                var wins = _checkWinAt(col, i % _gridN, i / _gridN);
                _cells[i] = MARK_NONE;
                if (wins) { return i; }
            }
            i = i + 1;
        }
        return -1;
    }

    // Fast win check — only 4 axes through (lx, ly). Does NOT set _winLine.
    hidden function _checkWinAt(col, lx, ly) {
        if (_fastAxis(col, lx, ly,  1,  0)) { return true; }
        if (_fastAxis(col, lx, ly,  0,  1)) { return true; }
        if (_fastAxis(col, lx, ly,  1,  1)) { return true; }
        if (_fastAxis(col, lx, ly,  1, -1)) { return true; }
        return false;
    }

    hidden function _fastAxis(col, x, y, dx, dy) {
        var cnt = 1; var k = 1;
        while (k < _winLen) {
            var nx = x + k * dx; var ny = y + k * dy;
            if (nx < 0 || nx >= _gridN || ny < 0 || ny >= _gridN) { break; }
            if (_cells[ny * _gridN + nx] != col) { break; }
            cnt = cnt + 1; k = k + 1;
        }
        k = 1;
        while (k < _winLen) {
            var nx = x - k * dx; var ny = y - k * dy;
            if (nx < 0 || nx >= _gridN || ny < 0 || ny >= _gridN) { break; }
            if (_cells[ny * _gridN + nx] != col) { break; }
            cnt = cnt + 1; k = k + 1;
        }
        return cnt >= _winLen;
    }

    hidden function _randomMove() {
        var total = _gridN * _gridN;
        var count = 0; var i = 0;
        while (i < total) { if (_cells[i] == MARK_NONE) { count = count + 1; } i = i + 1; }
        if (count == 0) { return -1; }
        var pick = Math.rand() % count;
        i = 0; var found = 0;
        while (i < total) {
            if (_cells[i] == MARK_NONE) {
                if (found == pick) { return i; }
                found = found + 1;
            }
            i = i + 1;
        }
        return -1;
    }

    hidden function _bestScoredMove(mark) {
        var best = -99999; var move = -1;
        var total = _gridN * _gridN; var i = 0;
        while (i < total) {
            if (_cells[i] != MARK_NONE) { i = i + 1; continue; }
            var s = _scoreCell(i, mark);
            if (s > best) { best = s; move = i; }
            i = i + 1;
        }
        return move;
    }

    // Score a candidate cell for 'mark'.
    // Combines own potential, opponent threat (defensive), and centre bias.
    hidden function _scoreCell(idx, mark) {
        var x = idx % _gridN; var y = idx / _gridN;
        var opp = (mark == MARK_X) ? MARK_O : MARK_X;
        var mid = _gridN / 2;
        var ddx = x - mid; if (ddx < 0) { ddx = -ddx; }
        var ddy = y - mid; if (ddy < 0) { ddy = -ddy; }
        var score = (_gridN - ddx - ddy) * 4;

        // Offensive potential (cubic: 1, 8, 27 for 1, 2, 3-in-window)
        score = score + _axisPotential(x, y, mark, opp,  1,  0);
        score = score + _axisPotential(x, y, mark, opp,  0,  1);
        score = score + _axisPotential(x, y, mark, opp,  1,  1);
        score = score + _axisPotential(x, y, mark, opp,  1, -1);

        // Defensive: how dangerous is this cell for the opponent?
        var defW = (_diff == DIFF_HARD) ? 6 : 4;
        score = score + _axisPotential(x, y, opp, mark,  1,  0) * defW / 4;
        score = score + _axisPotential(x, y, opp, mark,  0,  1) * defW / 4;
        score = score + _axisPotential(x, y, opp, mark,  1,  1) * defW / 4;
        score = score + _axisPotential(x, y, opp, mark,  1, -1) * defW / 4;

        if (_diff == DIFF_EASY) { score = score + Math.rand() % 20 - 10; }
        else if (_diff == DIFF_MED)  { score = score + Math.rand() % 5; }
        else                          { score = score + Math.rand() % 3; }
        return score;
    }

    // Scan all windows of size _winLen on axis (dx,dy) that contain (x,y).
    // For each window with no 'opp' mark, add cnt³ where cnt = own marks in window.
    // O(_winLen²) per call — extremely fast.
    hidden function _axisPotential(x, y, col, opp, dx, dy) {
        var W = _winLen; var N = _gridN; var score = 0;
        // Window offsets: the cell (x,y) is at position k within the window,
        // so window starts at (x - k*dx, y - k*dy) for k = 0..W-1.
        var k = 0;
        while (k < W) {
            var sx = x - k * dx; var sy = y - k * dy;
            // Verify window fits on board
            var ex = sx + (W - 1) * dx; var ey = sy + (W - 1) * dy;
            if (sx < 0 || sx >= N || sy < 0 || sy >= N) { k = k + 1; continue; }
            if (ex < 0 || ex >= N || ey < 0 || ey >= N) { k = k + 1; continue; }
            // Count col marks; abort if opp present
            var cnt = 0; var blocked = false; var j = 0;
            while (j < W) {
                var v = _cells[(sy + j * dy) * N + (sx + j * dx)];
                if (v == opp) { blocked = true; break; }
                if (v == col) { cnt = cnt + 1; }
                j = j + 1;
            }
            if (!blocked && cnt > 0) {
                score = score + cnt * cnt * cnt;  // 1, 8, 27 for 1, 2, 3 marks
            }
            k = k + 1;
        }
        return score;
    }

    // ── Rendering ─────────────────────────────────────────────────────────
    function onUpdate(dc) {
        if (_state == GS_MENU) { _drawMenu(dc); return; }
        dc.setColor(0x080810, 0x080810);
        dc.clear();
        _drawBoard(dc);
        _drawHUD(dc);
        if (_state == GS_OVER) { _drawGameOver(dc); }
    }

    // ── Board ─────────────────────────────────────────────────────────────
    hidden function _drawBoard(dc) {
        var bsz = _gridN * _cell;

        // Grid lines
        dc.setColor(0x3A3A5A, Graphics.COLOR_TRANSPARENT);
        var li = 0;
        while (li <= _gridN) {
            var lx = _boardX + li * _cell;
            var ly = _boardY + li * _cell;
            dc.drawLine(lx, _boardY,       lx, _boardY + bsz);
            dc.drawLine(_boardX, ly, _boardX + bsz, ly);
            li = li + 1;
        }

        // Marks and win-line highlight
        var total = _gridN * _gridN;
        var i = 0;
        while (i < total) {
            var gx = i % _gridN; var gy = i / _gridN;
            var px = _boardX + gx * _cell + _cell / 2;
            var py = _boardY + gy * _cell + _cell / 2;
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

        // Win line stroke
        if (_overType == OVER_XWIN || _overType == OVER_OWIN) {
            var w0 = _winLine[0]; var w3 = _winLine[_winLen - 1];
            if (w0 >= 0 && w3 >= 0) {
                var lx1 = _boardX + (w0 % _gridN) * _cell + _cell / 2;
                var ly1 = _boardY + (w0 / _gridN) * _cell + _cell / 2;
                var lx2 = _boardX + (w3 % _gridN) * _cell + _cell / 2;
                var ly2 = _boardY + (w3 / _gridN) * _cell + _cell / 2;
                dc.setColor(0x00FF44, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(lx1,     ly1,     lx2,     ly2);
                dc.drawLine(lx1 + 1, ly1,     lx2 + 1, ly2);
                dc.drawLine(lx1,     ly1 + 1, lx2,     ly2 + 1);
                dc.drawLine(lx1 - 1, ly1,     lx2 - 1, ly2);
                dc.drawLine(lx1,     ly1 - 1, lx2,     ly2 - 1);
            }
        }

        // Cursor — show for human turns
        var showCursor = (_state == GS_PLAY && _mode != MODE_AIAI) ||
                         (_state == GS_AI   && _mode == MODE_PVP);
        if (showCursor) {
            var cpx = _boardX + _curX * _cell;
            var cpy = _boardY + _curY * _cell;
            var occupied = (_cells[_curY * _gridN + _curX] != MARK_NONE);
            dc.setColor(occupied ? 0xFF6600 : 0xFFFF00, Graphics.COLOR_TRANSPARENT);
            var inset1 = (_cell > 8) ? 2 : 1;
            var inset2 = (_cell > 8) ? 3 : 1;
            dc.drawRoundedRectangle(cpx + inset1, cpy + inset1, _cell - inset1 * 2, _cell - inset1 * 2, 4);
            dc.drawRoundedRectangle(cpx + inset2, cpy + inset2, _cell - inset2 * 2, _cell - inset2 * 2, 3);
        }
    }

    hidden function _inWinLine(idx) {
        var k = 0;
        while (k < _winLen) {
            if (_winLine[k] == idx) { return true; }
            k = k + 1;
        }
        return false;
    }

    hidden function _drawX(dc, px, py) {
        var hc = _cell * 33 / 100;
        if (hc < 3) { hc = 3; }
        dc.setColor(0x00AAFF, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(px - hc,     py - hc,     px + hc,     py + hc);
        dc.drawLine(px - hc + 1, py - hc,     px + hc,     py + hc - 1);
        dc.drawLine(px + hc,     py - hc,     px - hc,     py + hc);
        dc.drawLine(px + hc - 1, py - hc,     px - hc,     py + hc - 1);
    }

    hidden function _drawO(dc, px, py) {
        var r = _cell * 33 / 100;
        if (r < 3) { r = 3; }
        dc.setColor(0xFF4422, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(px, py, r);
        dc.drawCircle(px, py, r - 1);
        if (r >= 3) { dc.drawCircle(px, py, r - 2); }
    }

    // ── HUD ───────────────────────────────────────────────────────────────
    hidden function _drawHUD(dc) {
        var ty = _sh * 3 / 100;
        if (ty < 4) { ty = 4; }

        // Score — left (X) and right (O)
        dc.setColor(0x00AAFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(10, ty, Graphics.FONT_XTINY,
                    "X " + _scoreX.format("%d"), Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(0xFF4422, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_sw - 10, ty, Graphics.FONT_XTINY,
                    _scoreO.format("%d") + " O", Graphics.TEXT_JUSTIFY_RIGHT);

        // Turn indicator — centre
        if (_state == GS_PLAY) {
            var turnTxt = "YOUR TURN";
            if (_mode == MODE_PVP)  { turnTxt = "X TURN"; }
            if (_mode == MODE_AIAI) { turnTxt = "X THINKING"; }
            dc.setColor(0x44FF44, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_sw / 2, ty, Graphics.FONT_XTINY, turnTxt, Graphics.TEXT_JUSTIFY_CENTER);
        } else if (_state == GS_AI || _state == GS_AI_FORK || _state == GS_AI_SCORE) {
            var aiTxt = "AI THINKING";
            if (_mode == MODE_PVP)  { aiTxt = "O TURN"; }
            if (_mode == MODE_AIAI) { aiTxt = "O THINKING"; }
            var aiCol = (_mode == MODE_PVP) ? 0x44FF44 : 0x555566;
            dc.setColor(aiCol, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_sw / 2, ty, Graphics.FONT_XTINY, aiTxt, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Hint below board
        var hintY = _boardY + _gridN * _cell + 8;
        if (hintY < _sh - 14) {
            dc.setColor(0x222233, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_sw / 2, hintY, Graphics.FONT_XTINY,
                        "DN=next  UP=down  SEL=place", Graphics.TEXT_JUSTIFY_CENTER);
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

        var cx  = _sw / 2;
        var msg = ""; var msgCol = 0xCCCCCC;
        if (_overType == OVER_XWIN) {
            msg    = (_mode == MODE_PVAI) ? (_playerFirst ? "YOU WIN!" : "AI WINS!") : "X WINS!";
            msgCol = 0x00AAFF;
        } else if (_overType == OVER_OWIN) {
            msg    = (_mode == MODE_PVAI) ? (_playerFirst ? "AI WINS!" : "YOU WIN!") : "O WINS!";
            msgCol = 0xFF4422;
        } else {
            msg = "DRAW!"; msgCol = 0xCCCC00;
        }

        dc.setColor(msgCol, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + 8, Graphics.FONT_SMALL, msg, Graphics.TEXT_JUSTIFY_CENTER);

        var sc1, sc2;
        if (_mode == MODE_PVAI) {
            if (_playerFirst) { sc1 = "YOU "; sc2 = " AI"; }
            else              { sc1 = "AI ";  sc2 = " YOU"; }
        } else {
            sc1 = "X "; sc2 = " O";
        }
        dc.setColor(0x555566, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + 36, Graphics.FONT_XTINY,
                    sc1 + _scoreX.format("%d") + " : " + _scoreO.format("%d") + sc2,
                    Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x2A2A44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + bh - 14, Graphics.FONT_XTINY,
                    "SELECT = new game", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Pre-game menu ─────────────────────────────────────────────────────
    hidden function _drawMenu(dc) {
        dc.setColor(0x080810, 0x080810); dc.clear();
        var hw = _sw / 2;
        if (_sw == _sh) {
            dc.setColor(0x0A0A18, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(hw, hw, hw - 1);
        }

        dc.setColor(0x00AAFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(hw, _sh * 11 / 100, Graphics.FONT_SMALL,
                    "TIC TAC PRO", Graphics.TEXT_JUSTIFY_CENTER);

        var modeStr = (_mode == MODE_PVAI) ? "P vs AI" : ((_mode == MODE_PVP) ? "P vs P" : "AI vs AI");
        var diffStr = (_diff == DIFF_EASY) ? "Easy" : ((_diff == DIFF_MED) ? "Med" : "Hard");
        var gridStr = "" + _gridN + "x" + _gridN;
        var sideStr = _playerFirst ? "Side: X" : "Side: O";
        var rows = ["Mode: " + modeStr, "Diff: " + diffStr, "Grid: " + gridStr, sideStr, "START"];
        var nR   = 5;
        var rowH = _sh * 10 / 100; if (rowH < 22) { rowH = 22; } if (rowH > 32) { rowH = 32; }
        var rowW = _sw * 76 / 100;
        var rowX = (_sw - rowW) / 2;
        var gap  = _sh * 2 / 100; if (gap < 3) { gap = 3; }
        var tot  = nR * rowH + (nR - 1) * gap;
        var rowY0 = (_sh - tot) / 2 + rowH;
        var i = 0;
        while (i < nR) {
            var ry     = rowY0 + i * (rowH + gap);
            var sel    = (i == _menuSel);
            var isStart = (i == nR - 1);
            dc.setColor(sel ? (isStart ? 0x3A1800 : 0x0A2040) : 0x0A0A18, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(rowX, ry, rowW, rowH, 5);
            dc.setColor(sel ? (isStart ? 0xFF8833 : 0x4499FF) : 0x1A2A3A, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(rowX, ry, rowW, rowH, 5);
            if (sel) {
                dc.setColor(isStart ? 0xFF8833 : 0x4499FF, Graphics.COLOR_TRANSPARENT);
                var ay = ry + rowH / 2;
                dc.fillPolygon([[rowX + 5, ay - 4], [rowX + 5, ay + 4], [rowX + 11, ay]]);
            }
            var dimmed = (i == 1 && _mode == MODE_PVP) || (i == 3 && _mode != MODE_PVAI);
            dc.setColor(dimmed ? 0x445566 :
                        (sel ? (isStart ? 0xFFCC88 : 0xAADDFF) : 0x556677),
                        Graphics.COLOR_TRANSPARENT);
            dc.drawText(hw, ry + (rowH - 14) / 2, Graphics.FONT_XTINY,
                        rows[i], Graphics.TEXT_JUSTIFY_CENTER);
            i++;
        }

        dc.setColor(0x334455, Graphics.COLOR_TRANSPARENT);
        dc.drawText(hw, _sh - 14, Graphics.FONT_XTINY,
                    "UP/DN move  SEL act", Graphics.TEXT_JUSTIFY_CENTER);
    }

    function doTap(tx, ty) {
        if (_state == GS_MENU) {
            var gap  = _sh * 2 / 100; if (gap < 3) { gap = 3; }
            var rowH = _sh * 10 / 100; if (rowH < 22) { rowH = 22; } if (rowH > 32) { rowH = 32; }
            var rowW = _sw * 76 / 100;
            var rowX = (_sw - rowW) / 2;
            var nR = 5;
            var tot  = nR * rowH + (nR - 1) * gap;
            var rowY0 = (_sh - tot) / 2 + rowH;
            for (var i = 0; i < nR; i++) {
                var ry = rowY0 + i * (rowH + gap);
                if (tx >= rowX && tx < rowX + rowW && ty >= ry && ty < ry + rowH) {
                    _menuSel = i; _menuAction(); return;
                }
            }
            return;
        }
        if (_state == GS_OVER) { _state = GS_MENU; _menuSel = 0; return; }
        if (_state != GS_PLAY && !(_state == GS_AI && _mode == MODE_PVP)) { return; }
        if (_cell <= 0) { return; }
        var col = (tx - _boardX) / _cell;
        var row = (ty - _boardY) / _cell;
        if (col < 0 || col >= _gridN || row < 0 || row >= _gridN) { return; }
        _curX = col; _curY = row;
        doAction();
    }
}
