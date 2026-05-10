using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.Math;

// ── Territory Clash ───────────────────────────────────────────────────────
//
// Simplified Go-like territory control on a 9×9 board.
//
// Board encoding:  flat array, index = y * TC_N + x
//   0 = TC_EMP  (empty)
//   1 = TC_P    (player — Black)
//   2 = TC_AI   (AI — White)
//
// Capture rule: after placing a stone, any opponent group with zero liberties
//   (no empty 4-directional neighbours across the whole connected group)
//   is removed. Suicide (own group has 0 liberties after captures) is illegal.
//
// Scoring (Japanese-style):
//   score = territory (empty cells surrounded only by your stones)
//         + captured opponent stones
//
// Game ends: board full  OR  two consecutive passes.

const TC_N     = 9;
const TC_CELLS = 81;   // TC_N * TC_N

const TC_EMP   = 0;
const TC_P     = 1;
const TC_AI    = 2;

// Game states
const TC_PLAY  = 0;    // player's turn
const TC_AIST  = 1;    // AI's turn (timer-driven)
const TC_OVER  = 2;

// Pre-game menu
const GS_MENU   = 10;
const MODE_PVAI = 0;
const MODE_PVP  = 1;
const MODE_AIAI = 2;
const DIFF_EASY = 0;
const DIFF_MED  = 1;
const DIFF_HARD = 2;

// ── GameView ──────────────────────────────────────────────────────────────
class GameView extends WatchUi.View {

    // ── Layout ────────────────────────────────────────────────────────────
    hidden var _sw, _sh;
    hidden var _step;       // pixel spacing between intersections
    hidden var _boardX;     // x of intersection (0, 0)
    hidden var _boardY;     // y of intersection (0, 0)
    hidden var _stoneR;     // stone radius in pixels

    // ── Board + BFS scratch — pre-allocated ───────────────────────────────
    hidden var _board;      // int[81]      board state
    hidden var _visit;      // bool[81]     BFS membership scratch
    hidden var _queue;      // int[81]      BFS queue scratch
    hidden var _terr;       // int[81]      territory display (TC_EMP / TC_P / TC_AI)

    // ── Game state ────────────────────────────────────────────────────────
    hidden var _curX, _curY;    // cursor grid position (0..8)
    hidden var _state;

    // ── Menu state ────────────────────────────────────────────────────────
    hidden var _mode;
    hidden var _diff;
    hidden var _menuSel;
    hidden var _playerFirst;
    hidden var _captP;          // stones player captured from AI
    hidden var _captAI;         // stones AI captured from player
    hidden var _passCount;      // consecutive passes
    hidden var _scoreP;         // final scores (computed at end)
    hidden var _scoreAI;
    hidden var _lastMove;       // cell index of last placed stone (-1 = none)

    // ── Session ───────────────────────────────────────────────────────────
    hidden var _sP, _sAI;
    hidden var _timer;

    // ─────────────────────────────────────────────────────────────────────
    function initialize() {
        View.initialize();
        _board = new [TC_CELLS];
        _visit = new [TC_CELLS];
        _queue = new [TC_CELLS];
        _terr  = new [TC_CELLS];
        _sP  = 0;
        _sAI = 0;
        _timer = null;
        _startGame();
        _state   = GS_MENU;
        _mode    = MODE_PVAI;
        _diff    = DIFF_MED;
        _menuSel = 0;
        _playerFirst = true;
    }

    function onLayout(dc) {
        _sw = dc.getWidth();
        _sh = dc.getHeight();
        // Available area (30 px top strip + 30 px bottom strip), board 10% smaller
        var avH = _sh - 60;
        var avW = _sw - 20;
        var avSz = avH < avW ? avH : avW;
        _step   = avSz / (TC_N - 1);
        _step   = _step * 9 / 10;  // shrink board 10%
        if (_step < 18) { _step = 18; }
        var bw  = _step * (TC_N - 1);
        _boardX = (_sw - bw) / 2;
        _boardY = 30 + (_sh - 60 - bw) / 2;
        _stoneR = _step / 2 - 1;
        if (_stoneR > 16) { _stoneR = 16; }
        if (_stoneR < 4)  { _stoneR = 4;  }
        _timer  = new Timer.Timer();
        _timer.start(method(:gameTick), 700, true);
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); }
    }

    // ── Public API ────────────────────────────────────────────────────────
    // dir: 0=UP  1=DOWN  2=LEFT  3=RIGHT
    function navigate(dir) {
        if (_state == GS_MENU) {
            if (dir == 0 || dir == 2) { _menuSel = (_menuSel + 3) % 4; }
            else if (dir == 1 || dir == 3) { _menuSel = (_menuSel + 1) % 4; }
            WatchUi.requestUpdate();
            return;
        }
        if (_state != TC_PLAY && !(_state == TC_AIST && _mode == MODE_PVP)) { return; }
        if (dir == 0 && _curY > 0)        { _curY = _curY - 1; }
        if (dir == 1 && _curY < TC_N - 1) { _curY = _curY + 1; }
        if (dir == 2 && _curX > 0)        { _curX = _curX - 1; }
        if (dir == 3 && _curX < TC_N - 1) { _curX = _curX + 1; }
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
            else if (_menuSel == 3) {
                _startGame();
                if (_mode == MODE_AIAI) { _state = TC_AIST; }
            }
            WatchUi.requestUpdate();
            return;
        }
        if (_state == TC_OVER) { _state = GS_MENU; _menuSel = 0; WatchUi.requestUpdate(); return; }
        if (_state == TC_AIST && _mode == MODE_PVP) {
            var ci = _curY * TC_N + _curX;
            if (_placeStone(ci, TC_AI)) {
                _lastMove = ci; _passCount = 0; _checkWin();
                if (_state != TC_OVER) { _state = TC_PLAY; }
            }
            WatchUi.requestUpdate();
            return;
        }
        if (_state != TC_PLAY) { return; }
        var ci = _curY * TC_N + _curX;
        if (_placeStone(ci, TC_P)) {
            _lastMove  = ci;
            _passCount = 0;
            _checkWin();
            if (_state != TC_OVER) { _state = TC_AIST; }
        }
    }

    function doPass() {
        if (_state == TC_OVER) { return; }
        if (_state == TC_AIST && _mode == MODE_PVP) {
            _passCount = _passCount + 1;
            if (_passCount >= 2) { _endGame(); return; }
            _lastMove = -1;
            _state    = TC_PLAY;
            return;
        }
        if (_state != TC_PLAY) { return; }
        _passCount = _passCount + 1;
        if (_passCount >= 2) { _endGame(); return; }
        _lastMove = -1;
        _state    = TC_AIST;
    }

    function isOver() { return _state == TC_OVER; }

    // ── Timer ─────────────────────────────────────────────────────────────
    function gameTick() {
        if (_state == TC_AIST) {
            if (_mode == MODE_PVP) {
                // PvP: P2 (White) acts via input — do nothing here
            } else {
                _aiDoTurn();
            }
            WatchUi.requestUpdate();
        } else if (_state == TC_PLAY && _mode == MODE_AIAI) {
            _aiPlaceAs(TC_P);
            WatchUi.requestUpdate();
        }
    }

    // ── Game management ───────────────────────────────────────────────────
    hidden function _startGame() {
        var i = 0;
        while (i < TC_CELLS) {
            _board[i] = TC_EMP;
            _terr[i]  = TC_EMP;
            i++;
        }
        _curX      = TC_N / 2;
        _curY      = TC_N / 2;
        _captP     = 0;
        _captAI    = 0;
        _passCount = 0;
        _scoreP    = 0;
        _scoreAI   = 0;
        _lastMove  = -1;
        if (_mode == MODE_PVAI && !_playerFirst) {
            _state = TC_AIST;
        } else {
            _state = TC_PLAY;
        }
    }

    // ── Core BFS / capture logic ──────────────────────────────────────────

    // Compute liberty count for the group containing cell ci (of given color).
    // Fills _visit[] with true for all group members.
    // Zero liberties → group is captured.
    hidden function _checkGroup(ci, color) {
        var i = 0;
        while (i < TC_CELLS) { _visit[i] = false; i++; }
        _queue[0] = ci;  _visit[ci] = true;
        var head = 0;    var tail   = 1;
        var libs = 0;
        while (head < tail) {
            var c  = _queue[head]; head++;
            var cx = c % TC_N;
            var cy = c / TC_N;
            if (cx > 0) {
                var nc = c - 1;
                if (_board[nc] == TC_EMP) { libs++; }
                else if (_board[nc] == color && !_visit[nc]) { _visit[nc] = true; _queue[tail] = nc; tail++; }
            }
            if (cx < TC_N - 1) {
                var nc = c + 1;
                if (_board[nc] == TC_EMP) { libs++; }
                else if (_board[nc] == color && !_visit[nc]) { _visit[nc] = true; _queue[tail] = nc; tail++; }
            }
            if (cy > 0) {
                var nc = c - TC_N;
                if (_board[nc] == TC_EMP) { libs++; }
                else if (_board[nc] == color && !_visit[nc]) { _visit[nc] = true; _queue[tail] = nc; tail++; }
            }
            if (cy < TC_N - 1) {
                var nc = c + TC_N;
                if (_board[nc] == TC_EMP) { libs++; }
                else if (_board[nc] == color && !_visit[nc]) { _visit[nc] = true; _queue[tail] = nc; tail++; }
            }
        }
        return libs;
    }

    // Remove all stones marked in _visit[] (set to TC_EMP). Returns count.
    hidden function _removeGroup() {
        var count = 0;
        var i = 0;
        while (i < TC_CELLS) {
            if (_visit[i]) { _board[i] = TC_EMP; count++; }
            i++;
        }
        return count;
    }

    // Place stone at ci for color. Handles captures and suicide prevention.
    // Returns true if the move was legal.
    hidden function _placeStone(ci, color) {
        if (_board[ci] != TC_EMP) { return false; }
        _board[ci] = color;
        var opp  = (color == TC_P) ? TC_AI : TC_P;
        var cx   = ci % TC_N;
        var cy   = ci / TC_N;
        var caps = 0;
        // Capture opponent groups that lost their last liberty
        if (cx > 0) {
            var nc = ci - 1;
            if (_board[nc] == opp && _checkGroup(nc, opp) == 0) { caps += _removeGroup(); }
        }
        if (cx < TC_N - 1) {
            var nc = ci + 1;
            if (_board[nc] == opp && _checkGroup(nc, opp) == 0) { caps += _removeGroup(); }
        }
        if (cy > 0) {
            var nc = ci - TC_N;
            if (_board[nc] == opp && _checkGroup(nc, opp) == 0) { caps += _removeGroup(); }
        }
        if (cy < TC_N - 1) {
            var nc = ci + TC_N;
            if (_board[nc] == opp && _checkGroup(nc, opp) == 0) { caps += _removeGroup(); }
        }
        // Suicide check: if own group still has no liberties, undo
        if (caps == 0 && _checkGroup(ci, color) == 0) {
            _board[ci] = TC_EMP;
            return false;
        }
        if (color == TC_P) { _captP  = _captP  + caps; }
        else               { _captAI = _captAI + caps; }
        return true;
    }

    // Check if the board is full → end game.
    hidden function _checkWin() {
        var i = 0;
        while (i < TC_CELLS) {
            if (_board[i] == TC_EMP) { return; }
            i++;
        }
        _endGame();
    }

    hidden function _endGame() {
        _calcScore();
        if      (_scoreP  > _scoreAI) { _sP  = _sP  + 1; }
        else if (_scoreAI > _scoreP)  { _sAI = _sAI + 1; }
        _state = TC_OVER;
    }

    // Territory BFS: find empty regions; assign to whoever surrounds them.
    // Fills _terr[] for end-game display.  Modifies _visit[] and _queue[].
    hidden function _calcScore() {
        var stonesP = 0; var stonesAI = 0;
        var i = 0;
        while (i < TC_CELLS) {
            if (_board[i] == TC_P)  { stonesP++;  }
            if (_board[i] == TC_AI) { stonesAI++; }
            _terr[i]  = TC_EMP;
            _visit[i] = false;
            i++;
        }
        var terrP = 0; var terrAI = 0;
        i = 0;
        while (i < TC_CELLS) {
            if (_board[i] == TC_EMP && !_visit[i]) {
                _queue[0] = i; _visit[i] = true;
                var head = 0; var tail = 1;
                var bP = 0;   var bAI  = 0;
                while (head < tail) {
                    var c  = _queue[head]; head++;
                    var cx = c % TC_N;
                    var cy = c / TC_N;
                    if (cx > 0) {
                        var nc = c - 1;
                        if      (_board[nc] == TC_EMP && !_visit[nc]) { _visit[nc] = true; _queue[tail] = nc; tail++; }
                        else if (_board[nc] == TC_P)  { bP  = bP  + 1; }
                        else if (_board[nc] == TC_AI) { bAI = bAI + 1; }
                    }
                    if (cx < TC_N - 1) {
                        var nc = c + 1;
                        if      (_board[nc] == TC_EMP && !_visit[nc]) { _visit[nc] = true; _queue[tail] = nc; tail++; }
                        else if (_board[nc] == TC_P)  { bP  = bP  + 1; }
                        else if (_board[nc] == TC_AI) { bAI = bAI + 1; }
                    }
                    if (cy > 0) {
                        var nc = c - TC_N;
                        if      (_board[nc] == TC_EMP && !_visit[nc]) { _visit[nc] = true; _queue[tail] = nc; tail++; }
                        else if (_board[nc] == TC_P)  { bP  = bP  + 1; }
                        else if (_board[nc] == TC_AI) { bAI = bAI + 1; }
                    }
                    if (cy < TC_N - 1) {
                        var nc = c + TC_N;
                        if      (_board[nc] == TC_EMP && !_visit[nc]) { _visit[nc] = true; _queue[tail] = nc; tail++; }
                        else if (_board[nc] == TC_P)  { bP  = bP  + 1; }
                        else if (_board[nc] == TC_AI) { bAI = bAI + 1; }
                    }
                }
                // Assign territory
                var owner = TC_EMP;
                if (bP > 0 && bAI == 0) { owner = TC_P;  terrP  = terrP  + tail; }
                if (bAI > 0 && bP == 0) { owner = TC_AI; terrAI = terrAI + tail; }
                if (owner != TC_EMP) {
                    var j = 0;
                    while (j < tail) { _terr[_queue[j]] = owner; j++; }
                }
            }
            i++;
        }
        // Territory + captures (Japanese-style)
        _scoreP  = terrP  + _captP;
        _scoreAI = terrAI + _captAI;
    }

    // ── AI ────────────────────────────────────────────────────────────────
    //
    // Heuristic per empty cell (no board modification):
    //   • Center bonus: 18 − 2 × manhattan_distance_from_centre
    //   • Capture bonus  +30: adjacent player group is in atari (1 liberty)
    //   • Defence bonus  +20: adjacent AI group is in atari
    //   • Random noise: 0..6
    // Best-scored legal move is played; falls back to first valid cell.
    //
    // Watchdog safety: 81 cells × _aiEval(≤4 × _checkGroup(BFS≤405 ops) + 12 influence + 5 territory)
    //   ≈ 81 × (4×405 + 17) ≈ 81 × 1 637 ≈ 132K ops per tick.
    //   Well within 1.5 s watchdog budget — no multi-tick split required.

    hidden function _aiEval(ci) {
        var cx   = ci % TC_N;
        var cy   = ci / TC_N;
        var mid  = TC_N / 2;
        var dx   = cx > mid ? cx - mid : mid - cx;
        var dy   = cy > mid ? cy - mid : mid - cy;
        var score = 18 - (dx + dy) * 2;

        var hard     = (_diff == DIFF_HARD);
        var capBonus = hard ? 60 : 30;
        var defBonus = hard ? 40 : 20;
        var cap2     = capBonus / 2;   // half bonus for 2-liberty (soon-threatened) groups
        var def2     = defBonus / 2;

        // Capture / defence — check all 4 orthogonal neighbours
        var lib = 0;
        if (cx > 0) {
            var nc = ci - 1;
            if (_board[nc] == TC_P) {
                lib = _checkGroup(nc, TC_P);
                if (lib == 1) { score = score + capBonus; }
                else if (lib == 2) { score = score + cap2; }
            } else if (_board[nc] == TC_AI) {
                lib = _checkGroup(nc, TC_AI);
                if (lib == 1) { score = score + defBonus; }
                else if (lib == 2) { score = score + def2; }
            }
        }
        if (cx < TC_N - 1) {
            var nc = ci + 1;
            if (_board[nc] == TC_P) {
                lib = _checkGroup(nc, TC_P);
                if (lib == 1) { score = score + capBonus; }
                else if (lib == 2) { score = score + cap2; }
            } else if (_board[nc] == TC_AI) {
                lib = _checkGroup(nc, TC_AI);
                if (lib == 1) { score = score + defBonus; }
                else if (lib == 2) { score = score + def2; }
            }
        }
        if (cy > 0) {
            var nc = ci - TC_N;
            if (_board[nc] == TC_P) {
                lib = _checkGroup(nc, TC_P);
                if (lib == 1) { score = score + capBonus; }
                else if (lib == 2) { score = score + cap2; }
            } else if (_board[nc] == TC_AI) {
                lib = _checkGroup(nc, TC_AI);
                if (lib == 1) { score = score + defBonus; }
                else if (lib == 2) { score = score + def2; }
            }
        }
        if (cy < TC_N - 1) {
            var nc = ci + TC_N;
            if (_board[nc] == TC_P) {
                lib = _checkGroup(nc, TC_P);
                if (lib == 1) { score = score + capBonus; }
                else if (lib == 2) { score = score + cap2; }
            } else if (_board[nc] == TC_AI) {
                lib = _checkGroup(nc, TC_AI);
                if (lib == 1) { score = score + defBonus; }
                else if (lib == 2) { score = score + def2; }
            }
        }

        // Influence: count AI vs player stones within Manhattan distance ≤ 2
        var infW = hard ? 6 : 3;
        var ownN = 0; var oppN = 0;
        // Distance 1
        if (cx > 0)             { var v = _board[ci - 1];    if (v == TC_AI) { ownN++; } else if (v == TC_P) { oppN++; } }
        if (cx < TC_N - 1)      { var v = _board[ci + 1];    if (v == TC_AI) { ownN++; } else if (v == TC_P) { oppN++; } }
        if (cy > 0)             { var v = _board[ci - TC_N]; if (v == TC_AI) { ownN++; } else if (v == TC_P) { oppN++; } }
        if (cy < TC_N - 1)      { var v = _board[ci + TC_N]; if (v == TC_AI) { ownN++; } else if (v == TC_P) { oppN++; } }
        // Distance 2 — orthogonal
        if (cx > 1)             { var v = _board[ci - 2];        if (v == TC_AI) { ownN++; } else if (v == TC_P) { oppN++; } }
        if (cx < TC_N - 2)      { var v = _board[ci + 2];        if (v == TC_AI) { ownN++; } else if (v == TC_P) { oppN++; } }
        if (cy > 1)             { var v = _board[ci - TC_N * 2]; if (v == TC_AI) { ownN++; } else if (v == TC_P) { oppN++; } }
        if (cy < TC_N - 2)      { var v = _board[ci + TC_N * 2]; if (v == TC_AI) { ownN++; } else if (v == TC_P) { oppN++; } }
        // Distance 2 — diagonal
        if (cx > 0 && cy > 0)             { var v = _board[ci - TC_N - 1]; if (v == TC_AI) { ownN++; } else if (v == TC_P) { oppN++; } }
        if (cx < TC_N-1 && cy > 0)        { var v = _board[ci - TC_N + 1]; if (v == TC_AI) { ownN++; } else if (v == TC_P) { oppN++; } }
        if (cx > 0 && cy < TC_N - 1)      { var v = _board[ci + TC_N - 1]; if (v == TC_AI) { ownN++; } else if (v == TC_P) { oppN++; } }
        if (cx < TC_N-1 && cy < TC_N - 1) { var v = _board[ci + TC_N + 1]; if (v == TC_AI) { ownN++; } else if (v == TC_P) { oppN++; } }
        score = score + (ownN - oppN) * infW;

        // Territory claim: bonus when 2+ orthogonal neighbours are own stones
        var adjOwn = 0;
        if (cx > 0        && _board[ci - 1]    == TC_AI) { adjOwn = adjOwn + 1; }
        if (cx < TC_N - 1 && _board[ci + 1]    == TC_AI) { adjOwn = adjOwn + 1; }
        if (cy > 0        && _board[ci - TC_N] == TC_AI) { adjOwn = adjOwn + 1; }
        if (cy < TC_N - 1 && _board[ci + TC_N] == TC_AI) { adjOwn = adjOwn + 1; }
        if (adjOwn >= 2) { score = score + adjOwn * 5; }

        // Hard: penalise edge / corner moves to prefer interior play
        if (hard) {
            if (cx == 0 || cx == TC_N - 1 || cy == 0 || cy == TC_N - 1) {
                score = score - 10;
            }
        }

        score = score + Math.rand() % 7;
        if (_diff == DIFF_EASY) { return score / 2 + Math.rand() % 25; }
        return score;
    }

    hidden function _aiDoTurn() {
        // Phase 1: find best-scored empty cell
        var bestScore = -999; var bestMove = -1;
        var i = 0;
        while (i < TC_CELLS) {
            if (_board[i] == TC_EMP) {
                var s = _aiEval(i);
                if (s > bestScore) { bestScore = s; bestMove = i; }
            }
            i++;
        }
        // Phase 2: play it; fall back to first legal move if it fails (suicide)
        var played = -1;
        if (bestMove >= 0 && _placeStone(bestMove, TC_AI)) {
            played = bestMove;
        }
        if (played < 0) {
            i = 0;
            while (i < TC_CELLS && played < 0) {
                if (_board[i] == TC_EMP && _placeStone(i, TC_AI)) { played = i; }
                i++;
            }
        }
        if (played >= 0) {
            _lastMove  = played;
            _passCount = 0;
            _checkWin();
        } else {
            _passCount = _passCount + 1;
        }
        if (_passCount >= 2) { _endGame(); return; }
        if (_state != TC_OVER) { _state = TC_PLAY; }
    }

    // ── Rendering ─────────────────────────────────────────────────────────
    function onUpdate(dc) {
        if (_state == GS_MENU) { _drawMenu(dc); return; }
        dc.setColor(0x0A180A, 0x0A180A);
        dc.clear();
        _drawBoard(dc);
        _drawStones(dc);
        if (_state == TC_PLAY || (_state == TC_AIST && _mode == MODE_PVP)) { _drawCursor(dc); }
        _drawUI(dc);
        if (_state == TC_OVER) {
            _drawTerritory(dc);
            _drawOver(dc);
        }
    }

    // ── Board (wood-coloured background + grid) ───────────────────────────
    hidden function _drawBoard(dc) {
        var bw  = _step * (TC_N - 1);
        var pad = _stoneR + 3;
        // Wood background
        dc.setColor(0xC8904C, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(_boardX - pad, _boardY - pad, bw + pad * 2, bw + pad * 2, 5);
        // Grid lines
        dc.setColor(0x7A4510, Graphics.COLOR_TRANSPARENT);
        var i = 0;
        while (i < TC_N) {
            var px = _boardX + i * _step;
            var py = _boardY + i * _step;
            dc.drawLine(px, _boardY, px, _boardY + bw);
            dc.drawLine(_boardX, py, _boardX + bw, py);
            i++;
        }
        // Star points: tengen (4,4) + four corner stars (2,2)(2,6)(6,2)(6,6)
        var sr = _stoneR / 5 + 1;
        dc.setColor(0x7A4510, Graphics.COLOR_TRANSPARENT);
        _drawStar(dc, 2, 2, sr);
        _drawStar(dc, 6, 2, sr);
        _drawStar(dc, 4, 4, sr);
        _drawStar(dc, 2, 6, sr);
        _drawStar(dc, 6, 6, sr);
    }

    hidden function _drawStar(dc, gx, gy, r) {
        dc.fillCircle(_boardX + gx * _step, _boardY + gy * _step, r);
    }

    // ── Stones ────────────────────────────────────────────────────────────
    hidden function _drawStones(dc) {
        var i = 0;
        while (i < TC_CELLS) {
            if (_board[i] != TC_EMP) {
                var px = _boardX + (i % TC_N) * _step;
                var py = _boardY + (i / TC_N) * _step;
                if (_board[i] == TC_P) {
                    dc.setColor(0x1A1A1A, Graphics.COLOR_TRANSPARENT);
                    dc.fillCircle(px, py, _stoneR);
                    // Subtle gloss highlight
                    dc.setColor(0x404040, Graphics.COLOR_TRANSPARENT);
                    dc.fillCircle(px - _stoneR / 3, py - _stoneR / 3, _stoneR / 4);
                } else {
                    dc.setColor(0xEEEEEE, Graphics.COLOR_TRANSPARENT);
                    dc.fillCircle(px, py, _stoneR);
                    dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT);
                    dc.drawCircle(px, py, _stoneR);
                    // Shadow
                    dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
                    dc.fillCircle(px + _stoneR / 4, py + _stoneR / 4, _stoneR / 4);
                }
                // Last-move dot
                if (i == _lastMove) {
                    var dotC = (_board[i] == TC_P) ? 0xFFFFFF : 0x111111;
                    dc.setColor(dotC, Graphics.COLOR_TRANSPARENT);
                    dc.fillCircle(px, py, _stoneR / 4);
                }
            }
            i++;
        }
    }

    // ── Cursor ring ───────────────────────────────────────────────────────
    hidden function _drawCursor(dc) {
        var px = _boardX + _curX * _step;
        var py = _boardY + _curY * _step;
        var ci = _curY * TC_N + _curX;
        if (_board[ci] == TC_EMP) {
            dc.setColor(0xFF8800, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(px, py, _stoneR);
            dc.drawCircle(px, py, _stoneR - 1);
        } else {
            dc.setColor(0xFF2200, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(px, py, _stoneR + 2);
        }
    }

    // ── Territory markers (end game only) ─────────────────────────────────
    hidden function _drawTerritory(dc) {
        var sq = _stoneR / 2;
        if (sq < 2) { sq = 2; }
        var i = 0;
        while (i < TC_CELLS) {
            if (_terr[i] != TC_EMP) {
                var px = _boardX + (i % TC_N) * _step;
                var py = _boardY + (i / TC_N) * _step;
                dc.setColor((_terr[i] == TC_P) ? 0x1A1A1A : 0xEEEEEE,
                            Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(px - sq, py - sq, sq * 2, sq * 2);
            }
            i++;
        }
    }

    // ── Status strips ─────────────────────────────────────────────────────
    hidden function _drawUI(dc) {
        // Top strip — AI info
        dc.setColor(0x050D05, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, _sw, 28);
        dc.setColor(0xBBBBBB, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_sw / 2, 2, Graphics.FONT_XTINY,
                    ((_mode == MODE_PVP) ? "P2(W)" : "AI(W)") + "  cap:" + _captAI.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x2299FF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_sw - 4, 2, Graphics.FONT_XTINY, "W:" + _sAI.format("%d"),
                    Graphics.TEXT_JUSTIFY_RIGHT);

        // Bottom strip — player info
        dc.setColor(0x050D05, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _sh - 28, _sw, 28);
        dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
        var btxt = ((_mode == MODE_PVP) ? "P1(B)" : "You(B)") + "  cap:" + _captP.format("%d");
        if (_state == TC_PLAY || (_state == TC_AIST && _mode == MODE_PVP)) { btxt = btxt + "  BACK=pass"; }
        dc.drawText(_sw / 2, _sh - 16, Graphics.FONT_XTINY, btxt,
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFF3300, Graphics.COLOR_TRANSPARENT);
        dc.drawText(4, _sh - 16, Graphics.FONT_XTINY, "W:" + _sP.format("%d"),
                    Graphics.TEXT_JUSTIFY_LEFT);

        // Pass counter hint
        if (_passCount == 1 && _state == TC_AIST) {
            dc.setColor(0xFF8800, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_sw / 2, 14, Graphics.FONT_XTINY, "1 pass",
                        Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── Pre-game menu ─────────────────────────────────────────────────────
    hidden function _drawMenu(dc) {
        dc.setColor(0x050D05, 0x050D05); dc.clear();
        var hw = _sw / 2;
        dc.setColor(0x0A180A, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(hw, hw, hw - 1);
        dc.setColor(0x44BB44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(hw, _sh * 8 / 100, Graphics.FONT_XTINY, "TERRITORY CLASH", Graphics.TEXT_JUSTIFY_CENTER);
        var modeStr = (_mode == MODE_PVAI) ? "P vs AI" : ((_mode == MODE_PVP) ? "P vs P" : "AI vs AI");
        var diffStr = (_diff == DIFF_EASY) ? "Easy" : ((_diff == DIFF_MED) ? "Med" : "Hard");
        var sideStr = _playerFirst ? "Side: Blk" : "Side: Wht";
        var rows = ["Mode: " + modeStr, "Diff: " + diffStr, sideStr, "START"];
        var nR = 4;
        var rowH = _sh * 13 / 100; if (rowH < 23) { rowH = 23; } if (rowH > 36) { rowH = 36; }
        var rowW = _sw * 70 / 100; var rowX = (_sw - rowW) / 2;
        var gap = 5; var tot = nR * rowH + (nR - 1) * gap; var rowY0 = (_sh - tot) / 2 + rowH;
        var i = 0;
        while (i < nR) {
            var ry = rowY0 + i * (rowH + gap); var sel = (i == _menuSel); var isStart = (i == nR - 1);
            dc.setColor(sel ? (isStart ? 0x0A2A0A : 0x0A2040) : 0x050D05, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(rowX, ry, rowW, rowH, 5);
            dc.setColor(sel ? (isStart ? 0x44BB44 : 0x4499FF) : 0x1A2A1A, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(rowX, ry, rowW, rowH, 5);
            if (sel) {
                dc.setColor(isStart ? 0x44BB44 : 0x4499FF, Graphics.COLOR_TRANSPARENT);
                var ay = ry + rowH / 2;
                dc.fillPolygon([[rowX + 5, ay - 4], [rowX + 5, ay + 4], [rowX + 11, ay]]);
            }
            var dimmed = (i == 1 && _mode == MODE_PVP) || (i == 2 && _mode != MODE_PVAI);
            dc.setColor(dimmed ? 0x445566 : (sel ? (isStart ? 0xAAFFAA : 0xAADDFF) : 0x556677), Graphics.COLOR_TRANSPARENT);
            dc.drawText(hw, ry + (rowH - 14) / 2, Graphics.FONT_XTINY, rows[i], Graphics.TEXT_JUSTIFY_CENTER);
            i++;
        }
        dc.setColor(0x334455, Graphics.COLOR_TRANSPARENT);
        dc.drawText(hw, _sh - 14, Graphics.FONT_XTINY, "UP/DN sel  SELECT set/start", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── AIvAI helper: place a stone as a given color using heuristic ──────
    hidden function _aiPlaceAs(color) {
        var opp = (color == TC_P) ? TC_AI : TC_P;
        var bestScore = -999; var bestMove = -1;
        var i = 0;
        while (i < TC_CELLS) {
            if (_board[i] == TC_EMP) {
                var cx = i % TC_N; var cy = i / TC_N; var mid = TC_N / 2;
                var dx = cx > mid ? cx - mid : mid - cx;
                var dy = cy > mid ? cy - mid : mid - cy;
                var score = 18 - (dx + dy) * 2 + Math.rand() % 7;
                if (cx > 0)        { if (_board[i - 1]    == opp && _checkGroup(i - 1,    opp) == 1) { score = score + 30; } }
                if (cx < TC_N - 1) { if (_board[i + 1]    == opp && _checkGroup(i + 1,    opp) == 1) { score = score + 30; } }
                if (cy > 0)        { if (_board[i - TC_N] == opp && _checkGroup(i - TC_N, opp) == 1) { score = score + 30; } }
                if (cy < TC_N - 1) { if (_board[i + TC_N] == opp && _checkGroup(i + TC_N, opp) == 1) { score = score + 30; } }
                if (score > bestScore) { bestScore = score; bestMove = i; }
            }
            i++;
        }
        if (bestMove >= 0 && _placeStone(bestMove, color)) {
            _lastMove = bestMove; _passCount = 0; _checkWin();
        } else { _passCount = _passCount + 1; }
        if (_passCount >= 2) { _endGame(); return; }
        if (_state != TC_OVER) { _state = TC_AIST; }
    }

    // ── Game-over overlay ─────────────────────────────────────────────────
    hidden function _drawOver(dc) {
        var bw = _sw * 62 / 100; var bh = _sh * 36 / 100;
        if (bw < 160) { bw = 160; }
        if (bh < 100) { bh = 100; }
        var ox = _sw / 2 - bw / 2; var oy = _sh / 2 - bh / 2;
        dc.setColor(0x060810, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(ox, oy, bw, bh, 10);
        dc.setColor(0x334433, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(ox, oy, bw, bh, 10);
        var cx = _sw / 2;
        var msg = ""; var mc = 0xCCCCCC;
        if      (_scoreP  > _scoreAI) { msg = (_mode == MODE_PVP) ? "P1 WIN!" : "YOU WIN!";  mc = 0xFF2200; }
        else if (_scoreAI > _scoreP)  { msg = (_mode == MODE_PVP) ? "P2 WIN!" : "AI WINS!";  mc = 0x2299FF; }
        else                          { msg = "DRAW!";      mc = 0xFFAA00; }
        dc.setColor(mc, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, oy + 6, Graphics.FONT_SMALL, msg, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x88BB88, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, oy + 36, Graphics.FONT_XTINY,
                    ((_mode == MODE_PVP) ? "P1(B):" : "B(you):") + _scoreP.format("%d") +
                    ((_mode == MODE_PVP) ? "  P2(W):" : "  W(ai):") + _scoreAI.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x556655, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, oy + 54, Graphics.FONT_XTINY,
                    "terr + captures",
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x2A442A, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, oy + bh - 14, Graphics.FONT_XTINY,
                    "SELECT = new game", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
