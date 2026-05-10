using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.Math;

// ── Nine Men's Morris — board constants ──────────────────────────────────
// 24 nodes arranged as 3 concentric squares with midpoint cross-lines.
//
// Grid coordinates (x=col, y=row, 0-6):
//   Outer square corners:   0(0,0) 2(6,0) 21(0,6) 23(6,6)
//   Outer square midpoints: 1(3,0) 9(0,3) 14(6,3) 22(3,6)
//   Middle corners:  3(1,1) 5(5,1) 18(1,5) 20(5,5)
//   Middle midpts:   4(3,1) 10(1,3) 13(5,3) 19(3,5)
//   Inner corners:   6(2,2) 8(4,2) 15(2,4) 17(4,4)
//   Inner midpts:    7(3,2) 11(2,3) 12(4,3) 16(3,4)

const MN        = 24;
const MC_EMPTY  = 0;
const MC_PLAYER = 1;    // human — Red
const MC_AI     = 2;    // computer — Blue

const MF_PLACE  = 0;    // hand > 0
const MF_MOVE   = 1;    // hand = 0, board > 3
const MF_FLY    = 2;    // hand = 0, board = 3

const MGS_P_SEL = 0;    // player selects node (place or pick piece)
const MGS_P_DST = 1;    // player chose a piece, picking destination
const MGS_P_REM = 2;    // player formed mill, must remove an AI piece
const MGS_AI    = 3;    // AI thinking (timer-fired)
const MGS_AI_RM = 4;    // brief hold after AI removes player piece
const MGS_OVER  = 5;

const MOV_PWIN  = 1;
const MOV_AIWIN = 2;

const MGS_P2_REM = 6;   // PvP: player 2 formed mill, must remove a P1 piece

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
    hidden var _bx, _by;   // board top-left pixel
    hidden var _step;      // pixels per grid unit  (board_size / 6)
    hidden var _nr;        // node circle radius

    // ── Board data — pre-allocated once, never reallocated ────────────────
    hidden var _nodes;     // int[24]  MC_EMPTY / MC_PLAYER / MC_AI
    hidden var _adj;       // int[96]  24 × 4 neighbours (−1 = no slot)
    hidden var _mills;     // int[48]  16 × 3 mill triplets
    hidden var _nav;       // int[96]  24 × 4  UP/DOWN/LEFT/RIGHT (−1 = none)
    hidden var _gx, _gy;   // int[24]  grid x, y (0–6) for each node
    hidden var _edges;     // int[64]  32 × 2 node-pair lines to draw

    // ── Piece counts ──────────────────────────────────────────────────────
    hidden var _pH, _pB;   // player: hand (unplaced), board
    hidden var _aH, _aB;   // AI:     hand, board

    // ── Cursor & selection ────────────────────────────────────────────────
    hidden var _cur;       // cursor node index 0–23
    hidden var _sel;       // selected piece during P_DST  (−1 = none)
    hidden var _millN;     // node that just completed a mill (−1 = none)

    // ── Game flow ─────────────────────────────────────────────────────────
    hidden var _state;
    hidden var _overType;

    // ── Session score ─────────────────────────────────────────────────────
    hidden var _sP, _sAI;

    // ── Pre-game menu ─────────────────────────────────────────────────────
    hidden var _mode;
    hidden var _diff;
    hidden var _menuSel;
    hidden var _playerFirst;

    // ── PvP player-2 selection ────────────────────────────────────────────
    hidden var _p2Sel;

    // ── Timer ─────────────────────────────────────────────────────────────
    hidden var _timer;

    // ─────────────────────────────────────────────────────────────────────
    function initialize() {
        View.initialize();
        _nodes = new [MN];
        _adj   = new [MN * 4];
        _mills = new [16 * 3];
        _nav   = new [MN * 4];
        _gx    = new [MN];
        _gy    = new [MN];
        _edges = new [32 * 2];
        _sP      = 0;
        _sAI     = 0;
        _timer   = null;
        _mode    = MODE_PVAI;
        _diff    = DIFF_MED;
        _menuSel = 0;
        _playerFirst = true;
        _p2Sel   = -1;
        _initTables();
        _startGame();
        _state   = GS_MENU;
    }

    // ── Static tables (called once in initialize) ─────────────────────────
    hidden function _initTables() {
        // Grid positions (gx, gy) 0-6 per axis
        _gx[0]=0;_gy[0]=0; _gx[1]=3;_gy[1]=0; _gx[2]=6;_gy[2]=0;
        _gx[3]=1;_gy[3]=1; _gx[4]=3;_gy[4]=1; _gx[5]=5;_gy[5]=1;
        _gx[6]=2;_gy[6]=2; _gx[7]=3;_gy[7]=2; _gx[8]=4;_gy[8]=2;
        _gx[9]=0;_gy[9]=3; _gx[10]=1;_gy[10]=3; _gx[11]=2;_gy[11]=3;
        _gx[12]=4;_gy[12]=3; _gx[13]=5;_gy[13]=3; _gx[14]=6;_gy[14]=3;
        _gx[15]=2;_gy[15]=4; _gx[16]=3;_gy[16]=4; _gx[17]=4;_gy[17]=4;
        _gx[18]=1;_gy[18]=5; _gx[19]=3;_gy[19]=5; _gx[20]=5;_gy[20]=5;
        _gx[21]=0;_gy[21]=6; _gx[22]=3;_gy[22]=6; _gx[23]=6;_gy[23]=6;

        // Adjacency — up to 4 neighbours per node (−1 = unused slot)
        _a(0,  1,  9, -1, -1); _a(1,  0,  2,  4, -1); _a(2,  1, 14, -1, -1);
        _a(3,  4, 10, -1, -1); _a(4,  1,  3,  5,  7); _a(5,  4, 13, -1, -1);
        _a(6,  7, 11, -1, -1); _a(7,  4,  6,  8, 16); _a(8,  7, 12, -1, -1);
        _a(9,  0, 10, 21, -1); _a(10, 3,  9, 11, 18); _a(11, 6, 10, 15, -1);
        _a(12, 8, 13, 17, -1); _a(13, 5, 12, 14, 20); _a(14, 2, 13, 23, -1);
        _a(15,11, 16, -1, -1); _a(16, 7, 15, 17, 19); _a(17,12, 16, -1, -1);
        _a(18,10, 19, -1, -1); _a(19,16, 18, 20, 22); _a(20,13, 19, -1, -1);
        _a(21, 9, 22, -1, -1); _a(22,19, 21, 23, -1); _a(23,14, 22, -1, -1);

        // Mills — 8 horizontal rows + 8 vertical columns = 16 total
        _m(0,  0,  1,  2); _m(1,  3,  4,  5); _m(2,  6,  7,  8);
        _m(3,  9, 10, 11); _m(4, 12, 13, 14); _m(5, 15, 16, 17);
        _m(6, 18, 19, 20); _m(7, 21, 22, 23);
        _m(8,  0,  9, 21); _m(9,  3, 10, 18); _m(10, 6, 11, 15);
        _m(11, 1,  4,  7); _m(12,16, 19, 22); _m(13, 8, 12, 17);
        _m(14, 5, 13, 20); _m(15, 2, 14, 23);

        // Navigation — UP / DOWN / LEFT / RIGHT (−1 = no connection)
        _n(0,  -1,  9, -1,  1); _n(1,  -1,  4,  0,  2); _n(2,  -1, 14,  1, -1);
        _n(3,  -1, 10, -1,  4); _n(4,   1,  7,  3,  5); _n(5,  -1, 13,  4, -1);
        _n(6,  -1, 11, -1,  7); _n(7,   4, 16,  6,  8); _n(8,  -1, 12,  7, -1);
        _n(9,   0, 21, -1, 10); _n(10,  3, 18,  9, 11); _n(11,  6, 15, 10, -1);
        _n(12,  8, 17, -1, 13); _n(13,  5, 20, 12, 14); _n(14,  2, 23, 13, -1);
        _n(15, 11, -1, -1, 16); _n(16,  7, 19, 15, 17); _n(17, 12, -1, 16, -1);
        _n(18, 10, -1, -1, 19); _n(19, 16, 22, 18, 20); _n(20, 13, -1, 19, -1);
        _n(21,  9, -1, -1, 22); _n(22, 19, -1, 21, 23); _n(23, 14, -1, 22, -1);

        // Edges (32 pairs) — outer / middle / inner squares + 4 cross spurs
        _e(0,0,1);  _e(1,1,2);   _e(2,2,14);   _e(3,14,23);
        _e(4,23,22);_e(5,22,21); _e(6,21,9);   _e(7,9,0);
        _e(8,3,4);  _e(9,4,5);   _e(10,5,13);  _e(11,13,20);
        _e(12,20,19);_e(13,19,18);_e(14,18,10);_e(15,10,3);
        _e(16,6,7); _e(17,7,8);  _e(18,8,12);  _e(19,12,17);
        _e(20,17,16);_e(21,16,15);_e(22,15,11);_e(23,11,6);
        _e(24,1,4); _e(25,4,7);
        _e(26,14,13);_e(27,13,12);
        _e(28,22,19);_e(29,19,16);
        _e(30,9,10);_e(31,10,11);
    }

    hidden function _a(i,n0,n1,n2,n3) {
        _adj[i*4]=n0; _adj[i*4+1]=n1; _adj[i*4+2]=n2; _adj[i*4+3]=n3;
    }
    hidden function _m(m,a,b,c) {
        _mills[m*3]=a; _mills[m*3+1]=b; _mills[m*3+2]=c;
    }
    hidden function _n(i,up,dn,lt,rt) {
        _nav[i*4]=up; _nav[i*4+1]=dn; _nav[i*4+2]=lt; _nav[i*4+3]=rt;
    }
    hidden function _e(e,a,b) {
        _edges[e*2]=a; _edges[e*2+1]=b;
    }

    // ── Layout ────────────────────────────────────────────────────────────
    function onLayout(dc) {
        _sw = dc.getWidth();
        _sh = dc.getHeight();
        // Board fills 70 % of screen width — outer corners stay inside round 454-px screen
        var bsz = _sw * 62 / 100;
        _step   = bsz / 6;
        _bx     = (_sw - bsz) / 2;
        _by     = (_sh - bsz) / 2;
        if (_by < 24) { _by = 24; }
        _nr = _step * 31 / 100;
        if (_nr < 7) { _nr = 7; }
        _timer = new Timer.Timer();
        _timer.start(method(:gameTick), 450, true);
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); }
    }

    // ── Public input API ──────────────────────────────────────────────────
    // dir: 0=retreat (prev node)  1=advance (next node)
    // Menu: 0 → prev item, 1 → next item
    function navigate(dir) {
        if (_state == GS_MENU) {
            if (dir == 0 || dir == 2) { _menuSel = (_menuSel + 3) % 4; }
            else if (dir == 1 || dir == 3) { _menuSel = (_menuSel + 1) % 4; }
            WatchUi.requestUpdate();
            return;
        }
        if (_state == MGS_OVER) { return; }
        // Block navigation in AI states unless PvP (where MGS_AI = P2 select, MGS_AI_RM = P2 dest)
        if ((_state == MGS_AI || _state == MGS_AI_RM) && _mode != MODE_PVP) { return; }
        // AIAI: no manual input during player states
        if (_mode == MODE_AIAI) { return; }
        if (dir == 0) {
            _cur = (_cur + MN - 1) % MN;
        } else if (dir == 1) {
            _cur = (_cur + 1) % MN;
        }
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
        if (_state == MGS_OVER) { _state = GS_MENU; _menuSel = 0; WatchUi.requestUpdate(); return; }
        if (_mode == MODE_AIAI) { return; }
        // PvP: MGS_AI = P2 selecting, MGS_AI_RM = P2 picking destination
        if (_state == MGS_AI    && _mode == MODE_PVP) { _p2Select(); return; }
        if (_state == MGS_AI_RM && _mode == MODE_PVP) { _p2Dest();   return; }
        if (_state == MGS_P2_REM)                     { _p2Remove(); return; }
        if (_state == MGS_AI || _state == MGS_AI_RM) { return; }
        if (_state == MGS_P_SEL) { _playerSelect(); }
        else if (_state == MGS_P_DST) { _playerDest(); }
        else if (_state == MGS_P_REM) { _playerRemove(); }
    }

    // ── 450 ms timer tick ─────────────────────────────────────────────────
    function gameTick() {
        if (_mode == MODE_PVP) { return; }
        if (_state == MGS_AI) {
            _doAiTurn();
            WatchUi.requestUpdate();
        } else if (_state == MGS_AI_RM) {
            _state = MGS_P_SEL;
            WatchUi.requestUpdate();
        } else if (_mode == MODE_AIAI &&
                   (_state == MGS_P_SEL || _state == MGS_P_DST || _state == MGS_P_REM)) {
            // AIAI: player-side AI handles MC_PLAYER's turn
            _doPlayerAiTurn();
            WatchUi.requestUpdate();
        }
    }

    // ── Game reset ────────────────────────────────────────────────────────
    hidden function _startGame() {
        var i = 0;
        while (i < MN) { _nodes[i] = MC_EMPTY; i = i + 1; }
        _pH = 9; _pB = 0;
        _aH = 9; _aB = 0;
        _cur      = 4;
        _sel      = -1;
        _p2Sel    = -1;
        _millN    = -1;
        _overType = 0;
        if (_mode == MODE_AIAI) {
            _state = MGS_AI;
        } else if (_mode == MODE_PVAI && !_playerFirst) {
            _state = MGS_AI;
        } else {
            _state = MGS_P_SEL;
        }
    }

    // ── Phase helpers ─────────────────────────────────────────────────────
    hidden function _pPhase() {
        if (_pH > 0) { return MF_PLACE; }
        if (_pB == 3) { return MF_FLY; }
        return MF_MOVE;
    }
    hidden function _aPhase() {
        if (_aH > 0) { return MF_PLACE; }
        if (_aB == 3) { return MF_FLY; }
        return MF_MOVE;
    }

    // ── Mill detection ────────────────────────────────────────────────────
    // True if node n is part of a complete 3-in-a-row of colour col.
    hidden function _inMill(n, col) {
        if (col == MC_EMPTY) { return false; }
        var m = 0;
        while (m < 16) {
            var a = _mills[m*3]; var b = _mills[m*3+1]; var c = _mills[m*3+2];
            if ((a == n || b == n || c == n) &&
                _nodes[a] == col && _nodes[b] == col && _nodes[c] == col) {
                return true;
            }
            m = m + 1;
        }
        return false;
    }

    // True if placing col at empty node n would complete a mill.
    // Temporarily modifies _nodes[n] then restores — only call on empty nodes.
    hidden function _wouldMill(n, col) {
        _nodes[n] = col;
        var r = _inMill(n, col);
        _nodes[n] = MC_EMPTY;
        return r;
    }

    // True if nodes a and b are adjacent.
    hidden function _adjNodes(a, b) {
        var j = 0;
        while (j < 4) { if (_adj[a*4+j] == b) { return true; } j = j + 1; }
        return false;
    }

    // Penalty for lifting piece of color col from src (called with _nodes[src] already
    // set to MC_EMPTY). Penalises breaking own mills/near-mills and exposing opponent
    // near-mills that src was blocking.
    hidden function _scoreDepartFor(src, col, opp) {
        var penalty = 0;
        var m = 0;
        while (m < 16) {
            var a = _mills[m*3]; var b = _mills[m*3+1]; var c = _mills[m*3+2];
            if (a == src || b == src || c == src) {
                var colCnt = 0; var oppCnt = 0;
                var x = 0;
                while (x < 3) {
                    var nd = _mills[m*3+x];
                    if (nd != src) {
                        if (_nodes[nd] == col) { colCnt = colCnt + 1; }
                        if (_nodes[nd] == opp) { oppCnt = oppCnt + 1; }
                    }
                    x = x + 1;
                }
                if (colCnt == 2) { penalty = penalty - 80; }  // was breaking complete mill
                if (colCnt == 1) { penalty = penalty - 20; }  // was breaking near-mill
                if (oppCnt == 2) { penalty = penalty - 50; }  // was blocking opp near-mill
            }
            m = m + 1;
        }
        return penalty;
    }

    // Score for removing a piece of color col at node n (higher = better to remove).
    // Prefers pieces involved in near-mills or complete mills of col.
    hidden function _removeThreatFor(n, col) {
        var sc = 0;
        var m = 0;
        while (m < 16) {
            var a = _mills[m*3]; var b = _mills[m*3+1]; var c = _mills[m*3+2];
            if (a == n || b == n || c == n) {
                var colCnt = 0;
                var x = 0;
                while (x < 3) {
                    if (_nodes[_mills[m*3+x]] == col) { colCnt = colCnt + 1; }
                    x = x + 1;
                }
                if (colCnt == 3) { sc = sc + 100; }
                else if (colCnt == 2) { sc = sc + 50; }
                else if (colCnt == 1) { sc = sc + 10; }
            }
            m = m + 1;
        }
        var dx = _gx[n] - 3; if (dx < 0) { dx = -dx; }
        var dy = _gy[n] - 3; if (dy < 0) { dy = -dy; }
        sc = sc + (6 - dx - dy);
        if (_diff != DIFF_HARD) { sc = sc + Math.rand() % 5; }
        return sc;
    }

    // True if col has at least one legal adjacent-slide move.
    hidden function _hasMove(col) {
        var i = 0;
        while (i < MN) {
            if (_nodes[i] == col) {
                var j = 0;
                while (j < 4) {
                    var nb = _adj[i*4+j];
                    if (nb >= 0 && _nodes[nb] == MC_EMPTY) { return true; }
                    j = j + 1;
                }
            }
            i = i + 1;
        }
        return false;
    }

    // ── Win conditions ────────────────────────────────────────────────────
    // Called after player removes an AI piece.
    hidden function _checkAiLoss() {
        if (_aH > 0) { return; }      // placing phase — pieces in hand still safe
        if (_aB < 3) {
            _overType = MOV_PWIN; _sP = _sP + 1; _state = MGS_OVER;
        } else if (_aPhase() == MF_MOVE && !_hasMove(MC_AI)) {
            _overType = MOV_PWIN; _sP = _sP + 1; _state = MGS_OVER;
        }
    }

    // Called after AI places/moves or removes a player piece.
    hidden function _checkPlayerLoss() {
        if (_pH > 0) { return; }
        if (_pB < 3) {
            _overType = MOV_AIWIN; _sAI = _sAI + 1; _state = MGS_OVER;
        } else if (_pPhase() == MF_MOVE && !_hasMove(MC_PLAYER)) {
            _overType = MOV_AIWIN; _sAI = _sAI + 1; _state = MGS_OVER;
        }
    }

    // ── Player: placing / selecting ───────────────────────────────────────
    hidden function _playerSelect() {
        var ph = _pPhase();
        if (ph == MF_PLACE) {
            if (_nodes[_cur] != MC_EMPTY) { return; }
            _nodes[_cur] = MC_PLAYER;
            _pH = _pH - 1; _pB = _pB + 1;
            if (_inMill(_cur, MC_PLAYER)) {
                _millN = _cur;
                if (_aB > 0) { _state = MGS_P_REM; } else { _state = MGS_AI; }
            } else {
                _state = MGS_AI;
            }
        } else {
            if (_nodes[_cur] != MC_PLAYER) { return; }
            _sel   = _cur;
            _state = MGS_P_DST;
        }
    }

    // ── Player: choosing destination ──────────────────────────────────────
    hidden function _playerDest() {
        if (_cur == _sel) {
            _sel = -1; _state = MGS_P_SEL; return;
        }
        if (_nodes[_cur] == MC_PLAYER) {
            _sel = _cur; return;   // re-select different own piece
        }
        if (_nodes[_cur] != MC_EMPTY) { return; }
        var ph = _pPhase();
        var ok = (ph == MF_FLY) ? true : _adjNodes(_sel, _cur);
        if (!ok) { return; }
        _nodes[_sel] = MC_EMPTY;
        _nodes[_cur] = MC_PLAYER;
        _sel = -1;
        if (_inMill(_cur, MC_PLAYER)) {
            _millN = _cur;
            if (_aB > 0) { _state = MGS_P_REM; }
            else { _checkAiLoss(); if (_state != MGS_OVER) { _state = MGS_AI; } }
        } else {
            _checkAiLoss();
            if (_state != MGS_OVER) { _state = MGS_AI; }
        }
    }

    // ── Player: removing an AI piece ──────────────────────────────────────
    hidden function _playerRemove() {
        if (_nodes[_cur] != MC_AI) { return; }
        // Cannot remove a mill piece unless ALL AI pieces are in mills
        var anyFree = false;
        var i = 0;
        while (i < MN) {
            if (_nodes[i] == MC_AI && !_inMill(i, MC_AI)) { anyFree = true; }
            i = i + 1;
        }
        if (anyFree && _inMill(_cur, MC_AI)) { return; }
        _nodes[_cur] = MC_EMPTY;
        _aB = _aB - 1;
        _millN = -1;
        _checkAiLoss();
        if (_state != MGS_OVER) { _state = MGS_AI; }
    }

    // ── AI: top-level dispatch ────────────────────────────────────────────
    hidden function _doAiTurn() {
        var ph = _aPhase();
        if (ph == MF_MOVE && !_hasMove(MC_AI)) {
            _overType = MOV_PWIN; _sP = _sP + 1; _state = MGS_OVER; return;
        }
        if (ph == MF_PLACE) { _aiPlace(); }
        else                { _aiMove(ph == MF_FLY); }
    }

    // Generic placement score for colour col against opp at empty node n.
    // Hard: high weights + double-mill detection to compensate for no 2-ply.
    hidden function _aiScoreFor(n, col, opp) {
        var hard = (_diff == DIFF_HARD);
        if (_wouldMill(n, col)) { return hard ? 2000 : 1000; }
        if (_wouldMill(n, opp)) { return hard ?  900 :  500; }
        var pot = 0; var millsOpen = 0;
        var m = 0;
        while (m < 16) {
            var a = _mills[m*3]; var b = _mills[m*3+1]; var c = _mills[m*3+2];
            if (a == n || b == n || c == n) {
                var colCnt = 0; var oppCnt = 0;
                var x = 0;
                while (x < 3) {
                    var nd = _mills[m*3+x];
                    if (_nodes[nd] == col) { colCnt = colCnt + 1; }
                    if (_nodes[nd] == opp) { oppCnt = oppCnt + 1; }
                    x = x + 1;
                }
                if (oppCnt == 0) {
                    var w = hard ? 18 : 12;
                    pot = pot + colCnt * w;
                    millsOpen = millsOpen + 1;
                }
            }
            m = m + 1;
        }
        // Hard: bonus for nodes that open two mills simultaneously (fork setup)
        if (hard && millsOpen >= 2) { pot = pot + 80; }
        var dx = _gx[n] - 3; if (dx < 0) { dx = -dx; }
        var dy = _gy[n] - 3; if (dy < 0) { dy = -dy; }
        var noise = (_diff == DIFF_EASY) ? 40 : (hard ? 1 : 5);
        return pot + (6 - dx - dy) * 2 + Math.rand() % noise;
    }

    // Score for AI placing at empty node n (assumes _nodes[n] == MC_EMPTY).
    // Higher = better for AI.
    hidden function _aiScore(n) {
        return _aiScoreFor(n, MC_AI, MC_PLAYER);
    }

    // ── AI: placing phase ─────────────────────────────────────────────────
    // Pure 1-ply scoring — fast enough on all devices (24 × ~48 ops ≈ 1 150).
    // Hard difficulty is distinguished by near-zero noise in _aiScoreFor.
    hidden function _aiPlace() {
        var best = -99999; var pick = -1;
        var i = 0;
        while (i < MN) {
            if (_nodes[i] == MC_EMPTY) {
                var sc = _aiScore(i);
                if (sc > best) { best = sc; pick = i; }
            }
            i = i + 1;
        }
        if (pick < 0) { _state = MGS_P_SEL; return; }
        _nodes[pick] = MC_AI;
        _aH = _aH - 1; _aB = _aB + 1;
        if (_inMill(pick, MC_AI)) { _millN = pick; _aiRemove(); }
        else { _checkPlayerLoss(); if (_state != MGS_OVER) { _state = MGS_P_SEL; } }
    }

    // ── AI: moving / flying phase ─────────────────────────────────────────
    hidden function _aiMove(fly) {
        var best = -99999; var fromN = -1; var toN = -1;
        var i = 0;
        while (i < MN) {
            if (_nodes[i] == MC_AI) {
                _nodes[i] = MC_EMPTY;   // temporarily lift piece
                var depart = _scoreDepartFor(i, MC_AI, MC_PLAYER);
                var j = 0;
                while (j < (fly ? MN : 4)) {
                    var nb = fly ? j : _adj[i*4+j];
                    if (nb < 0 || nb == i || _nodes[nb] != MC_EMPTY) { j = j + 1; continue; }
                    var sc = _aiScore(nb) + depart;
                    if (sc > best) { best = sc; fromN = i; toN = nb; }
                    j = j + 1;
                }
                _nodes[i] = MC_AI;      // restore
            }
            i = i + 1;
        }
        if (fromN < 0) {
            _overType = MOV_PWIN; _sP = _sP + 1; _state = MGS_OVER; return;
        }
        _nodes[fromN] = MC_EMPTY;
        _nodes[toN]   = MC_AI;
        if (_inMill(toN, MC_AI)) { _millN = toN; _aiRemove(); }
        else { _checkPlayerLoss(); if (_state != MGS_OVER) { _state = MGS_P_SEL; } }
    }

    // ── AI: removing a player piece after forming a mill ──────────────────
    hidden function _aiRemove() {
        // Prefer pieces not in a mill; if all are milled, take any.
        var anyFree = false;
        var i = 0;
        while (i < MN) {
            if (_nodes[i] == MC_PLAYER && !_inMill(i, MC_PLAYER)) { anyFree = true; }
            i = i + 1;
        }
        // Pick the most dangerous free piece (highest mill-threat score).
        var pick = -1; var bestSc = -9999;
        i = 0;
        while (i < MN) {
            if (_nodes[i] == MC_PLAYER) {
                var takeable = anyFree ? !_inMill(i, MC_PLAYER) : true;
                if (takeable) {
                    var sc = _removeThreatFor(i, MC_PLAYER);
                    if (sc > bestSc) { bestSc = sc; pick = i; }
                }
            }
            i = i + 1;
        }
        if (pick >= 0) { _nodes[pick] = MC_EMPTY; _pB = _pB - 1; }
        _millN = -1;
        _checkPlayerLoss();
        if (_state != MGS_OVER) { _state = MGS_AI_RM; }
    }

    // ── PvP: player-2 (MC_AI colour) actions ─────────────────────────────
    // State MGS_AI  = P2 selecting a piece or placing during hand phase.
    // State MGS_AI_RM = P2 has selected, now picking destination.
    hidden function _p2Select() {
        var ph = _aPhase();
        if (ph == MF_PLACE) {
            if (_nodes[_cur] != MC_EMPTY) { return; }
            _nodes[_cur] = MC_AI;
            _aH = _aH - 1; _aB = _aB + 1;
            if (_inMill(_cur, MC_AI)) {
                _millN = _cur;
                if (_pB > 0) { _state = MGS_P2_REM; } else { _checkPlayerLoss(); if (_state != MGS_OVER) { _state = MGS_P_SEL; } }
            } else {
                _checkPlayerLoss();
                if (_state != MGS_OVER) { _state = MGS_P_SEL; }
            }
        } else {
            if (_nodes[_cur] != MC_AI) { return; }
            _p2Sel = _cur;
            _state = MGS_AI_RM;
        }
    }

    hidden function _p2Dest() {
        if (_p2Sel < 0) { _state = MGS_AI; return; }
        if (_cur == _p2Sel) { _p2Sel = -1; _state = MGS_AI; return; }
        if (_nodes[_cur] == MC_AI) { _p2Sel = _cur; return; }
        if (_nodes[_cur] != MC_EMPTY) { return; }
        var ph = _aPhase();
        var ok = (ph == MF_FLY) ? true : _adjNodes(_p2Sel, _cur);
        if (!ok) { return; }
        _nodes[_p2Sel] = MC_EMPTY;
        _nodes[_cur]   = MC_AI;
        _p2Sel = -1;
        if (_inMill(_cur, MC_AI)) {
            _millN = _cur;
            if (_pB > 0) { _state = MGS_P2_REM; }
            else { _checkPlayerLoss(); if (_state != MGS_OVER) { _state = MGS_P_SEL; } }
        } else {
            _checkPlayerLoss();
            if (_state != MGS_OVER) { _state = MGS_P_SEL; }
        }
    }

    hidden function _p2Remove() {
        if (_nodes[_cur] != MC_PLAYER) { return; }
        var anyFree = false;
        var i = 0;
        while (i < MN) {
            if (_nodes[i] == MC_PLAYER && !_inMill(i, MC_PLAYER)) { anyFree = true; }
            i = i + 1;
        }
        if (anyFree && _inMill(_cur, MC_PLAYER)) { return; }
        _nodes[_cur] = MC_EMPTY;
        _pB = _pB - 1;
        _millN = -1;
        _checkPlayerLoss();
        if (_state != MGS_OVER) { _state = MGS_P_SEL; }
    }

    // ── AIAI: player-side AI (mirrors _doAiTurn but for MC_PLAYER) ────────
    hidden function _doPlayerAiTurn() {
        if (_state == MGS_P_REM) { _aiRemoveP(); return; }
        var ph = _pPhase();
        if (ph == MF_MOVE && !_hasMove(MC_PLAYER)) {
            _overType = MOV_AIWIN; _sAI = _sAI + 1; _state = MGS_OVER; return;
        }
        if (ph == MF_PLACE) { _aiPlaceP(); }
        else                { _aiMoveP(ph == MF_FLY); }
    }

    hidden function _aiPlaceP() {
        var best = -99999; var pick = -1;
        var i = 0;
        while (i < MN) {
            if (_nodes[i] == MC_EMPTY) {
                var sc = _aiScoreFor(i, MC_PLAYER, MC_AI);
                if (sc > best) { best = sc; pick = i; }
            }
            i = i + 1;
        }
        if (pick < 0) { _state = MGS_AI; return; }
        _nodes[pick] = MC_PLAYER;
        _pH = _pH - 1; _pB = _pB + 1;
        if (_inMill(pick, MC_PLAYER)) { _millN = pick; _aiRemoveP(); }
        else { _checkAiLoss(); if (_state != MGS_OVER) { _state = MGS_AI; } }
    }

    hidden function _aiMoveP(fly) {
        var best = -99999; var fromN = -1; var toN = -1;
        var i = 0;
        while (i < MN) {
            if (_nodes[i] == MC_PLAYER) {
                _nodes[i] = MC_EMPTY;
                var depart = _scoreDepartFor(i, MC_PLAYER, MC_AI);
                var j = 0;
                while (j < (fly ? MN : 4)) {
                    var nb = fly ? j : _adj[i*4+j];
                    if (nb < 0 || nb == i || _nodes[nb] != MC_EMPTY) { j = j + 1; continue; }
                    var sc = _aiScoreFor(nb, MC_PLAYER, MC_AI) + depart;
                    if (sc > best) { best = sc; fromN = i; toN = nb; }
                    j = j + 1;
                }
                _nodes[i] = MC_PLAYER;
            }
            i = i + 1;
        }
        if (fromN < 0) { _overType = MOV_AIWIN; _sAI = _sAI + 1; _state = MGS_OVER; return; }
        _nodes[fromN] = MC_EMPTY;
        _nodes[toN]   = MC_PLAYER;
        if (_inMill(toN, MC_PLAYER)) { _millN = toN; _aiRemoveP(); }
        else { _checkAiLoss(); if (_state != MGS_OVER) { _state = MGS_AI; } }
    }

    hidden function _aiRemoveP() {
        var anyFree = false;
        var i = 0;
        while (i < MN) {
            if (_nodes[i] == MC_AI && !_inMill(i, MC_AI)) { anyFree = true; }
            i = i + 1;
        }
        var pick = -1; var bestSc = -9999;
        i = 0;
        while (i < MN) {
            if (_nodes[i] == MC_AI) {
                var takeable = anyFree ? !_inMill(i, MC_AI) : true;
                if (takeable) {
                    var sc = _removeThreatFor(i, MC_AI);
                    if (sc > bestSc) { bestSc = sc; pick = i; }
                }
            }
            i = i + 1;
        }
        if (pick >= 0) { _nodes[pick] = MC_EMPTY; _aB = _aB - 1; }
        _millN = -1;
        _checkAiLoss();
        if (_state != MGS_OVER) { _state = MGS_AI; }
    }

    // ── Rendering ─────────────────────────────────────────────────────────
    function onUpdate(dc) {
        if (_state == GS_MENU) { _drawMenu(dc); return; }
        dc.setColor(0x06060E, 0x06060E);
        dc.clear();
        _drawBoard(dc);
        _drawNodes(dc);
        _drawCursor(dc);
        _drawHUD(dc);
        if (_state == MGS_OVER) { _drawOver(dc); }
    }

    hidden function _nx(i) { return _bx + _gx[i] * _step; }
    hidden function _ny(i) { return _by + _gy[i] * _step; }

    // ── Board lines ───────────────────────────────────────────────────────
    hidden function _drawBoard(dc) {
        dc.setColor(0x282840, Graphics.COLOR_TRANSPARENT);
        var e = 0;
        while (e < 32) {
            var a = _edges[e*2]; var b = _edges[e*2+1];
            dc.drawLine(_nx(a), _ny(a), _nx(b), _ny(b));
            e = e + 1;
        }
    }

    // ── Nodes, highlights ─────────────────────────────────────────────────
    hidden function _drawNodes(dc) {
        var i = 0;
        while (i < MN) {
            var px = _nx(i); var py = _ny(i);
            var v  = _nodes[i];
            if (v == MC_PLAYER) {
                // Mill pieces glow brighter orange-red
                dc.setColor(_inMill(i, MC_PLAYER) ? 0xFF5500 : 0xFF2200,
                            Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(px, py, _nr);
            } else if (v == MC_AI) {
                dc.setColor(_inMill(i, MC_AI) ? 0x33CCFF : 0x0099FF,
                            Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(px, py, _nr);
            } else {
                dc.setColor(0x181828, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(px, py, _nr - 2);
                dc.setColor(0x34344E, Graphics.COLOR_TRANSPARENT);
                dc.drawCircle(px, py, _nr - 2);
            }
            i = i + 1;
        }

        // Valid-destination rings (green) when player is choosing a move
        if (_state == MGS_P_DST && _sel >= 0) {
            var ph = _pPhase();
            i = 0;
            while (i < MN) {
                if (_nodes[i] == MC_EMPTY) {
                    var ok = (ph == MF_FLY) ? true : _adjNodes(_sel, i);
                    if (ok) {
                        dc.setColor(0x44CC44, Graphics.COLOR_TRANSPARENT);
                        dc.drawCircle(_nx(i), _ny(i), _nr + 2);
                    }
                }
                i = i + 1;
            }
            // Selected-piece double ring (orange)
            dc.setColor(0xFF8800, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(_nx(_sel), _ny(_sel), _nr + 3);
            dc.drawCircle(_nx(_sel), _ny(_sel), _nr + 4);
        }

        // PvP: P2 destination rings
        if (_state == MGS_AI_RM && _mode == MODE_PVP && _p2Sel >= 0) {
            var ph2 = _aPhase();
            i = 0;
            while (i < MN) {
                if (_nodes[i] == MC_EMPTY) {
                    var ok2 = (ph2 == MF_FLY) ? true : _adjNodes(_p2Sel, i);
                    if (ok2) {
                        dc.setColor(0x44CC44, Graphics.COLOR_TRANSPARENT);
                        dc.drawCircle(_nx(i), _ny(i), _nr + 2);
                    }
                }
                i = i + 1;
            }
            dc.setColor(0xFF8800, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(_nx(_p2Sel), _ny(_p2Sel), _nr + 3);
            dc.drawCircle(_nx(_p2Sel), _ny(_p2Sel), _nr + 4);
        }

        // Removable-AI rings (yellow) during player remove phase
        if (_state == MGS_P_REM) {
            var anyFree = false;
            i = 0;
            while (i < MN) {
                if (_nodes[i] == MC_AI && !_inMill(i, MC_AI)) { anyFree = true; }
                i = i + 1;
            }
            i = 0;
            while (i < MN) {
                if (_nodes[i] == MC_AI) {
                    var takeable = anyFree ? !_inMill(i, MC_AI) : true;
                    if (takeable) {
                        dc.setColor(0xFFDD00, Graphics.COLOR_TRANSPARENT);
                        dc.drawCircle(_nx(i), _ny(i), _nr + 2);
                    }
                }
                i = i + 1;
            }
        }

        // Removable-P1 rings (yellow) during P2 remove phase (PvP)
        if (_state == MGS_P2_REM) {
            var anyFreeP = false;
            i = 0;
            while (i < MN) {
                if (_nodes[i] == MC_PLAYER && !_inMill(i, MC_PLAYER)) { anyFreeP = true; }
                i = i + 1;
            }
            i = 0;
            while (i < MN) {
                if (_nodes[i] == MC_PLAYER) {
                    var tkP = anyFreeP ? !_inMill(i, MC_PLAYER) : true;
                    if (tkP) {
                        dc.setColor(0xFFDD00, Graphics.COLOR_TRANSPARENT);
                        dc.drawCircle(_nx(i), _ny(i), _nr + 2);
                    }
                }
                i = i + 1;
            }
        }
    }

    // ── Cursor ────────────────────────────────────────────────────────────
    hidden function _drawCursor(dc) {
        if (_state == MGS_OVER) { return; }
        if ((_state == MGS_AI || _state == MGS_AI_RM) && _mode != MODE_PVP) { return; }
        var px = _nx(_cur); var py = _ny(_cur);
        var col = 0xFFFF00;
        if (_state == MGS_P_REM) {
            col = (_nodes[_cur] == MC_AI) ? 0xFF4400 : 0x333348;
        } else if (_state == MGS_P2_REM) {
            col = (_nodes[_cur] == MC_PLAYER) ? 0xFF4400 : 0x333348;
        } else if (_state == MGS_P_DST && _nodes[_cur] == MC_PLAYER && _cur != _sel) {
            col = 0xFFAA00;
        } else if (_state == MGS_AI_RM && _mode == MODE_PVP && _nodes[_cur] == MC_AI && _cur != _p2Sel) {
            col = 0xFFAA00;
        }
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(px, py, _nr + 2);
        dc.drawCircle(px, py, _nr + 3);
    }

    // ── HUD ───────────────────────────────────────────────────────────────
    hidden function _drawHUD(dc) {
        var ty = _sh * 2 / 100;
        if (ty < 4) { ty = 4; }

        // Session scores (labels depend on mode)
        var lbl1 = (_mode == MODE_PVP) ? "P1 " : "YOU ";
        var lbl2 = (_mode == MODE_PVP) ? " P2" : " AI";
        dc.setColor(0xFF2200, Graphics.COLOR_TRANSPARENT);
        dc.drawText(8, ty, Graphics.FONT_XTINY,
                    lbl1 + _sP.format("%d"), Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(0x0099FF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_sw - 8, ty, Graphics.FONT_XTINY,
                    _sAI.format("%d") + lbl2, Graphics.TEXT_JUSTIFY_RIGHT);

        // Piece-in-hand counts (shown during placing phase)
        var hy = ty + 14;
        if (_pH > 0) {
            dc.setColor(0xFF4422, Graphics.COLOR_TRANSPARENT);
            dc.drawText(8, hy, Graphics.FONT_XTINY,
                        "H:" + _pH.format("%d"), Graphics.TEXT_JUSTIFY_LEFT);
        }
        if (_aH > 0) {
            dc.setColor(0x2299FF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_sw - 8, hy, Graphics.FONT_XTINY,
                        _aH.format("%d") + ":H", Graphics.TEXT_JUSTIFY_RIGHT);
        }

        // Centre status text
        var txt = ""; var tcol = 0xCCCCCC;
        if (_state == MGS_P_SEL) {
            var ph = _pPhase();
            if (ph == MF_PLACE)     { txt = "PLACE"; tcol = 0x44FF44; }
            else if (ph == MF_MOVE) { txt = "MOVE";  tcol = 0x44FF44; }
            else                    { txt = "FLY";   tcol = 0x44FFCC; }
        } else if (_state == MGS_P_DST) { txt = "DEST";  tcol = 0xFF8800; }
        else if (_state == MGS_P_REM)   { txt = "TAKE!"; tcol = 0xFFDD00; }
        else if (_state == MGS_P2_REM)  { txt = "P2 TAKE!"; tcol = 0xFFDD00; }
        else if (_state == MGS_AI || _state == MGS_AI_RM) {
            if (_mode == MODE_PVP) {
                txt = (_state == MGS_AI) ? "P2 SEL" : "P2 DEST"; tcol = 0x44FF44;
            } else {
                txt = "AI..."; tcol = 0x444455;
            }
        }
        if (txt.length() > 0) {
            dc.setColor(tcol, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_sw / 2, ty, Graphics.FONT_XTINY, txt, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Board counts below the board (only if space allows)
        var botY = _by + 6 * _step + _nr + 6;
        if (botY < _sh - 16) {
            dc.setColor(0xFF2200, Graphics.COLOR_TRANSPARENT);
            dc.drawText(8, botY, Graphics.FONT_XTINY,
                        "B:" + _pB.format("%d"), Graphics.TEXT_JUSTIFY_LEFT);
            dc.setColor(0x0099FF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_sw - 8, botY, Graphics.FONT_XTINY,
                        _aB.format("%d") + ":B", Graphics.TEXT_JUSTIFY_RIGHT);
        }
    }

    // ── Pre-game menu ─────────────────────────────────────────────────────
    hidden function _drawMenu(dc) {
        dc.setColor(0x080810, 0x080810); dc.clear();
        var hw = _sw / 2;
        dc.setColor(0x0A0A18, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(hw, hw, hw - 1);
        dc.setColor(0xFF6622, Graphics.COLOR_TRANSPARENT);
        dc.drawText(hw, _sh * 11 / 100, Graphics.FONT_SMALL, "MORRIS", Graphics.TEXT_JUSTIFY_CENTER);
        var modeStr = (_mode == MODE_PVAI) ? "P vs AI" : ((_mode == MODE_PVP) ? "P vs P" : "AI vs AI");
        var diffStr = (_diff == DIFF_EASY) ? "Easy" : ((_diff == DIFF_MED) ? "Med" : "Hard");
        var sideStr = _playerFirst ? "Side: Dk" : "Side: Lt";
        var rows = ["Mode: " + modeStr, "Diff: " + diffStr, sideStr, "START"];
        var nR = 4;
        var rowH = _sh * 10 / 100; if (rowH < 22) { rowH = 22; } if (rowH > 30) { rowH = 30; }
        var rowW = _sw * 74 / 100;
        var rowX = (_sw - rowW) / 2;
        var gap  = 6;
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
    hidden function _drawOver(dc) {
        var bw = _sw * 56 / 100; var bh = _sh * 30 / 100;
        if (bw < 150) { bw = 150; }
        if (bh < 90)  { bh = 90; }
        var ox = _sw / 2 - bw / 2;
        var oy = _sh / 2 - bh / 2;
        dc.setColor(0x040408, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(ox, oy, bw, bh, 10);
        dc.setColor(0x3A3A5A, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(ox, oy, bw, bh, 10);

        var cx = _sw / 2;
        var msg = ""; var mc = 0xCCCCCC;
        if (_overType == MOV_PWIN) { msg = "YOU WIN!"; mc = 0xFF2200; }
        else                       { msg = "AI WINS!"; mc = 0x0099FF; }
        dc.setColor(mc, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, oy + 8, Graphics.FONT_SMALL, msg, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x555566, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, oy + 38, Graphics.FONT_XTINY,
                    "YOU " + _sP.format("%d") + " : " + _sAI.format("%d") + " AI",
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x2A2A44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, oy + bh - 14, Graphics.FONT_XTINY,
                    "SELECT = new game", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
