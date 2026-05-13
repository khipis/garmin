using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.Math;

// ── Gobblet Mini ──────────────────────────────────────────────────────────
//
// 4 × 4 grid.  Each player starts with 12 pieces: 3 of each of 4 sizes.
// A larger piece gobbles (covers) any smaller piece on any board cell.
// Win: 4 in a row of the same owner's TOP-VISIBLE pieces.
//
// Piece value encoding (flat int, 1–8, 0 = empty slot):
//   v = (owner − 1) × GSIZES + size
//   Player: size 1 → v=1 … size 4 → v=4
//   AI:     size 1 → v=5 … size 4 → v=8
//
// Stack layout: _stack[cell * GSIZES + depth]
//   depth 0 = bottom piece (oldest / smallest), depth-1 = top (visible)
//   _depth[cell] = number of pieces currently stacked

const GM     = 4;    // grid side
const GM2    = 16;   // grid area
const GSIZES = 4;    // piece sizes (1 = smallest … 4 = largest)
const GHAND  = 3;    // pieces per size per player at game start

// Game states
const GMS_P_SEL  = 0;  // player selects a source (hand or own board piece)
const GMS_P_SIZE = 1;  // player picks which hand size to use (overlay)
const GMS_P_DST  = 2;  // player picks destination cell
const GMS_AI     = 3;  // AI turn (timer-driven)
const GMS_OVER   = 4;

const GOM_PWIN  = 1;
const GOM_AIWIN = 2;

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
    hidden var _gx, _gy;     // board top-left pixel
    hidden var _csz;         // cell pixel size

    // ── Board — all pre-allocated in initialize(), zero runtime alloc ─────
    //
    // _stack[64]: flat [cell * GSIZES + d], piece value 1-8 or 0
    // _depth[16]: stack depth per cell (0 = empty)
    // _ph[4]:     player hand count per size-index (0 = size-1)
    // _aih[4]:    AI hand count per size-index
    // _lines[40]: 10 win-check lines × 4 cell indices each
    hidden var _stack;
    hidden var _depth;
    hidden var _ph;
    hidden var _aih;
    hidden var _lines;

    // ── Piece radii — precomputed in onLayout ──────────────────────────────
    hidden var _psz;    // int[4]: board piece radii (index = size−1)
    hidden var _hpsz;   // int[4]: hand-strip icon radii

    // ── Game state ────────────────────────────────────────────────────────
    hidden var _state;
    hidden var _gridCur;   // 0–15: highlighted grid cell
    hidden var _selFrom;   // 0=from hand  1=from board  −1=nothing selected
    hidden var _selSize;   // 1–4: size of piece in transit (valid when selFrom≥0)
    hidden var _selCell;   // board source cell index (valid when selFrom==1)
    hidden var _sizePick;  // 1–4: highlighted size in the size-picker overlay

    // ── Session ───────────────────────────────────────────────────────────
    hidden var _overWho;
    hidden var _sP, _sAI;

    // ── Timer ─────────────────────────────────────────────────────────────
    hidden var _timer;
    hidden var _mode;
    hidden var _diff;
    hidden var _menuSel;
    hidden var _playerFirst;
    hidden var _activePlayer;   // 1 = P1 / human, 2 = AI / P2

    // ─────────────────────────────────────────────────────────────────────
    function initialize() {
        View.initialize();
        _stack = new [GM2 * GSIZES];
        _depth = new [GM2];
        _ph    = new [GSIZES];
        _aih   = new [GSIZES];
        _lines = new [10 * GM];
        _psz   = new [GSIZES];
        _hpsz  = new [GSIZES];
        _sP    = 0;
        _sAI   = 0;
        _timer = null;
        _mode    = MODE_PVAI;
        _diff    = DIFF_MED;
        _menuSel = 0;
        _playerFirst = true;
        _activePlayer = 1;
        _initLines();
        _startGame();
        _state = GS_MENU;
    }

    function onLayout(dc) {
        _sw = dc.getWidth();
        _sh = dc.getHeight();

        // Hand icon radii — must be computed first (used in _gy calculation below)
        var hr = _sh * 3 / 100;
        if (hr > 10) { hr = 10; }
        if (hr < 3)  { hr = 3; }
        _hpsz[0] = hr * 25 / 100; if (_hpsz[0] < 2) { _hpsz[0] = 2; }
        _hpsz[1] = hr * 50 / 100; if (_hpsz[1] < 2) { _hpsz[1] = 2; }
        _hpsz[2] = hr * 75 / 100; if (_hpsz[2] < 3) { _hpsz[2] = 3; }
        _hpsz[3] = hr;

        // Space reserved above and below the board:
        //   above: 16px HUD text + hand-strip radius + 3px gap
        //   below: hand-strip radius + 4px gap + 14px count-text
        var topR = 16 + hr + 3;
        var botR = hr + 4 + 14;

        // Cell size: fit board vertically in remaining space; shrunk 15% for watch fit
        var maxH = (_sh - topR - botR) * 85 / 100 / GM;
        var maxW = _sw * 72 / 100 / GM;   // 85% × 85% ≈ 72%
        _csz = (maxH < maxW) ? maxH : maxW;
        if (_csz < 10) { _csz = 10; }

        var bsz = _csz * GM;

        // Centre horizontally
        _gx = (_sw - bsz) / 2;

        // Centre vertically — board centred in the strip-to-strip space
        _gy = (_sh - bsz) / 2;
        if (_gy < topR)              { _gy = topR; }              // clamp top
        if (_gy + bsz + botR > _sh) { _gy = _sh - bsz - botR; } // clamp bottom

        // Board piece radii: 22 / 40 / 58 / 76 % of half-cell
        var hc = _csz / 2;
        _psz[0] = hc * 22 / 100; if (_psz[0] < 2) { _psz[0] = 2; }
        _psz[1] = hc * 40 / 100; if (_psz[1] < 4) { _psz[1] = 4; }
        _psz[2] = hc * 58 / 100; if (_psz[2] < 6) { _psz[2] = 6; }
        _psz[3] = hc * 76 / 100; if (_psz[3] < 8) { _psz[3] = 8; }

        _timer = new Timer.Timer();
        _timer.start(method(:gameTick), 500, true);
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); }
    }

    // ── Public input API ──────────────────────────────────────────────────
    // dir: 0=KEY_UP   → row up   (wrapping)
    //      1=KEY_DOWN → row down (wrapping)
    //      2=onPreviousPage → col RIGHT (wrapping)
    //      3=onNextPage     → row DOWN  (wrapping)
    function navigate(dir) {
        if (_state == GS_MENU) {
            if (dir == 0 || dir == 2) { _menuSel = (_menuSel + 3) % 4; }
            else if (dir == 1 || dir == 3) { _menuSel = (_menuSel + 1) % 4; }
            WatchUi.requestUpdate();
            return;
        }
        if (_state == GMS_AI || _state == GMS_OVER) { return; }
        if (_state == GMS_P_SIZE) {
            // size picker: left/right cycles available sizes
            if      (dir == 2) { _sizePickStep(-1); }
            else if (dir == 3) { _sizePickStep(1); }
            return;
        }
        var r = _gridCur / GM; var c = _gridCur % GM;
        if      (dir == 0) { _gridCur = ((r + GM - 1) % GM) * GM + c; }  // up wrap
        else if (dir == 1) { _gridCur = ((r + 1)      % GM) * GM + c; }  // down wrap
        else if (dir == 2) { _gridCur = r * GM + (c + 1) % GM; }          // right wrap
        else if (dir == 3) { _gridCur = ((r + 1)      % GM) * GM + c; }  // down wrap
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
        if (_state == GMS_OVER)   { _state = GS_MENU; _menuSel = 0; WatchUi.requestUpdate(); return; }
        if (_state == GMS_AI)     { return; }
        if (_state == GMS_P_SIZE) { _confirmSizePick(); return; }
        if (_state == GMS_P_SEL)  { _doSelect(); }
        else if (_state == GMS_P_DST) { _doDest(); }
    }

    // Returns false → delegate should popView; true → handled internally
    function doBack() {
        if (_state == GMS_P_SIZE || _state == GMS_P_DST) {
            _state = GMS_P_SEL; _selFrom = -1;
            return true;
        }
        if (_state == GS_MENU) { return false; }
        _state = GS_MENU; _menuSel = 0;
        return true;
    }

    // ── Timer tick — AI turn ──────────────────────────────────────────────
    function gameTick() as Void {
        if (_mode == MODE_PVP) { WatchUi.requestUpdate(); return; }
        if (_state == GMS_AI) {
            _aiDoMoveFor(2);
            if (_checkWin(2)) {
                _overWho = GOM_AIWIN; _sAI = _sAI + 1; _state = GMS_OVER;
            } else if (_checkWin(1)) {
                _overWho = GOM_PWIN; _sP = _sP + 1; _state = GMS_OVER;
            } else {
                _state = GMS_P_SEL; _activePlayer = 1;
            }
            WatchUi.requestUpdate();
        } else if (_mode == MODE_AIAI && _state == GMS_P_SEL) {
            _aiDoMoveFor(1);
            if (_checkWin(1)) {
                _overWho = GOM_PWIN; _sP = _sP + 1; _state = GMS_OVER;
            } else if (_checkWin(2)) {
                _overWho = GOM_AIWIN; _sAI = _sAI + 1; _state = GMS_OVER;
            } else {
                _state = GMS_AI;
            }
            WatchUi.requestUpdate();
        }
    }

    // ── Game management ───────────────────────────────────────────────────
    hidden function _startGame() {
        var i = 0;
        while (i < GM2 * GSIZES) { _stack[i] = 0; i = i + 1; }
        i = 0;
        while (i < GM2) { _depth[i] = 0; i = i + 1; }
        i = 0;
        while (i < GSIZES) { _ph[i] = GHAND; _aih[i] = GHAND; i = i + 1; }
        _gridCur  = 0;
        _selFrom  = -1;
        _selSize  = 0;
        _selCell  = -1;
        _sizePick = 1;
        _overWho  = 0;
        _activePlayer = 1;
        if (_mode == MODE_AIAI) {
            _state = GMS_AI;
        } else if (_mode == MODE_PVAI && !_playerFirst) {
            _state = GMS_AI;
        } else {
            _state = GMS_P_SEL;
        }
    }

    // 10 win-check lines: 4 rows, 4 columns, 2 diagonals
    hidden function _initLines() {
        var r = 0;
        while (r < GM) {
            _lines[r * GM]     = r * GM;
            _lines[r * GM + 1] = r * GM + 1;
            _lines[r * GM + 2] = r * GM + 2;
            _lines[r * GM + 3] = r * GM + 3;
            r = r + 1;
        }
        var c = 0;
        while (c < GM) {
            var base = (GM + c) * GM;
            _lines[base]     = c;
            _lines[base + 1] = c + GM;
            _lines[base + 2] = c + 2 * GM;
            _lines[base + 3] = c + 3 * GM;
            c = c + 1;
        }
        // Main diagonal: 0,5,10,15
        _lines[32] = 0;  _lines[33] = 5;  _lines[34] = 10; _lines[35] = 15;
        // Anti-diagonal: 3,6,9,12
        _lines[36] = 3;  _lines[37] = 6;  _lines[38] = 9;  _lines[39] = 12;
    }

    // ── Board primitives ──────────────────────────────────────────────────
    // Top piece value at cell (0 if empty).
    hidden function _topOf(cell) {
        if (_depth[cell] == 0) { return 0; }
        return _stack[cell * GSIZES + _depth[cell] - 1];
    }

    // Size of top piece at cell (0 if empty).
    hidden function _topSize(cell) {
        var v = _topOf(cell); if (v == 0) { return 0; }
        return (v - 1) % GSIZES + 1;
    }

    // Owner of top piece at cell (0=none  1=player  2=AI).
    hidden function _topOwner(cell) {
        var v = _topOf(cell); if (v == 0) { return 0; }
        return (v - 1) / GSIZES + 1;
    }

    // Encode a piece as a single int value.
    hidden function _makeVal(owner, size) { return (owner - 1) * GSIZES + size; }

    // Can a piece of 'size' be placed at 'dst' (empty or smaller top)?
    hidden function _canPlace(size, dst) {
        return (_depth[dst] == 0) || (size > _topSize(dst));
    }

    // Push piece value onto cell's stack.
    hidden function _place(val, cell) {
        _stack[cell * GSIZES + _depth[cell]] = val;
        _depth[cell] = _depth[cell] + 1;
    }

    // Pop and return the top piece value from cell's stack.
    // The piece beneath is automatically revealed (stack semantics).
    hidden function _pop(cell) {
        _depth[cell] = _depth[cell] - 1;
        var v = _stack[cell * GSIZES + _depth[cell]];
        _stack[cell * GSIZES + _depth[cell]] = 0;
        return v;
    }

    // ── Player actions ────────────────────────────────────────────────────
    hidden function _doSelect() {
        var cell = _gridCur;
        if (_topOwner(cell) == _activePlayer) {
            // Pick up own board piece → go straight to destination selection
            _selFrom = 1;
            _selSize = _topSize(cell);
            _selCell = cell;
            _state   = GMS_P_DST;
        } else {
            // Try to pick from hand → open size-picker overlay
            var firstSz = _firstValidHandSize(cell);
            if (firstSz > 0) {
                _sizePick = firstSz;
                _state    = GMS_P_SIZE;
            }
            // else: no hand piece can go here; ignore input
        }
    }

    // Smallest hand size ≥1 that is available AND can be placed at dst.
    hidden function _firstValidHandSize(dst) {
        var hand = (_activePlayer == 1) ? _ph : _aih;
        var s = 1;
        while (s <= GSIZES) {
            if (hand[s - 1] > 0 && _canPlace(s, dst)) { return s; }
            s = s + 1;
        }
        return 0;
    }

    // Advance _sizePick by delta (±1), skipping unavailable/invalid sizes.
    hidden function _sizePickStep(delta) {
        var hand = (_activePlayer == 1) ? _ph : _aih;
        var s = _sizePick + delta;
        while (s >= 1 && s <= GSIZES) {
            if (hand[s - 1] > 0 && _canPlace(s, _gridCur)) {
                _sizePick = s; return;
            }
            s = s + delta;
        }
    }

    // Confirm the size-picker selection and move to destination phase.
    hidden function _confirmSizePick() {
        _selFrom = 0;
        _selSize = _sizePick;
        _state   = GMS_P_DST;
    }

    // Player commits to placing/moving at the current grid cursor.
    hidden function _doDest() {
        var dst = _gridCur;
        if (_selFrom == 1) {
            // Moving a board piece
            if (dst == _selCell) { _state = GMS_P_SEL; _selFrom = -1; return; }
            if (!_canPlace(_selSize, dst)) { return; }
            var val = _pop(_selCell);
            _place(val, dst);
        } else {
            // Placing a new piece from hand
            if (!_canPlace(_selSize, dst)) { return; }
            var hand = (_activePlayer == 1) ? _ph : _aih;
            hand[_selSize - 1] = hand[_selSize - 1] - 1;
            _place(_makeVal(_activePlayer, _selSize), dst);
        }
        _selFrom = -1;
        if (_checkWin(1)) {
            _overWho = GOM_PWIN; _sP = _sP + 1; _state = GMS_OVER;
        } else if (_checkWin(2)) {
            _overWho = GOM_AIWIN; _sAI = _sAI + 1; _state = GMS_OVER;
        } else if (_mode == MODE_PVP) {
            _activePlayer = (_activePlayer == 1) ? 2 : 1;
            _state = GMS_P_SEL;
        } else {
            _state = GMS_AI;
        }
    }

    // ── Win check ─────────────────────────────────────────────────────────
    // Returns true if 'who' owns all 4 top pieces of any win line.
    hidden function _checkWin(who) {
        var l = 0;
        while (l < 10) {
            var cnt = 0; var i = 0;
            while (i < GM) {
                if (_topOwner(_lines[l * GM + i]) == who) { cnt = cnt + 1; }
                i = i + 1;
            }
            if (cnt == GM) { return true; }
            l = l + 1;
        }
        return false;
    }

    // Check one win line by index (l = 0..9).
    hidden function _checkLine(who, l) {
        var cnt = 0; var i = 0; var base = l * GM;
        while (i < GM) {
            if (_topOwner(_lines[base + i]) == who) { cnt = cnt + 1; }
            i = i + 1;
        }
        return cnt == GM;
    }

    // Fast win check: only tests lines passing through 'dst' (2-4 lines).
    // Requires _cells[dst] already set to the new piece before calling.
    // Lines layout: rows 0-3, cols 4-7, main-diag 8, anti-diag 9.
    hidden function _checkWinAt(who, dst) {
        var r = dst / GM; var c = dst % GM;
        if (_checkLine(who, r))              { return true; }
        if (_checkLine(who, GM + c))         { return true; }
        if (r == c && _checkLine(who, 8))           { return true; }
        if (r + c == GM - 1 && _checkLine(who, 9)) { return true; }
        return false;
    }

    // Fast win check for Phase B (board moves): board changed at 'a' and 'b'.
    hidden function _checkWinAt2(who, a, b) {
        return _checkWinAt(who, a) || _checkWinAt(who, b);
    }

    // ── AI ────────────────────────────────────────────────────────────────
    //
    // Strategy (one-ply lookahead):
    //   1. Win immediately if any move creates 4-in-a-row for AI.
    //   2. Block enemy threat (via pre-computed mask).
    //   3. Score positions by AI line progress minus player threat weight.
    //
    // NOTE: _checkWinAt(enemy, dst) is OMITTED from Phase A — after placing our
    //   piece at dst, _topOwner(dst)==who so the enemy can never win through dst.
    //   Removing it saves ~72 ops × 64 candidates = ~4 600 ops.
    //
    // Watchdog budget:
    //   _enemyThreatMask  : ~5 600 ops  (once per turn)
    //   Phase A (≤64):     ~120 ops/cand × 64  = ~7 680 ops
    //   Phase B (budget=32): ~350 ops/cand × 32 = ~11 200 ops
    //   Total ≈ 24 480 ops — safe on all devices.

    // Score a single win-line for 'who' vs 'enemy'.
    hidden function _aiScoreLine(who, enemy, l) {
        var aCnt = 0; var pCnt = 0; var i = 0; var base = l * GM;
        while (i < GM) {
            var own = _topOwner(_lines[base + i]);
            if      (own == who)   { aCnt = aCnt + 1; }
            else if (own == enemy) { pCnt = pCnt + 1; }
            i = i + 1;
        }
        if (aCnt > 0 && pCnt > 0) { return 0; }       // contested — no value
        if (pCnt == 0) { return aCnt * aCnt; }         // own progress
        var pen = pCnt * pCnt * 2;
        if (pCnt == 3) { pen = pen + ((_diff == DIFF_HARD) ? 160 : 80); }
        return -pen;
    }

    // Fast positional score: only checks the 2-4 lines through cell 'dst'.
    // Board must already reflect the move before calling.
    // Lines: rows 0-3, cols 4-7, main-diag 8, anti-diag 9.
    hidden function _aiScoreAt(who, enemy, dst) {
        var r = dst / GM; var c = dst % GM;
        var sc = _aiScoreLine(who, enemy, r);
        sc = sc + _aiScoreLine(who, enemy, GM + c);
        if (r == c)        { sc = sc + _aiScoreLine(who, enemy, 8); }
        if (r + c == GM-1) { sc = sc + _aiScoreLine(who, enemy, 9); }
        return sc;
    }

    // Full-board positional score (used only as a fallback; kept for reference).
    hidden function _aiLineScoreFor(who) {
        var enemy = (who == 2) ? 1 : 2;
        var score = 0;
        var l = 0;
        while (l < 10) {
            score = score + _aiScoreLine(who, enemy, l);
            l = l + 1;
        }
        if (_diff == DIFF_EASY) { score = score + Math.rand() % 25 - 12; }
        return score;
    }

    // Pre-compute a bitmask of cells where 'enemy' can win by placing a hand piece.
    // Called ONCE per turn (not per candidate) — cost: GSIZES×GM2×~40 = ~2560 ops.
    // Returns 32-bit int with bit i set if placing any enemy hand piece at cell i wins.
    hidden function _enemyThreatMask(enemy, eh) {
        var mask = 0;
        var es = GSIZES;
        while (es >= 1) {
            if (eh[es - 1] > 0) {
                var ev = _makeVal(enemy, es);
                var ed = 0;
                while (ed < GM2) {
                    if (_canPlace(es, ed)) {
                        _place(ev, ed);
                        if (_checkWinAt(enemy, ed)) { mask = mask | (1 << ed); }
                        _pop(ed);
                    }
                    ed = ed + 1;
                }
            }
            es = es - 1;
        }
        return mask;
    }

    // Choose and execute the best move for player 'who' (1=P1/player, 2=AI).
    //
    // Watchdog budget (see block comment above for full breakdown):
    //   _enemyThreatMask : ~5 600 ops  (once per turn)
    //   Phase A          : ~7 680 ops  (64 candidates × ~120 ops)
    //   Phase B          : ~11 200 ops (32 budget × ~350 ops, dst-only score)
    //   Total            : ~24 480 ops — safely within watchdog limits.
    hidden function _aiDoMoveFor(who) {
        var enemy = (who == 2) ? 1 : 2;
        var ah  = (who == 2) ? _aih : _ph;
        var eh  = (who == 2) ? _ph  : _aih;
        var winScore   = (_diff == DIFF_HARD) ? 30000 : 10000;
        var blockScore = (_diff == DIFF_HARD) ? -25000 : -9000;
        var bestScore   = -999999;
        var bestSrcCell = -2;   // −2=none found, −1=from hand, 0..15=board cell
        var bestSize    = 0;
        var bestDst     = -1;

        // Pre-compute enemy threat mask once — O(1) lookup replaces per-candidate calls.
        var eThreat = 0;
        var ePen = 0;
        if (_diff != DIFF_EASY) {
            eThreat = _enemyThreatMask(enemy, eh);
            ePen = (_diff == DIFF_HARD) ? 20000 : 8000;
        }

        // ── Phase A: place from hand (prefer larger pieces first) ─────────
        var s = GSIZES;
        while (s >= 1) {
            if (ah[s - 1] > 0) {
                var aiVal = _makeVal(who, s);
                var dst = 0;
                while (dst < GM2) {
                    if (_canPlace(s, dst)) {
                        var capBonus = 0;
                        if (_topOwner(dst) == enemy) { capBonus = _topSize(dst) * 150; }
                        _place(aiVal, dst);
                        var sc = 0;
                        if (_checkWinAt(who, dst)) {
                            sc = winScore;
                        } else {
                            // _checkWinAt(enemy, dst) is always false here: we just
                            // placed our piece at dst so _topOwner(dst)==who.
                            sc = _aiScoreAt(who, enemy, dst) + capBonus;
                            // O(1) threat check: reward blocking, penalise ignoring threats
                            if (eThreat != 0) {
                                var bit = 1 << dst;
                                if ((eThreat & bit) != 0) {
                                    sc = sc + ePen;
                                } else {
                                    sc = sc - ePen;
                                }
                            }
                            if (_diff == DIFF_EASY) { sc = sc + Math.rand() % 25 - 12; }
                        }
                        _pop(dst);
                        if (sc > bestScore) {
                            bestScore = sc; bestSrcCell = -1; bestSize = s; bestDst = dst;
                        }
                    }
                    dst = dst + 1;
                }
            }
            s = s - 1;
        }

        // ── Phase B: move a board piece ───────────────────────────────────
        // Budget capped at 32/20 to stay within watchdog.
        // Score only dst (not src) to halve Phase B eval cost; src contribution
        // is approximated as zero (neutral) — fast and watchdog-safe.
        var src = 0; var phBudget = (_diff == DIFF_HARD) ? 32 : 20;
        while (src < GM2 && phBudget > 0) {
            if (_topOwner(src) == who) {
                var sz = _topSize(src);
                var dst = 0;
                while (dst < GM2 && phBudget > 0) {
                    phBudget = phBudget - 1;
                    if (dst != src && _canPlace(sz, dst)) {
                        var capBonus2 = 0;
                        if (_topOwner(dst) == enemy) { capBonus2 = _topSize(dst) * 150; }
                        var val = _pop(src);
                        _place(val, dst);
                        var sc = 0;
                        if      (_checkWinAt2(who, src, dst))   { sc = winScore; }
                        else if (_checkWinAt2(enemy, src, dst)) { sc = blockScore; }
                        else {
                            // Only score dst (not src) — halves Phase B eval cost.
                            sc = _aiScoreAt(who, enemy, dst) + capBonus2;
                            // O(1) threat check via pre-computed mask
                            if (eThreat != 0) {
                                var bit = 1 << dst;
                                if ((eThreat & bit) != 0) {
                                    sc = sc + ePen;
                                } else {
                                    sc = sc - ePen;
                                }
                            }
                            if (_diff == DIFF_EASY) { sc = sc + Math.rand() % 25 - 12; }
                        }
                        _pop(dst);
                        _place(val, src);
                        if (sc > bestScore) {
                            bestScore = sc; bestSrcCell = src; bestSize = sz; bestDst = dst;
                        }
                    }
                    dst = dst + 1;
                }
            }
            src = src + 1;
        }

        // ── Execute best move ─────────────────────────────────────────────
        if (bestDst >= 0) {
            if (bestSrcCell == -1) {
                ah[bestSize - 1] = ah[bestSize - 1] - 1;
                _place(_makeVal(who, bestSize), bestDst);
            } else if (bestSrcCell >= 0) {
                var val = _pop(bestSrcCell);
                _place(val, bestDst);
            }
        }
    }

    // ── Rendering ─────────────────────────────────────────────────────────
    function onUpdate(dc) {
        if (_state == GS_MENU) { _drawMenu(dc); return; }
        dc.setColor(0x06060E, 0x06060E);
        dc.clear();
        _drawGrid(dc);
        _drawPieces(dc);
        _drawCursor(dc);
        _drawHUD(dc);
        if (_state == GMS_P_SIZE) { _drawSizePicker(dc); }
        if (_state == GMS_OVER)   { _drawOver(dc); }
    }

    hidden function _cellX(c) { return _gx + c * _csz + _csz / 2; }
    hidden function _cellY(r) { return _gy + r * _csz + _csz / 2; }

    // ── Grid lines ────────────────────────────────────────────────────────
    hidden function _drawGrid(dc) {
        dc.setColor(0x1E1E30, Graphics.COLOR_TRANSPARENT);
        var i = 0;
        while (i <= GM) {
            var x = _gx + i * _csz; var y = _gy + i * _csz;
            dc.drawLine(x, _gy, x, _gy + GM * _csz);
            dc.drawLine(_gx, y, _gx + GM * _csz, y);
            i = i + 1;
        }
    }

    // ── Pieces ────────────────────────────────────────────────────────────
    hidden function _drawPieces(dc) {
        // Highlight board-source cell
        if (_state == GMS_P_DST && _selFrom == 1) {
            var sr = _selCell / GM; var sc2 = _selCell % GM;
            dc.setColor(0xFFDD00, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(_gx + sc2 * _csz + 1, _gy + sr * _csz + 1,
                             _csz - 2, _csz - 2);
        }
        // Valid-destination corner dots
        if (_state == GMS_P_DST) {
            var cell = 0;
            while (cell < GM2) {
                if (_canPlace(_selSize, cell) &&
                    (_selFrom == 0 || cell != _selCell)) {
                    var r2 = cell / GM; var c2 = cell % GM;
                    var x1 = _gx + c2 * _csz; var y1 = _gy + r2 * _csz;
                    dc.setColor(0x003800, Graphics.COLOR_TRANSPARENT);
                    dc.fillRectangle(x1 + 1,        y1 + 1,        4, 4);
                    dc.fillRectangle(x1 + _csz - 5, y1 + 1,        4, 4);
                    dc.fillRectangle(x1 + 1,        y1 + _csz - 5, 4, 4);
                    dc.fillRectangle(x1 + _csz - 5, y1 + _csz - 5, 4, 4);
                }
                cell = cell + 1;
            }
        }
        // Draw top piece in each occupied cell
        var cell = 0;
        while (cell < GM2) {
            if (_depth[cell] > 0) {
                var v   = _topOf(cell);
                var szI = (v - 1) % GSIZES;          // 0-indexed size
                var own = (v - 1) / GSIZES + 1;
                var r2  = cell / GM; var c2 = cell % GM;
                var cx  = _cellX(c2); var cy = _cellY(r2);
                var rad = _psz[szI];
                var col = (own == 1) ? 0xFF2200 : 0x0099FF;
                // Dark halo for contrast against any background
                dc.setColor(0x06060E, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(cx, cy, rad + 2);
                // Piece body
                dc.setColor(col, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(cx, cy, rad);
                // Inner dark ring — encodes size hierarchy visually
                if (szI >= 1) {
                    dc.setColor(0x06060E, Graphics.COLOR_TRANSPARENT);
                    dc.fillCircle(cx, cy, rad * 38 / 100);
                }
                // Stack-depth indicator at cell top-left (how many hidden below)
                if (_depth[cell] > 1) {
                    dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
                    dc.drawText(_gx + c2 * _csz + 2, _gy + r2 * _csz,
                                Graphics.FONT_XTINY,
                                _depth[cell].format("%d"),
                                Graphics.TEXT_JUSTIFY_LEFT);
                }
            }
            cell = cell + 1;
        }
    }

    // ── Cursor ────────────────────────────────────────────────────────────
    hidden function _drawCursor(dc) {
        if (_state == GMS_OVER || _state == GMS_AI || _state == GMS_P_SIZE) { return; }
        var r = _gridCur / GM; var c = _gridCur % GM;
        var x1 = _gx + c * _csz; var y1 = _gy + r * _csz;
        var col = 0x666677;   // neutral browse
        if (_state == GMS_P_SEL) {
            if (_topOwner(_gridCur) == 1)   { col = 0xFFDD00; }  // own piece — pickable
        } else if (_state == GMS_P_DST) {
            if (_selFrom == 1 && _gridCur == _selCell) {
                col = 0xFF8800;                                     // cancel: same as source
            } else if (_canPlace(_selSize, _gridCur)) {
                col = 0x44FF44;                                     // valid destination
            } else {
                col = 0x662222;                                     // invalid
            }
        }
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(x1 + 2, y1 + 2, _csz - 4, _csz - 4);
        // Corner ticks for extra visibility
        dc.drawLine(x1, y1, x1 + 6, y1);
        dc.drawLine(x1, y1, x1, y1 + 6);
        dc.drawLine(x1 + _csz, y1, x1 + _csz - 6, y1);
        dc.drawLine(x1 + _csz, y1, x1 + _csz, y1 + 6);
        dc.drawLine(x1, y1 + _csz, x1 + 6, y1 + _csz);
        dc.drawLine(x1, y1 + _csz, x1, y1 + _csz - 6);
        dc.drawLine(x1 + _csz, y1 + _csz, x1 + _csz - 6, y1 + _csz);
        dc.drawLine(x1 + _csz, y1 + _csz, x1 + _csz, y1 + _csz - 6);
    }

    // ── HUD ───────────────────────────────────────────────────────────────
    hidden function _drawHUD(dc) {
        var ty    = 2;
        var hSlot = _sw / (GSIZES + 1);                    // icon column spacing
        var hx0   = hSlot;                                  // first icon centre-x

        // Session wins (corners)
        dc.setColor(0xFF3300, Graphics.COLOR_TRANSPARENT);
        dc.drawText(4, ty, Graphics.FONT_XTINY, "W:" + _sP.format("%d"),
                    Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(0x2299FF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_sw - 4, ty, Graphics.FONT_XTINY, _sAI.format("%d") + ":W",
                    Graphics.TEXT_JUSTIFY_RIGHT);

        // Turn / action indicator (centre top)
        var msg = "";
        var mc  = 0x666677;
        if (_state == GMS_P_SEL) {
            if (_mode == MODE_PVP && _activePlayer == 2) { msg = "P2 TURN"; mc = 0x4499FF; }
            else                                         { msg = "YOUR TURN"; mc = 0x44FF44; }
        } else if (_state == GMS_P_SIZE) { msg = "PICK SIZE"; mc = 0xFFDD00; }
        else if (_state == GMS_P_DST) {
            if (_selFrom == 0) { msg = "PLACE SZ:" + _selSize.format("%d"); mc = 0xFF8844; }
            else               { msg = "MOVE PIECE"; mc = 0xFF8844; }
        } else if (_state == GMS_AI) { msg = "AI..."; mc = 0x334455; }
        dc.setColor(mc, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_sw / 2, ty, Graphics.FONT_XTINY, msg, Graphics.TEXT_JUSTIFY_CENTER);

        // Player hand strip (above grid)
        var hpY = _gy - _hpsz[3] - 3;
        if (hpY < 14) { hpY = 14; }
        var s = 0;
        while (s < GSIZES) {
            var cx = hx0 + s * hSlot;
            var ir = _hpsz[s];
            var avail = (_ph[s] > 0);
            dc.setColor(avail ? 0xFF2200 : 0x330800, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, hpY, ir);
            if (avail) {
                dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, hpY + ir, Graphics.FONT_XTINY,
                            _ph[s].format("%d"), Graphics.TEXT_JUSTIFY_CENTER);
            }
            s = s + 1;
        }
        // Highlight the size currently in transit (from hand)
        if (_state == GMS_P_DST && _selFrom == 0) {
            var cx = hx0 + (_selSize - 1) * hSlot;
            dc.setColor(0xFFDD00, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(cx, hpY, _hpsz[_selSize - 1] + 3);
        }

        // AI hand strip (below grid)
        var ahY = _gy + GM * _csz + _hpsz[3] + 4;
        if (ahY > _sh - 4) { ahY = _sh - 4; }
        s = 0;
        while (s < GSIZES) {
            var cx = hx0 + s * hSlot;
            var ir = _hpsz[s];
            var avail = (_aih[s] > 0);
            dc.setColor(avail ? 0x0099FF : 0x001133, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, ahY, ir);
            if (avail) {
                dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, ahY + ir, Graphics.FONT_XTINY,
                            _aih[s].format("%d"), Graphics.TEXT_JUSTIFY_CENTER);
            }
            s = s + 1;
        }
    }

    // ── Size-picker overlay ───────────────────────────────────────────────
    // Shows 4 size options horizontally above/below the cursor cell.
    hidden function _drawSizePicker(dc) {
        var bw = _csz * 4; var bh = _csz * 3 / 4;
        if (bw > _sw - 8)  { bw = _sw - 8; }
        if (bh < 36)        { bh = 36; }
        var ox = _sw / 2 - bw / 2;
        var r  = _gridCur / GM;
        // Prefer above the cell; flip below if not enough room
        var oy = _gy + r * _csz - bh - 4;
        if (oy < _gy)      { oy = _gy + (r + 1) * _csz + 4; }
        if (oy < 0)        { oy = 0; }
        if (oy + bh > _sh) { oy = _sh - bh; }

        dc.setColor(0x08081A, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(ox, oy, bw, bh, 8);
        dc.setColor(0x444466, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(ox, oy, bw, bh, 8);

        // Scale radii to fit picker height, maintain proportions
        var maxR = bh / 2 - 6;
        if (maxR < 4) { maxR = 4; }
        var sw4 = bw / GSIZES;
        var s = 0;
        while (s < GSIZES) {
            var sz    = s + 1;
            var hand  = (_activePlayer == 1) ? _ph : _aih;
            var avail = (hand[s] > 0 && _canPlace(sz, _gridCur));
            var cx    = ox + s * sw4 + sw4 / 2;
            var cy    = oy + bh / 2;
            var rad   = _psz[s] * maxR / _psz[3];
            if (rad < 3) { rad = 3; }
            if (avail) {
                if (_sizePick == sz) {
                    dc.setColor(0xFFDD00, Graphics.COLOR_TRANSPARENT);
                    dc.fillCircle(cx, cy, rad + 4);
                }
                dc.setColor((_activePlayer == 1) ? 0xFF2200 : 0x0099FF, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(cx, cy, rad);
                dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, cy + rad + 1, Graphics.FONT_XTINY,
                            hand[s].format("%d"), Graphics.TEXT_JUSTIFY_CENTER);
            } else {
                dc.setColor(0x220800, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(cx, cy, rad);
            }
            s = s + 1;
        }
        // Hint
        dc.setColor(0x444455, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_sw / 2, oy + bh - 11, Graphics.FONT_XTINY,
                    "nxt=size  SELECT ok", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Game-over overlay ─────────────────────────────────────────────────
    hidden function _drawOver(dc) {
        var bw = _sw * 56 / 100; var bh = _sh * 30 / 100;
        if (bw < 150) { bw = 150; } if (bh < 90) { bh = 90; }
        var ox = _sw / 2 - bw / 2; var oy = _sh / 2 - bh / 2;
        dc.setColor(0x040408, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(ox, oy, bw, bh, 10);
        dc.setColor(0x3A3A5A, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(ox, oy, bw, bh, 10);
        var cx = _sw / 2;
        var msg = ""; var mc = 0xCCCCCC;
        if      (_overWho == GOM_PWIN)  { msg = (_mode == MODE_PVP) ? "P1 WINS!" : "YOU WIN!"; mc = 0xFF2200; }
        else if (_overWho == GOM_AIWIN) { msg = (_mode == MODE_PVP) ? "P2 WINS!" : "AI WINS!"; mc = 0x0099FF; }
        dc.setColor(mc, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, oy + 8, Graphics.FONT_SMALL, msg, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x555566, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, oy + 38, Graphics.FONT_XTINY,
                    "W:" + _sP.format("%d") + "   " + _sAI.format("%d") + ":W",
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x2A2A44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, oy + bh - 14, Graphics.FONT_XTINY,
                    "SELECT = menu", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Pre-game menu ─────────────────────────────────────────────────────
    hidden function _drawMenu(dc) {
        dc.setColor(0x080808, 0x080808); dc.clear();
        var hw = _sw / 2;
        dc.setColor(0x0C0C0C, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(hw, hw, hw - 1);
        dc.setColor(0xFFAA00, Graphics.COLOR_TRANSPARENT);
        dc.drawText(hw, _sh * 9 / 100, Graphics.FONT_XTINY, "GOBBLET MINI", Graphics.TEXT_JUSTIFY_CENTER);
        var modeStr = (_mode == MODE_PVAI) ? "P vs AI" : ((_mode == MODE_PVP) ? "P vs P" : "AI vs AI");
        var diffStr = (_diff == DIFF_EASY) ? "Easy" : ((_diff == DIFF_MED) ? "Med" : "Hard");
        var sideStr = _playerFirst ? "Side: Lt" : "Side: Dk";
        var rows = ["Mode: " + modeStr, "Diff: " + diffStr, sideStr, "START"];
        var nR = 4;
        var rowH = _sh * 11 / 100; if (rowH < 22) { rowH = 22; } if (rowH > 32) { rowH = 32; }
        var rowW = _sw * 66 / 100; var rowX = (_sw - rowW) / 2;
        var gap = 5; var tot = nR * rowH + (nR - 1) * gap; var rowY0 = (_sh - tot) / 2 + rowH;
        var i = 0;
        while (i < nR) {
            var ry = rowY0 + i * (rowH + gap); var sel = (i == _menuSel); var isStart = (i == nR - 1);
            dc.setColor(sel ? (isStart ? 0x2A1A00 : 0x0A2040) : 0x0A0A0A, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(rowX, ry, rowW, rowH, 5);
            dc.setColor(sel ? (isStart ? 0xFFAA00 : 0x4499FF) : 0x1A1A2A, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(rowX, ry, rowW, rowH, 5);
            if (sel) {
                dc.setColor(isStart ? 0xFFAA00 : 0x4499FF, Graphics.COLOR_TRANSPARENT);
                var ay = ry + rowH / 2;
                dc.fillPolygon([[rowX + 5, ay - 4], [rowX + 5, ay + 4], [rowX + 11, ay]]);
            }
            var dimmed = (i == 1 && _mode == MODE_PVP) || (i == 2 && _mode != MODE_PVAI);
            dc.setColor(dimmed ? 0x445566 : (sel ? (isStart ? 0xFFDD99 : 0xAADDFF) : 0x556677), Graphics.COLOR_TRANSPARENT);
            dc.drawText(hw, ry + (rowH - 14) / 2, Graphics.FONT_XTINY, rows[i], Graphics.TEXT_JUSTIFY_CENTER);
            i++;
        }
        dc.setColor(0x334455, Graphics.COLOR_TRANSPARENT);
        dc.drawText(hw, _sh - 14, Graphics.FONT_XTINY, "UP/DN sel  SELECT set/start", Graphics.TEXT_JUSTIFY_CENTER);
    }

    function doTap(tx, ty) {
        if (_state == GS_MENU) {
            var nR = 4;
            var rowH = _sh * 11 / 100; if (rowH < 22) { rowH = 22; } if (rowH > 32) { rowH = 32; }
            var rowW = _sw * 66 / 100; var rowX = (_sw - rowW) / 2;
            var gap = 5; var tot = nR * rowH + (nR - 1) * gap; var rowY0 = (_sh - tot) / 2 + rowH;
            for (var i = 0; i < nR; i++) {
                var ry = rowY0 + i * (rowH + gap);
                if (tx >= rowX && tx < rowX + rowW && ty >= ry && ty < ry + rowH) {
                    _menuSel = i; doAction(); return;
                }
            }
            return;
        }
        if (_state == GMS_OVER) { _state = GS_MENU; _menuSel = 0; return; }
        if (_state == GMS_AI)   { return; }
        if (_csz <= 0) { return; }
        // Map tap to board cell
        var col = (tx - _gx) / _csz;
        var row = (ty - _gy) / _csz;
        if (col >= 0 && col < GM && row >= 0 && row < GM) {
            _gridCur = row * GM + col;
        }
        doAction();
    }
}
