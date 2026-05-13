using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.Math;

// ── Board ─────────────────────────────────────────────────────────────────
const HEX_N     = 7;    // 7×7 board

// ── Marks ─────────────────────────────────────────────────────────────────
const HM_NONE   = 0;
const HM_P      = 1;    // Player  — Red,  connects LEFT  (col 0) → RIGHT (col 6)
const HM_AI     = 2;    // AI      — Blue, connects TOP   (row 0) → BOTTOM (row 6)

// ── Game states ────────────────────────────────────────────────────────────
const HGS_PLAY  = 0;
const HGS_AI    = 1;    // 350 ms delay then AI places a stone
const HGS_OVER  = 2;

const HOV_NONE   = 0;
const HOV_PWIN   = 1;
const HOV_AIWIN  = 2;

const GS_MENU   = 10;
const MODE_PVAI = 0;
const MODE_PVP  = 1;
const MODE_AIAI = 2;
const DIFF_EASY = 0;
const DIFF_MED  = 1;
const DIFF_HARD = 2;

// ── GameView ───────────────────────────────────────────────────────────────
class GameView extends WatchUi.View {

    // ── Layout ────────────────────────────────────────────────────────────
    hidden var _sw, _sh;
    hidden var _boardX, _boardY;
    hidden var _dx;    // horizontal distance between adjacent cell centres (same row)
    hidden var _dy;    // vertical   distance between adjacent row centres
    hidden var _rad;   // stone circle radius

    // ── Board ─────────────────────────────────────────────────────────────
    hidden var _cells;      // int[HEX_N * HEX_N], row-major
    hidden var _moveCount;
    hidden var _lastR, _lastC;   // position of the most-recently placed stone

    // ── Cursor ────────────────────────────────────────────────────────────
    hidden var _curR, _curC;

    // ── Game flow ─────────────────────────────────────────────────────────
    hidden var _state;
    hidden var _overType;

    // ── Session score ─────────────────────────────────────────────────────
    hidden var _scoreP, _scoreAI;

    // ── Pre-game menu ─────────────────────────────────────────────────────
    hidden var _mode;
    hidden var _diff;
    hidden var _menuSel;
    hidden var _playerFirst;

    // ── BFS state — pre-allocated, reused every win-check ─────────────────
    // Hex adjacency (row-offset parallelogram layout):
    //   neighbours of (r, c): (r-1,c), (r-1,c+1), (r,c-1), (r,c+1), (r+1,c-1), (r+1,c)
    hidden var _bfsQueue;   // int[HEX_N * HEX_N]
    hidden var _bfsVis;     // int[HEX_N * HEX_N] — generation stamps, avoids clear
    hidden var _bfsGen;     // monotonic generation counter
    hidden var _bfsQi;      // queue read pointer
    hidden var _bfsQo;      // queue write pointer (one past last occupied slot)

    // ── Timer ─────────────────────────────────────────────────────────────
    hidden var _timer;

    // ─────────────────────────────────────────────────────────────────────
    function initialize() {
        View.initialize();
        _cells    = new [HEX_N * HEX_N];
        _bfsQueue = new [HEX_N * HEX_N];
        _bfsVis   = new [HEX_N * HEX_N];
        var i = 0;
        while (i < HEX_N * HEX_N) { _bfsVis[i] = 0; i = i + 1; }
        _bfsGen  = 0;
        _bfsQi   = 0;
        _bfsQo   = 0;
        _scoreP  = 0;
        _scoreAI = 0;
        _timer   = null;
        _mode    = MODE_PVAI;
        _diff    = DIFF_MED;
        _menuSel = 0;
        _playerFirst = true;
        _startGame();
        _state   = GS_MENU;
    }

    function onLayout(dc) {
        _sw = dc.getWidth();
        _sh = dc.getHeight();

        // Scale hex cell spacing to screen width (reference: 26 px on 390 px watch).
        _dx = _sw * 22 / 390;
        if (_dx < 18) { _dx = 18; }
        // dy ≈ dx * sqrt(3)/2; use integer approximation 87/100.
        _dy  = _dx * 87 / 100;
        if (_dy < 14) { _dy = 14; }
        // Stone radius: slightly smaller than half-spacing so stones have a gap.
        _rad = _dx * 44 / 100;

        // Parallelogram bounding-box width = (N-1)*dx + (N-1)*(dx/2) = (N-1)*3*dx/2.
        // For N=7: 6 * 3 * dx / 2 = 9 * dx.  Centre it horizontally.
        _boardX = (_sw - 9 * _dx) / 2;

        // Centre vertically; shift board slightly down for the HUD line above it.
        _boardY = (_sh - (HEX_N - 1) * _dy) / 2 + _sh * 3 / 100;
        if (_boardY < 28) { _boardY = 28; }

        _timer = new Timer.Timer();
        _timer.start(method(:gameTick), 350, true);
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); }
    }

    // ── Public input API ──────────────────────────────────────────────────

    function moveCursor(dr, dc2) {
        if (_state == GS_MENU) {
            if (dr < 0 || dc2 < 0) { _menuSel = (_menuSel + 3) % 4; }
            else if (dr > 0 || dc2 > 0) { _menuSel = (_menuSel + 1) % 4; }
            WatchUi.requestUpdate(); return;
        }
        if (_mode == MODE_AIAI) { return; }
        if (_state != HGS_PLAY && !(_state == HGS_AI && _mode == MODE_PVP)) { return; }
        _curR = _curR + dr;
        _curC = _curC + dc2;
        if (_curR < 0)        { _curR = 0; }
        if (_curR >= HEX_N)   { _curR = HEX_N - 1; }
        if (_curC < 0)        { _curC = 0; }
        if (_curC >= HEX_N)   { _curC = HEX_N - 1; }
        WatchUi.requestUpdate();
    }

    // onNextPage: move RIGHT in current row, wrap to col=0
    function advanceCursor() {
        if (_state == GS_MENU) {
            _menuSel = (_menuSel + 1) % 4;
            WatchUi.requestUpdate(); return;
        }
        if (_mode == MODE_AIAI) { return; }
        if (_state != HGS_PLAY && !(_state == HGS_AI && _mode == MODE_PVP)) { return; }
        _curC = (_curC + 1) % HEX_N;
        WatchUi.requestUpdate();
    }

    // onPreviousPage: move DOWN in current column, wrap to row=0
    function retreatCursor() {
        if (_state == GS_MENU) {
            _menuSel = (_menuSel + 3) % 4;
            WatchUi.requestUpdate(); return;
        }
        if (_mode == MODE_AIAI) { return; }
        if (_state != HGS_PLAY && !(_state == HGS_AI && _mode == MODE_PVP)) { return; }
        _curR = (_curR + 1) % HEX_N;
        WatchUi.requestUpdate();
    }

    // BACK: menu → pop app, in-game → return to menu
    function doBack() {
        if (_state == GS_MENU) { return false; }
        _state = GS_MENU; _menuSel = 0;
        return true;
    }

    function doAction() {
        if (_state == GS_MENU) {
            if (_menuSel == 0) { _mode = (_mode + 1) % 3; }
            else if (_menuSel == 1 && _mode != MODE_PVP) { _diff = (_diff + 1) % 3; }
            else if (_menuSel == 2) { if (_mode == MODE_PVAI) { _playerFirst = !_playerFirst; } }
            else if (_menuSel == 3) { _startGame(); }
            WatchUi.requestUpdate();
            return;
        }
        if (_state == HGS_OVER) { _state = GS_MENU; _menuSel = 0; WatchUi.requestUpdate(); return; }
        if (_mode == MODE_AIAI) { return; }
        // PvP: HGS_AI state is player 2's turn
        if (_state == HGS_AI && _mode == MODE_PVP) {
            if (_cells[_curR * HEX_N + _curC] != HM_NONE) { return; }
            _placeMark(_curR, _curC, HM_AI);
            if (_checkWin(HM_AI)) {
                _overType = HOV_AIWIN; _scoreAI = _scoreAI + 1; _state = HGS_OVER; return;
            }
            _state = HGS_PLAY;
            return;
        }
        if (_state != HGS_PLAY) { return; }
        if (_cells[_curR * HEX_N + _curC] != HM_NONE) { return; }
        _placeMark(_curR, _curC, HM_P);
        if (_checkWin(HM_P)) {
            _overType = HOV_PWIN; _scoreP = _scoreP + 1; _state = HGS_OVER; return;
        }
        _state = HGS_AI;
    }

    // ── 350 ms timer tick ─────────────────────────────────────────────────
    function gameTick() as Void {
        if (_mode == MODE_PVP) { return; }
        if (_state == HGS_AI) {
            _aiMove(HM_AI);
            if (_checkWin(HM_AI)) {
                _overType = HOV_AIWIN; _scoreAI = _scoreAI + 1; _state = HGS_OVER;
            } else {
                _state = HGS_PLAY;
            }
            WatchUi.requestUpdate();
        } else if (_mode == MODE_AIAI && _state == HGS_PLAY) {
            _aiMove(HM_P);
            if (_checkWin(HM_P)) {
                _overType = HOV_PWIN; _scoreP = _scoreP + 1; _state = HGS_OVER;
            } else {
                _state = HGS_AI;
            }
            WatchUi.requestUpdate();
        }
    }

    // ── Game management ───────────────────────────────────────────────────

    hidden function _startGame() {
        var i = 0;
        while (i < HEX_N * HEX_N) { _cells[i] = HM_NONE; i = i + 1; }
        _moveCount = 0;
        _curR      = HEX_N / 2;
        _curC      = HEX_N / 2;
        _lastR     = -1;
        _lastC     = -1;
        _overType  = HOV_NONE;
        if (_mode == MODE_AIAI) {
            _state = HGS_AI;
        } else if (_mode == MODE_PVAI && !_playerFirst) {
            _state = HGS_AI;
        } else {
            _state = HGS_PLAY;
        }
    }

    hidden function _placeMark(r, c, mark) {
        _cells[r * HEX_N + c] = mark;
        _moveCount = _moveCount + 1;
        _lastR = r;
        _lastC = c;
    }

    // ── BFS win check ─────────────────────────────────────────────────────
    // Player  (HM_P)  wins by connecting column 0 → column HEX_N-1.
    // AI      (HM_AI) wins by connecting row    0 → row    HEX_N-1.
    // Uses a generation counter to skip clearing the _bfsVis array.
    hidden function _checkWin(mark) {
        _bfsGen = _bfsGen + 1;
        var gen  = _bfsGen;
        _bfsQi   = 0;
        _bfsQo   = 0;

        // Seed queue from the starting edge.
        var i = 0;
        while (i < HEX_N) {
            // For player: starting edge = column 0; idx = row*N + 0.
            // For AI:     starting edge = row 0;    idx = 0*N  + col.
            var idx = (mark == HM_P) ? (i * HEX_N) : i;
            if (_cells[idx] == mark) {
                _bfsVis[idx] = gen;
                _bfsQueue[_bfsQo] = idx;
                _bfsQo = _bfsQo + 1;
            }
            i = i + 1;
        }

        while (_bfsQi < _bfsQo) {
            var idx2 = _bfsQueue[_bfsQi]; _bfsQi = _bfsQi + 1;
            var cr   = idx2 / HEX_N;
            var cc   = idx2 % HEX_N;

            // Check reaching the target edge.
            if ((mark == HM_P  && cc == HEX_N - 1) ||
                (mark == HM_AI && cr == HEX_N - 1)) { return true; }

            // Visit all 6 hex neighbours.
            // Layout: row r is offset r*(dx/2) to the right, so adjacency is:
            // (r-1,c), (r-1,c+1), (r,c-1), (r,c+1), (r+1,c-1), (r+1,c)
            _bfsVisit(cr - 1, cc,     mark, gen);
            _bfsVisit(cr - 1, cc + 1, mark, gen);
            _bfsVisit(cr,     cc - 1, mark, gen);
            _bfsVisit(cr,     cc + 1, mark, gen);
            _bfsVisit(cr + 1, cc - 1, mark, gen);
            _bfsVisit(cr + 1, cc,     mark, gen);
        }
        return false;
    }

    hidden function _bfsVisit(r, c, mark, gen) {
        if (r < 0 || r >= HEX_N || c < 0 || c >= HEX_N) { return; }
        var idx = r * HEX_N + c;
        if (_cells[idx] != mark || _bfsVis[idx] == gen) { return; }
        _bfsVis[idx]        = gen;
        _bfsQueue[_bfsQo]   = idx;
        _bfsQo              = _bfsQo + 1;
    }

    // ── AI — BFS path + connectivity + defence heuristic ─────────────────
    // Med/Hard: BFS counts reachable cells for each mark to estimate path progress.
    // Placing at a cell that blocks opp's shortest path AND extends own path is ideal.
    // Hard also simulates opponent response to penalise moves that let opp advance fast.
    //
    // Watchdog safety: 49 cells × (BFS-reach ~49 ops + 6 neighbour checks) ≈ 49 × 60 = 2940 ops.
    hidden function _aiMove(mark) {
        var best   = -9999;
        var move   = -1;
        var mid    = HEX_N / 2;
        var isHard = (_diff == DIFF_HARD);
        var isMed  = (_diff == DIFF_MED);
        var noise  = (_diff == DIFF_EASY) ? 20 : (isHard ? 1 : 4);
        var opp    = (mark == HM_AI) ? HM_P : HM_AI;
        var nv     = 0;
        var i      = 0;
        while (i < HEX_N * HEX_N) {
            if (_cells[i] == HM_NONE) {
                var r   = i / HEX_N;
                var c   = i % HEX_N;

                // Centre bias
                var dr  = r - mid; if (dr  < 0) { dr  = -dr;  }
                var dc2 = c - mid; if (dc2 < 0) { dc2 = -dc2; }
                var score = (HEX_N - dr - dc2) * 3;

                // Path bonus: progress toward goal edge
                var distMid = (mark == HM_AI) ? (r - mid) : (c - mid);
                if (distMid < 0) { distMid = -distMid; }
                score = score + (HEX_N - distMid * 2);

                // Count hex neighbours
                var nSelf = 0; var nOpp = 0;
                if (r - 1 >= 0) {
                    nv = _cells[(r - 1) * HEX_N + c];
                    if (nv == mark) { nSelf = nSelf + 1; } else if (nv == opp) { nOpp = nOpp + 1; }
                }
                if (r - 1 >= 0 && c + 1 < HEX_N) {
                    nv = _cells[(r - 1) * HEX_N + (c + 1)];
                    if (nv == mark) { nSelf = nSelf + 1; } else if (nv == opp) { nOpp = nOpp + 1; }
                }
                if (c - 1 >= 0) {
                    nv = _cells[r * HEX_N + (c - 1)];
                    if (nv == mark) { nSelf = nSelf + 1; } else if (nv == opp) { nOpp = nOpp + 1; }
                }
                if (c + 1 < HEX_N) {
                    nv = _cells[r * HEX_N + (c + 1)];
                    if (nv == mark) { nSelf = nSelf + 1; } else if (nv == opp) { nOpp = nOpp + 1; }
                }
                if (r + 1 < HEX_N && c - 1 >= 0) {
                    nv = _cells[(r + 1) * HEX_N + (c - 1)];
                    if (nv == mark) { nSelf = nSelf + 1; } else if (nv == opp) { nOpp = nOpp + 1; }
                }
                if (r + 1 < HEX_N) {
                    nv = _cells[(r + 1) * HEX_N + c];
                    if (nv == mark) { nSelf = nSelf + 1; } else if (nv == opp) { nOpp = nOpp + 1; }
                }

                var mult = isHard ? 3 : (isMed ? 2 : 1);
                score = score + nSelf * 10 * mult + nOpp * 8 * mult;

                // Med/Hard: BFS reach bonus — count how many cells of mark's colour
                // are reachable from start edge through this candidate cell.
                // Temporarily place mark, run BFS-count, remove.
                if (isMed || isHard) {
                    _cells[i] = mark;
                    var reach = _bfsReachCount(mark);
                    _cells[i] = HM_NONE;
                    // Also count opp reach without this cell (blocking effect)
                    var oppReach = _bfsReachCount(opp);
                    score = score + reach * 5 - oppReach * 6;
                }

                score = score + Math.rand() % noise;
                if (score > best) { best = score; move = i; }
            }
            i = i + 1;
        }
        if (move >= 0) { _placeMark(move / HEX_N, move % HEX_N, mark); }
    }

    // Count how many cells of 'mark' are reachable from the starting edge via BFS.
    // AI (HM_AI): starting edge = row 0.   Player (HM_P): starting edge = col 0.
    // Reachability counts own cells + empty cells adjacent to own cells.
    // O(HEX_N²) — fast BFS.
    hidden function _bfsReachCount(mark) {
        _bfsGen = _bfsGen + 1;
        var gen = _bfsGen;
        _bfsQi = 0; _bfsQo = 0;
        var i = 0;
        while (i < HEX_N) {
            var idx = (mark == HM_AI) ? i : (i * HEX_N);
            if (_cells[idx] == mark || _cells[idx] == HM_NONE) {
                if (_bfsVis[idx] != gen) {
                    _bfsVis[idx] = gen;
                    _bfsQueue[_bfsQo] = idx;
                    _bfsQo = _bfsQo + 1;
                }
            }
            i = i + 1;
        }
        var cnt = 0;
        while (_bfsQi < _bfsQo) {
            var idx2 = _bfsQueue[_bfsQi]; _bfsQi = _bfsQi + 1;
            if (_cells[idx2] == mark) { cnt = cnt + 2; } else { cnt = cnt + 1; }
            var cr = idx2 / HEX_N; var cc = idx2 % HEX_N;
            _bfsVisitReach(cr - 1, cc,     mark, gen);
            _bfsVisitReach(cr - 1, cc + 1, mark, gen);
            _bfsVisitReach(cr,     cc - 1, mark, gen);
            _bfsVisitReach(cr,     cc + 1, mark, gen);
            _bfsVisitReach(cr + 1, cc - 1, mark, gen);
            _bfsVisitReach(cr + 1, cc,     mark, gen);
        }
        return cnt;
    }

    hidden function _bfsVisitReach(r, c, mark, gen) {
        if (r < 0 || r >= HEX_N || c < 0 || c >= HEX_N) { return; }
        var idx = r * HEX_N + c;
        if (_bfsVis[idx] == gen) { return; }
        var v = _cells[idx];
        if (v == mark || v == HM_NONE) {
            _bfsVis[idx] = gen;
            _bfsQueue[_bfsQo] = idx;
            _bfsQo = _bfsQo + 1;
        }
    }

    // ── Rendering ─────────────────────────────────────────────────────────
    function onUpdate(dc) {
        if (_state == GS_MENU) { _drawMenu(dc); return; }
        dc.setColor(0x06060E, 0x06060E);
        dc.clear();

        _drawEdgeBands(dc);
        _drawGridLines(dc);
        _drawStones(dc);
        _drawCursor(dc);
        _drawHUD(dc);

        if (_state == HGS_OVER) { _drawGameOver(dc); }
    }

    // ── Cell centre coordinates ───────────────────────────────────────────
    // Row r is shifted r*(dx/2) to the right to form the parallelogram.
    hidden function _cx(r, c) { return _boardX + c * _dx + r * (_dx / 2); }
    hidden function _cy(r, c) { return _boardY + r * _dy; }

    // ── Edge bands — coloured dots outside each of the 4 board edges ─────
    // Red  dots on left (col 0) and right (col N-1) — Player's goal axis.
    // Blue dots on top  (row 0) and bot  (row N-1) — AI's   goal axis.
    hidden function _drawEdgeBands(dc) {
        var off = _rad + 5;     // how far outside the cell centre to draw
        var r   = 0;
        dc.setColor(0xFF2200, Graphics.COLOR_TRANSPARENT);
        while (r < HEX_N) {
            dc.fillCircle(_cx(r, 0)        - off, _cy(r, 0),        3);
            dc.fillCircle(_cx(r, HEX_N-1) + off, _cy(r, HEX_N-1), 3);
            r = r + 1;
        }
        var c = 0;
        dc.setColor(0x0099FF, Graphics.COLOR_TRANSPARENT);
        while (c < HEX_N) {
            dc.fillCircle(_cx(0,        c), _cy(0,        c) - off, 3);
            dc.fillCircle(_cx(HEX_N-1, c), _cy(HEX_N-1, c) + off, 3);
            c = c + 1;
        }
    }

    // ── Grid lines — draw each edge once using 3 forward directions ───────
    // Directions: right (r,c+1), lower-left (r+1,c-1), lower-right (r+1,c).
    hidden function _drawGridLines(dc) {
        dc.setColor(0x2A2A44, Graphics.COLOR_TRANSPARENT);
        var r = 0;
        while (r < HEX_N) {
            var c = 0;
            while (c < HEX_N) {
                var px = _cx(r, c);
                var py = _cy(r, c);
                if (c + 1 < HEX_N) {
                    dc.drawLine(px, py, _cx(r, c + 1), _cy(r, c + 1));
                }
                if (r + 1 < HEX_N && c - 1 >= 0) {
                    dc.drawLine(px, py, _cx(r + 1, c - 1), _cy(r + 1, c - 1));
                }
                if (r + 1 < HEX_N) {
                    dc.drawLine(px, py, _cx(r + 1, c), _cy(r + 1, c));
                }
                c = c + 1;
            }
            r = r + 1;
        }
    }

    // ── Stones ────────────────────────────────────────────────────────────
    hidden function _drawStones(dc) {
        var r = 0;
        while (r < HEX_N) {
            var c = 0;
            while (c < HEX_N) {
                var px   = _cx(r, c);
                var py   = _cy(r, c);
                var mark = _cells[r * HEX_N + c];

                if (mark == HM_P) {
                    dc.setColor(0xFF2200, Graphics.COLOR_TRANSPARENT);
                    dc.fillCircle(px, py, _rad);
                    // Bright centre dot on last-placed stone
                    if (r == _lastR && c == _lastC) {
                        dc.setColor(0xFFAAAA, Graphics.COLOR_TRANSPARENT);
                        dc.fillCircle(px, py, _rad * 35 / 100);
                    }
                } else if (mark == HM_AI) {
                    dc.setColor(0x0099FF, Graphics.COLOR_TRANSPARENT);
                    dc.fillCircle(px, py, _rad);
                    if (r == _lastR && c == _lastC) {
                        dc.setColor(0xAADDFF, Graphics.COLOR_TRANSPARENT);
                        dc.fillCircle(px, py, _rad * 35 / 100);
                    }
                } else {
                    // Empty cell — slightly lighter than background
                    dc.setColor(0x1A1A2E, Graphics.COLOR_TRANSPARENT);
                    dc.fillCircle(px, py, _rad);
                }
                c = c + 1;
            }
            r = r + 1;
        }
    }

    // ── Cursor ────────────────────────────────────────────────────────────
    hidden function _drawCursor(dc) {
        if (_state == HGS_OVER) { return; }
        var px = _cx(_curR, _curC);
        var py = _cy(_curR, _curC);
        var occupied = (_cells[_curR * HEX_N + _curC] != HM_NONE);
        dc.setColor(occupied ? 0xFF6600 : 0xFFFF00, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(px, py, _rad + 2);
        dc.drawCircle(px, py, _rad + 3);
    }

    // ── HUD ───────────────────────────────────────────────────────────────
    hidden function _drawHUD(dc) {
        var ty = _sh * 3 / 100;

        // Session score labels (P1/P2 in PvP, YOU/AI otherwise)
        var lbl1 = (_mode == MODE_PVP) ? "P1 " : "YOU ";
        var lbl2 = (_mode == MODE_PVP) ? " P2" : " AI";
        dc.setColor(0xFF2200, Graphics.COLOR_TRANSPARENT);
        dc.drawText(10, ty, Graphics.FONT_XTINY,
                    lbl1 + _scoreP.format("%d"), Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(0x0099FF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_sw - 10, ty, Graphics.FONT_XTINY,
                    _scoreAI.format("%d") + lbl2, Graphics.TEXT_JUSTIFY_RIGHT);

        // Turn indicator
        if (_state == HGS_PLAY) {
            var turnTxt = (_mode == MODE_PVP) ? "P1 TURN" : ((_mode == MODE_AIAI) ? "P1..." : "YOUR TURN");
            dc.setColor(0x44FF44, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_sw / 2, ty, Graphics.FONT_XTINY, turnTxt, Graphics.TEXT_JUSTIFY_CENTER);
        } else if (_state == HGS_AI) {
            var aiTxt = (_mode == MODE_PVP) ? "P2 TURN" : ((_mode == MODE_AIAI) ? "P2..." : "AI...");
            dc.setColor((_mode == MODE_PVP) ? 0x44FF44 : 0x555566, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_sw / 2, ty, Graphics.FONT_XTINY, aiTxt, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Direction hints below the board (concise ASCII arrows)
        var hintY = _boardY + (HEX_N - 1) * _dy + _rad + 10;
        if (hintY < _sh - 28) {
            dc.setColor(0xFF3300, Graphics.COLOR_TRANSPARENT);
            dc.drawText(10, hintY, Graphics.FONT_XTINY,
                        "YOU<>", Graphics.TEXT_JUSTIFY_LEFT);
            dc.setColor(0x0099FF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_sw - 10, hintY, Graphics.FONT_XTINY,
                        "AI^v", Graphics.TEXT_JUSTIFY_RIGHT);
        }
        // Exit hint
        var exitY = hintY + 14;
        if (exitY < _sh - 10) {
            dc.setColor(0x1A1A2A, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_sw / 2, exitY, Graphics.FONT_XTINY,
                        "BACK = exit", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── Pre-game menu ─────────────────────────────────────────────────────
    hidden function _drawMenu(dc) {
        dc.setColor(0x080810, 0x080810); dc.clear();
        var hw = _sw / 2;
        dc.setColor(0x0A0A18, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(hw, hw, hw - 1);
        dc.setColor(0xFF4422, Graphics.COLOR_TRANSPARENT);
        dc.drawText(hw, _sh * 11 / 100, Graphics.FONT_SMALL, "HEX MINI", Graphics.TEXT_JUSTIFY_CENTER);
        var modeStr = (_mode == MODE_PVAI) ? "P vs AI" : ((_mode == MODE_PVP) ? "P vs P" : "AI vs AI");
        var diffStr = (_diff == DIFF_EASY) ? "Easy" : ((_diff == DIFF_MED) ? "Med" : "Hard");
        var sideStr = _playerFirst ? "Side: Red" : "Side: Blu";
        var rows = ["Mode: " + modeStr, "Diff: " + diffStr, sideStr, "START"];
        var nR = 4;
        var rowH = _sh * 10 / 100; if (rowH < 22) { rowH = 22; } if (rowH > 30) { rowH = 30; }
        var rowW = _sw * 74 / 100;
        var rowX = (_sw - rowW) / 2;
        var gap  = _sh * 2 / 100; if (gap < 3) { gap = 3; }
        var tot  = nR * rowH + (nR - 1) * gap;
        var rowY0 = (_sh - tot) / 2 + rowH;
        var i = 0;
        while (i < nR) {
            var ry  = rowY0 + i * (rowH + gap);
            var sel = (i == _menuSel);
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
            var dimmed = (i == 1 && _mode == MODE_PVP) || (i == 2 && _mode != MODE_PVAI);
            dc.setColor(dimmed ? 0x445566 : (sel ? (isStart ? 0xFFCC88 : 0xAADDFF) : 0x556677), Graphics.COLOR_TRANSPARENT);
            dc.drawText(hw, ry + (rowH - 14) / 2, Graphics.FONT_XTINY, rows[i], Graphics.TEXT_JUSTIFY_CENTER);
            i++;
        }
        dc.setColor(0x334455, Graphics.COLOR_TRANSPARENT);
        dc.drawText(hw, _sh - 14, Graphics.FONT_XTINY, "UP/DN sel  SELECT set/start", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Game-over overlay ─────────────────────────────────────────────────
    hidden function _drawGameOver(dc) {
        var bw = _sw * 54 / 100; var bh = _sh * 29 / 100;
        if (bw < 148) { bw = 148; } if (bh < 88) { bh = 88; }
        var bx = _sw / 2 - bw / 2;
        var by = _sh / 2 - bh / 2;

        dc.setColor(0x040408, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bx, by, bw, bh, 8);
        dc.setColor(0x3A3A5A, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(bx, by, bw, bh, 8);

        var cx  = _sw / 2;
        var msg = ""; var msgCol = 0xCCCCCC;
        if (_overType == HOV_PWIN) { msg = "YOU WIN!"; msgCol = 0xFF2200; }
        else                        { msg = "AI WINS!"; msgCol = 0x0099FF; }

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

    function doTap(tx, ty) {
        if (_state == GS_MENU) {
            var nR = 4;
            var rowH = _sh * 10 / 100; if (rowH < 22) { rowH = 22; } if (rowH > 30) { rowH = 30; }
            var rowW = _sw * 74 / 100;
            var rowX = (_sw - rowW) / 2;
            var gap  = _sh * 2 / 100; if (gap < 3) { gap = 3; }
            var tot  = nR * rowH + (nR - 1) * gap;
            var rowY0 = (_sh - tot) / 2 + rowH;
            for (var i = 0; i < nR; i++) {
                var ry = rowY0 + i * (rowH + gap);
                if (tx >= rowX && tx < rowX + rowW && ty >= ry && ty < ry + rowH) {
                    _menuSel = i; doAction(); return;
                }
            }
            return;
        }
        if (_state == HGS_OVER) { _state = GS_MENU; _menuSel = 0; return; }
        if (_state != HGS_PLAY && !(_state == HGS_AI && _mode == MODE_PVP)) { return; }
        if (_dx <= 0 || _dy <= 0) { return; }
        // Find nearest hex cell using pixel-to-hex inverse of _cx/_cy:
        //   _cx(r,c) = _boardX + c*_dx + r*(_dx/2)
        //   _cy(r,c) = _boardY + r*_dy
        var bestR = 0; var bestC = 0; var bestDist = 0x7FFFFFFF;
        for (var r = 0; r < HEX_N; r++) {
            for (var c = 0; c < HEX_N; c++) {
                var px = _boardX + c * _dx + r * (_dx / 2);
                var py = _boardY + r * _dy;
                var dx2 = tx - px; var dy2 = ty - py;
                var dist = dx2 * dx2 + dy2 * dy2;
                if (dist < bestDist) { bestDist = dist; bestR = r; bestC = c; }
            }
        }
        _curR = bestR; _curC = bestC;
        doAction();
    }
}
