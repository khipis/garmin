using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.Math;

// ── Dots & Boxes — grid layout ────────────────────────────────────────────
//
// 5 × 5 dot grid  →  4 × 4 = 16 boxes,  40 edges total.
//
// Edge index encoding (flat array, zero allocations):
//   Horizontal  h(r,c): row r∈[0..4], col c∈[0..3]  → index = r*4+c   (0..19)
//   Vertical    v(r,c): row r∈[0..3], col c∈[0..4]  → index = 20+r*5+c (20..39)
//
// Cursor navigation:
//   KEY_UP   from h(r,c) → h((r−1) mod DOTS, c)   wraps row upward
//   KEY_DOWN from h(r,c) → h((r+1) mod DOTS, c)   wraps row downward
//   KEY_UP   from v(r,c) → v((r−1) mod BOXES, c)  wraps row upward
//   KEY_DOWN from v(r,c) → v((r+1) mod BOXES, c)  wraps row downward
//   onNextPage     → (_cursor+1)            % EDGES  (linear reading order)
//   onPreviousPage → (_cursor+EDGES−1)      % EDGES  (linear reading order)
//
// Box (br,bc) sides:
//   top=h(br,bc)  bottom=h(br+1,bc)  left=v(br,bc)  right=v(br,bc+1)

const DB_DOTS  = 5;    // dots per side
const DB_BOXES = 4;    // boxes per side  (DOTS − 1)
const DB_H     = 20;   // horizontal edges  (DOTS × BOXES)
const DB_V     = 20;   // vertical   edges  (BOXES × DOTS)
const DB_EDGES = 40;   // total edges
const DB_B     = 16;   // total boxes  (BOXES²)

const DC_NONE   = 0;
const DC_PLAYER = 1;   // human — Red
const DC_AI     = 2;   // computer — Blue

const DBS_PLAYER = 0;  // player's turn
const DBS_AI     = 1;  // AI thinking (timer-driven)
const DBS_OVER   = 2;

const DOV_PWIN  = 1;
const DOV_AIWIN = 2;
const DOV_TIE   = 3;

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
    hidden var _bx, _by;   // pixel position of the top-left dot
    hidden var _step;      // pixels between adjacent dots
    hidden var _dr;        // dot radius

    // ── Game data — all pre-allocated in initialize(), zero runtime alloc ─
    hidden var _edges;     // int[40]  DC_NONE / DC_PLAYER / DC_AI
    hidden var _boxes;     // int[16]  DC_NONE / DC_PLAYER / DC_AI
    hidden var _tmpBr;     // int[2]   scratch: adjacent box row indices
    hidden var _tmpBc;     // int[2]   scratch: adjacent box col indices
    hidden var _tmpCnt;    // int      valid entries in _tmpBr / _tmpBc

    // ── Scores ────────────────────────────────────────────────────────────
    hidden var _pScore, _aiScore;   // boxes claimed this game
    hidden var _sP, _sAI;           // session wins

    // ── State ─────────────────────────────────────────────────────────────
    hidden var _state;
    hidden var _overType;
    hidden var _cursor;    // current edge index 0–39

    // ── Timer ─────────────────────────────────────────────────────────────
    hidden var _timer;
    hidden var _mode;
    hidden var _diff;
    hidden var _menuSel;
    hidden var _playerFirst;

    // ─────────────────────────────────────────────────────────────────────
    function initialize() {
        View.initialize();
        _edges  = new [DB_EDGES];
        _boxes  = new [DB_B];
        _tmpBr  = new [2];
        _tmpBc  = new [2];
        _sP     = 0;
        _sAI    = 0;
        _timer  = null;
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
        // Board fills 70 % of screen width — corners stay inside round 454-px screen
        var bsz = _sw * 62 / 100;
        _step   = bsz / DB_BOXES;
        _bx     = (_sw - bsz) / 2;
        _by     = (_sh - bsz) / 2;
        if (_by < 26) { _by = 26; }
        _dr     = _step * 8 / 100;
        if (_dr < 3) { _dr = 3; }
        _timer  = new Timer.Timer();
        _timer.start(method(:gameTick), 420, true);
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); }
    }

    // ── Public input API ──────────────────────────────────────────────────
    // dir: 0=KEY_UP (row up)  1=KEY_DOWN (row down)
    //      2=onPreviousPage (linear prev)  3=onNextPage (linear next)
    // Menu: 0|2 → prev item, 1|3 → next item
    function navigate(dir) {
        if (_state == GS_MENU) {
            if (dir == 0 || dir == 2) { _menuSel = (_menuSel + 3) % 4; }
            else if (dir == 1 || dir == 3) { _menuSel = (_menuSel + 1) % 4; }
            WatchUi.requestUpdate();
            return;
        }
        if (_state == DBS_AI && _mode != MODE_PVP) { return; }
        if (_state != DBS_PLAYER && _state != DBS_AI) { return; }
        var e = _cursor;
        if (dir == 2) {
            // linear previous edge (wrapping)
            _cursor = (e + DB_EDGES - 1) % DB_EDGES;
        } else if (dir == 3) {
            // linear next edge (wrapping)
            _cursor = (e + 1) % DB_EDGES;
        } else if (e < DB_H) {
            // horizontal h(r, c) — KEY_UP/DOWN shifts row, wrapping
            var r = e / DB_BOXES; var c = e % DB_BOXES;
            if      (dir == 0) { _cursor = ((r + DB_DOTS  - 1) % DB_DOTS)  * DB_BOXES + c; }
            else if (dir == 1) { _cursor = ((r + 1)        % DB_DOTS)       * DB_BOXES + c; }
        } else {
            // vertical v(r, c) — KEY_UP/DOWN shifts row, wrapping
            var idx = e - DB_H;
            var r = idx / DB_DOTS; var c = idx % DB_DOTS;
            if      (dir == 0) { _cursor = DB_H + ((r + DB_BOXES - 1) % DB_BOXES) * DB_DOTS + c; }
            else if (dir == 1) { _cursor = DB_H + ((r + 1)            % DB_BOXES) * DB_DOTS + c; }
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
        if (_state == DBS_OVER) { _state = GS_MENU; _menuSel = 0; WatchUi.requestUpdate(); return; }
        if (_state == DBS_AI && _mode != MODE_PVP) { return; }
        if (_state != DBS_PLAYER && _state != DBS_AI) { return; }
        var e = _cursor;
        if (_edges[e] != DC_NONE) { return; }
        var who = (_state == DBS_AI) ? DC_AI : DC_PLAYER;
        var got = _claimBoxes(e, who);
        if (_state == DBS_AI) {
            _aiScore = _aiScore + got;
            if (_pScore + _aiScore == DB_B) { _endGame(); return; }
            if (got == 0) { _state = DBS_PLAYER; }
        } else {
            _pScore = _pScore + got;
            if (_pScore + _aiScore == DB_B) { _endGame(); return; }
            if (got == 0) { _state = DBS_AI; }
        }
    }

    // ── 420 ms timer tick ─────────────────────────────────────────────────
    function gameTick() as Void {
        if (_mode == MODE_PVP) { WatchUi.requestUpdate(); return; }
        if (_state == DBS_AI) {
            var e = _aiChooseEdge();
            if (e < 0) { _state = DBS_PLAYER; WatchUi.requestUpdate(); return; }
            var got = _claimBoxes(e, DC_AI);
            _aiScore = _aiScore + got;
            if (_pScore + _aiScore == DB_B) { _endGame(); }
            else if (got == 0) { _state = DBS_PLAYER; }
            WatchUi.requestUpdate();
        } else if (_mode == MODE_AIAI && _state == DBS_PLAYER) {
            var e = _aiChooseEdge();
            if (e < 0) { _state = DBS_AI; WatchUi.requestUpdate(); return; }
            var got = _claimBoxes(e, DC_PLAYER);
            _pScore = _pScore + got;
            if (_pScore + _aiScore == DB_B) { _endGame(); }
            else if (got == 0) { _state = DBS_AI; }
            WatchUi.requestUpdate();
        }
    }

    // ── Game management ───────────────────────────────────────────────────
    hidden function _startGame() {
        var i = 0;
        while (i < DB_EDGES) { _edges[i] = DC_NONE; i = i + 1; }
        i = 0;
        while (i < DB_B)     { _boxes[i] = DC_NONE; i = i + 1; }
        _pScore   = 0;
        _aiScore  = 0;
        _overType = 0;
        _cursor   = 0;
        if (_mode == MODE_AIAI) {
            _state = DBS_AI;
        } else if (_mode == MODE_PVAI && !_playerFirst) {
            _state = DBS_AI;
        } else {
            _state = DBS_PLAYER;
        }
    }

    hidden function _endGame() {
        if (_pScore > _aiScore)       { _overType = DOV_PWIN;  _sP  = _sP  + 1; }
        else if (_aiScore > _pScore)  { _overType = DOV_AIWIN; _sAI = _sAI + 1; }
        else                          { _overType = DOV_TIE; }
        _state = DBS_OVER;
    }

    // ── Board logic ───────────────────────────────────────────────────────
    // Fill _tmpBr/_tmpBc/_tmpCnt with the (≤2) box indices adjacent to edge e.
    hidden function _getAdj(e) {
        _tmpCnt = 0;
        if (e < DB_H) {
            // horizontal h(r, c) — top edge of box(r,c), bottom of box(r-1,c)
            var r = e / DB_BOXES; var c = e % DB_BOXES;
            if (r > 0)        { _tmpBr[_tmpCnt] = r-1; _tmpBc[_tmpCnt] = c; _tmpCnt = _tmpCnt + 1; }
            if (r < DB_BOXES) { _tmpBr[_tmpCnt] = r;   _tmpBc[_tmpCnt] = c; _tmpCnt = _tmpCnt + 1; }
        } else {
            // vertical v(r, c) — left edge of box(r,c), right edge of box(r,c-1)
            var idx = e - DB_H; var r = idx / DB_DOTS; var c = idx % DB_DOTS;
            if (c > 0)        { _tmpBr[_tmpCnt] = r; _tmpBc[_tmpCnt] = c-1; _tmpCnt = _tmpCnt + 1; }
            if (c < DB_BOXES) { _tmpBr[_tmpCnt] = r; _tmpBc[_tmpCnt] = c;   _tmpCnt = _tmpCnt + 1; }
        }
    }

    // Number of drawn sides of box (br, bc).
    // top=h(br,bc)  bottom=h(br+1,bc)  left=v(br,bc)  right=v(br,bc+1)
    hidden function _sideCount(br, bc) {
        var n = 0;
        if (_edges[br * DB_BOXES + bc] != 0)             { n = n + 1; }
        if (_edges[(br+1) * DB_BOXES + bc] != 0)         { n = n + 1; }
        if (_edges[DB_H + br * DB_DOTS + bc] != 0)       { n = n + 1; }
        if (_edges[DB_H + br * DB_DOTS + bc + 1] != 0)   { n = n + 1; }
        return n;
    }

    // Draw edge e for 'who', claim any newly completed boxes. Returns count.
    hidden function _claimBoxes(e, who) {
        _edges[e] = who;
        _getAdj(e);
        var scored = 0;
        var i = 0;
        while (i < _tmpCnt) {
            var br = _tmpBr[i]; var bc = _tmpBc[i];
            var b  = br * DB_BOXES + bc;
            if (_boxes[b] == DC_NONE && _sideCount(br, bc) == 4) {
                _boxes[b] = who;
                scored = scored + 1;
            }
            i = i + 1;
        }
        return scored;
    }

    // ── AI helpers ────────────────────────────────────────────────────────
    // True if drawing open edge e would complete at least one adjacent box.
    hidden function _wouldComplete(e) {
        _getAdj(e);
        var i = 0;
        while (i < _tmpCnt) {
            if (_sideCount(_tmpBr[i], _tmpBc[i]) == 3) { return true; }
            i = i + 1;
        }
        return false;
    }

    // True if drawing edge e would leave any adjacent box at 3 sides
    // (opponent then closes it for free on the next turn).
    hidden function _wouldGiveBox(e) {
        _getAdj(e);
        var i = 0;
        while (i < _tmpCnt) {
            if (_sideCount(_tmpBr[i], _tmpBc[i]) == 2) { return true; }
            i = i + 1;
        }
        return false;
    }

    // Count of adjacent boxes that would reach 3 sides after drawing e.
    hidden function _giveawayCount(e) {
        _getAdj(e);
        var n = 0; var i = 0;
        while (i < _tmpCnt) {
            if (_sideCount(_tmpBr[i], _tmpBc[i]) == 2) { n = n + 1; }
            i = i + 1;
        }
        return n;
    }

    // True if any box adjacent to edge e is already claimed by the AI.
    hidden function _adjToOwnBox(e) {
        _getAdj(e);
        var i = 0;
        while (i < _tmpCnt) {
            if (_boxes[_tmpBr[i] * DB_BOXES + _tmpBc[i]] == DC_AI) { return true; }
            i = i + 1;
        }
        return false;
    }

    // Return the single undrawn edge of box (br,bc) when it has exactly 3 drawn
    // sides. Uses DC_NONE==0 check, consistent with _sideCount. Returns -1 otherwise.
    hidden function _fourthEdge(br, bc) {
        var e0 = br * DB_BOXES + bc;
        var e1 = (br + 1) * DB_BOXES + bc;
        var e2 = DB_H + br * DB_DOTS + bc;
        var e3 = DB_H + br * DB_DOTS + bc + 1;
        var drawn = 0; var undrawn = -1;
        if (_edges[e0] != DC_NONE) { drawn = drawn + 1; } else { undrawn = e0; }
        if (_edges[e1] != DC_NONE) { drawn = drawn + 1; } else { undrawn = e1; }
        if (_edges[e2] != DC_NONE) { drawn = drawn + 1; } else { undrawn = e2; }
        if (_edges[e3] != DC_NONE) { drawn = drawn + 1; } else { undrawn = e3; }
        if (drawn == 3) { return undrawn; }
        return -1;
    }

    // Count how many consecutive boxes the opponent can capture after we draw
    // edge e. Uses value 3 as a temporary "drawn" marker (DC_NONE=0, DC_PLAYER=1,
    // DC_AI=2 are all legitimate; 3 is safe scratch). Restores _edges[] on exit.
    // Budget of 50 inner-loop iterations prevents worst-case watchdog exposure:
    // theoretical worst = 16 passes × 16 boxes = 256 per call × 40 edges in P3.
    hidden function _chainLength(e) {
        if (_edges[e] != DC_NONE) { return 0; }
        _edges[e] = 3;
        var count = 0;
        var changed = true;
        var budget = 50;
        while (changed && budget > 0) {
            changed = false;
            var br = 0;
            while (br < DB_BOXES) {
                var bc = 0;
                while (bc < DB_BOXES && budget > 0) {
                    budget = budget - 1;
                    if (_boxes[br * DB_BOXES + bc] == DC_NONE && _sideCount(br, bc) == 3) {
                        var fe = _fourthEdge(br, bc);
                        if (fe >= 0) {
                            _edges[fe] = 3;
                            count = count + 1;
                            changed = true;
                        }
                    }
                    bc = bc + 1;
                }
                br = br + 1;
            }
        }
        var i = 0;
        while (i < DB_EDGES) { if (_edges[i] == 3) { _edges[i] = DC_NONE; } i = i + 1; }
        return count;
    }

    // Double-cross: for a chain of length ≥ 3 opened by edge e, return the
    // interior cross-edge whose drawing gives the opponent only the last 2 boxes
    // while leaving the first (N-2) boxes for the AI to reclaim. Returns e for
    // chains shorter than 3.
    hidden function _dcEdge(e) {
        if (_edges[e] != DC_NONE) { return e; }
        var n = _chainLength(e);
        if (n < 3) { return e; }
        _edges[e] = 3;
        var cur = e;
        var step = 0;
        var target = n - 2;
        while (step < target) {
            var done = false;
            var br = 0;
            while (br < DB_BOXES && !done) {
                var bc = 0;
                while (bc < DB_BOXES && !done) {
                    if (_boxes[br * DB_BOXES + bc] == DC_NONE && _sideCount(br, bc) == 3) {
                        var fe = _fourthEdge(br, bc);
                        if (fe >= 0) {
                            _edges[fe] = 3;
                            cur = fe;
                            step = step + 1;
                            done = true;
                        }
                    }
                    bc = bc + 1;
                }
                br = br + 1;
            }
            if (!done) { step = target; }
        }
        var result = cur;
        var i = 0;
        while (i < DB_EDGES) { if (_edges[i] == 3) { _edges[i] = DC_NONE; } i = i + 1; }
        return result;
    }

    // Count chains on the entire board and return parity (odd = good for opener).
    // A "chain" is any sequence of connected near-complete boxes (3 sides drawn).
    // We count the number of long chains (length ≥ 3) since those determine parity.
    hidden function _countLongChains() {
        var n = 0; var visited = 0;
        var e = 0;
        while (e < DB_EDGES) {
            if (_edges[e] == DC_NONE) {
                var len = _chainLength(e);
                if (len >= 3) {
                    n = n + 1;
                    visited = visited + len;
                }
            }
            e = e + 1;
        }
        return n;
    }

    // ── AI: chain-aware greedy strategy (improved) ────────────────────────
    //
    //  P1: Complete a box immediately (always).
    //  P2: Safe edge — won't give opponent a free box.
    //      Hard: prefer safe edges adjacent to own completed boxes.
    //  P3: Chain parity control: if the current number of long chains has the
    //      "wrong" parity, open a short chain (≤2) to change parity.
    //      Med/Hard: for chains ≥ 3, apply double-cross tactic.
    hidden function _aiChooseEdge() {
        if (_diff == DIFF_EASY && Math.rand() % 10 < 3) {
            var rnd = Math.rand() % DB_EDGES;
            var ci = 0;
            while (ci < DB_EDGES) {
                var er = (rnd + ci) % DB_EDGES;
                if (_edges[er] == DC_NONE) { return er; }
                ci = ci + 1;
            }
        }
        var e = 0;

        // P1: take any completing edge
        while (e < DB_EDGES) {
            if (_edges[e] == DC_NONE && _wouldComplete(e)) { return e; }
            e = e + 1;
        }

        // P2: safe edge
        var offset = Math.rand() % DB_EDGES;
        var cnt = 0;
        if (_diff == DIFF_HARD) {
            while (cnt < DB_EDGES) {
                e = (offset + cnt) % DB_EDGES;
                if (_edges[e] == DC_NONE && !_wouldGiveBox(e) && _adjToOwnBox(e)) { return e; }
                cnt = cnt + 1;
            }
            cnt = 0;
        }
        while (cnt < DB_EDGES) {
            e = (offset + cnt) % DB_EDGES;
            if (_edges[e] == DC_NONE && !_wouldGiveBox(e)) { return e; }
            cnt = cnt + 1;
        }

        // P3: parity-aware sacrifice
        // Ideal: keep number of long chains even (AI is second player → wants odd).
        // But we don't know who goes first easily, so: prefer opening short chains
        // to avoid giving long chain runs.
        var bestShort = -1; var bestShortLen = 99;
        var bestLong  = -1; var bestLongLen  = 99;
        e = 0;
        while (e < DB_EDGES) {
            if (_edges[e] == DC_NONE) {
                var chainLen = (_diff == DIFF_EASY) ? _giveawayCount(e) : _chainLength(e);
                var rng = (_diff == DIFF_HARD) ? 0 : Math.rand() % 3;
                if (chainLen <= 2) {
                    if (bestShort < 0 || chainLen < bestShortLen) {
                        bestShortLen = chainLen; bestShort = e;
                    }
                } else {
                    if (bestLong < 0 || chainLen < bestLongLen) {
                        bestLongLen = chainLen; bestLong = e;
                    }
                }
            }
            e = e + 1;
        }

        // Hard/Med: prefer short chains (len ≤ 2) to avoid giving long runs
        if (_diff != DIFF_EASY && bestShort >= 0) { return bestShort; }

        // Must open a long chain — use double-cross for Med/Hard
        var best = (bestShort >= 0) ? bestShort : bestLong;
        var bestLen = (bestShort >= 0) ? bestShortLen : bestLongLen;
        if (best >= 0 && bestLen >= 3 && _diff != DIFF_EASY) {
            return _dcEdge(best);
        }
        return (best >= 0) ? best : 0;
    }

    // ── Rendering ─────────────────────────────────────────────────────────
    function onUpdate(dc) {
        if (_state == GS_MENU) { _drawMenu(dc); return; }
        dc.setColor(0x06060E, 0x06060E);
        dc.clear();
        _drawBoxFills(dc);
        _drawGuideEdges(dc);
        _drawDrawnEdges(dc);
        _drawCursor(dc);
        _drawDots(dc);
        _drawHUD(dc);
        if (_state == DBS_OVER) { _drawOver(dc); }
    }

    hidden function _dotX(c) { return _bx + c * _step; }
    hidden function _dotY(r) { return _by + r * _step; }

    // ── Claimed box fills + centre ownership marker ───────────────────────
    hidden function _drawBoxFills(dc) {
        var br = 0;
        while (br < DB_BOXES) {
            var bc = 0;
            while (bc < DB_BOXES) {
                var owner = _boxes[br * DB_BOXES + bc];
                if (owner != DC_NONE) {
                    var x1 = _dotX(bc) + 1; var y1 = _dotY(br) + 1;
                    var bw = _step - 2;      var bh = _step - 2;
                    // Subtle tinted fill
                    dc.setColor(owner == DC_PLAYER ? 0x220500 : 0x001520,
                                Graphics.COLOR_TRANSPARENT);
                    dc.fillRectangle(x1, y1, bw, bh);
                    // Centre circle showing owner
                    var cr = _step * 15 / 100;
                    if (cr < 4) { cr = 4; }
                    dc.setColor(owner == DC_PLAYER ? 0xFF2200 : 0x0099FF,
                                Graphics.COLOR_TRANSPARENT);
                    dc.fillCircle(_dotX(bc) + _step / 2,
                                  _dotY(br) + _step / 2, cr);
                }
                bc = bc + 1;
            }
            br = br + 1;
        }
    }

    // ── Faint guide lines showing all potential edge positions ────────────
    hidden function _drawGuideEdges(dc) {
        dc.setColor(0x1B1B2B, Graphics.COLOR_TRANSPARENT);
        // Horizontal guides: DB_DOTS rows × DB_BOXES edges each
        var r = 0;
        while (r < DB_DOTS) {
            var c = 0;
            while (c < DB_BOXES) {
                dc.drawLine(_dotX(c), _dotY(r), _dotX(c + 1), _dotY(r));
                c = c + 1;
            }
            r = r + 1;
        }
        // Vertical guides: DB_BOXES rows × DB_DOTS edges each
        r = 0;
        while (r < DB_BOXES) {
            var c = 0;
            while (c < DB_DOTS) {
                dc.drawLine(_dotX(c), _dotY(r), _dotX(c), _dotY(r + 1));
                c = c + 1;
            }
            r = r + 1;
        }
    }

    // ── Drawn edges (bright player/AI colours) ────────────────────────────
    hidden function _drawDrawnEdges(dc) {
        // Horizontal edges 0..19
        var e = 0;
        while (e < DB_H) {
            var owner = _edges[e];
            if (owner != DC_NONE) {
                var r = e / DB_BOXES; var c = e % DB_BOXES;
                dc.setColor(owner == DC_PLAYER ? 0xFF2200 : 0x0099FF,
                            Graphics.COLOR_TRANSPARENT);
                dc.drawLine(_dotX(c), _dotY(r), _dotX(c + 1), _dotY(r));
            }
            e = e + 1;
        }
        // Vertical edges 20..39
        while (e < DB_EDGES) {
            var owner = _edges[e];
            if (owner != DC_NONE) {
                var idx = e - DB_H;
                var r = idx / DB_DOTS; var c = idx % DB_DOTS;
                dc.setColor(owner == DC_PLAYER ? 0xFF2200 : 0x0099FF,
                            Graphics.COLOR_TRANSPARENT);
                dc.drawLine(_dotX(c), _dotY(r), _dotX(c), _dotY(r + 1));
            }
            e = e + 1;
        }
    }

    // ── Cursor — triple-line highlight on selected edge ───────────────────
    hidden function _drawCursor(dc) {
        if (_state != DBS_PLAYER && !(_state == DBS_AI && _mode == MODE_PVP)) { return; }
        var e = _cursor;
        var taken = (_edges[e] != DC_NONE);
        dc.setColor(taken ? 0xFF8800 : 0xFFFF00, Graphics.COLOR_TRANSPARENT);
        if (e < DB_H) {
            // Horizontal: 3 stacked horizontal lines for thickness
            var r = e / DB_BOXES; var c = e % DB_BOXES;
            var x1 = _dotX(c); var y1 = _dotY(r); var x2 = _dotX(c + 1);
            dc.drawLine(x1, y1 - 1, x2, y1 - 1);
            dc.drawLine(x1, y1,     x2, y1);
            dc.drawLine(x1, y1 + 1, x2, y1 + 1);
        } else {
            // Vertical: 3 side-by-side vertical lines for thickness
            var idx = e - DB_H;
            var r = idx / DB_DOTS; var c = idx % DB_DOTS;
            var x1 = _dotX(c); var y1 = _dotY(r); var y2 = _dotY(r + 1);
            dc.drawLine(x1 - 1, y1, x1 - 1, y2);
            dc.drawLine(x1,     y1, x1,     y2);
            dc.drawLine(x1 + 1, y1, x1 + 1, y2);
        }
    }

    // ── Dots (intersection markers) ───────────────────────────────────────
    hidden function _drawDots(dc) {
        dc.setColor(0x5A5A7A, Graphics.COLOR_TRANSPARENT);
        var r = 0;
        while (r < DB_DOTS) {
            var c = 0;
            while (c < DB_DOTS) {
                dc.fillCircle(_dotX(c), _dotY(r), _dr);
                c = c + 1;
            }
            r = r + 1;
        }
    }

    // ── HUD ───────────────────────────────────────────────────────────────
    hidden function _drawHUD(dc) {
        var ty = _sh * 2 / 100;
        if (ty < 4) { ty = 4; }

        // Current game score
        dc.setColor(0xFF2200, Graphics.COLOR_TRANSPARENT);
        dc.drawText(8, ty, Graphics.FONT_XTINY,
                    "YOU " + _pScore.format("%d"), Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(0x0099FF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_sw - 8, ty, Graphics.FONT_XTINY,
                    _aiScore.format("%d") + (_mode == MODE_PVP ? " P2" : " AI"), Graphics.TEXT_JUSTIFY_RIGHT);

        // Session wins (second line)
        var hy = ty + 14;
        dc.setColor(0xFF4422, Graphics.COLOR_TRANSPARENT);
        dc.drawText(8, hy, Graphics.FONT_XTINY,
                    "W:" + _sP.format("%d"), Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(0x2299FF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_sw - 8, hy, Graphics.FONT_XTINY,
                    _sAI.format("%d") + ":W", Graphics.TEXT_JUSTIFY_RIGHT);

        // Centre turn indicator
        if (_state == DBS_PLAYER) {
            dc.setColor(0x44FF44, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_sw / 2, ty, Graphics.FONT_XTINY,
                        "YOUR TURN", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (_state == DBS_AI) {
            if (_mode == MODE_PVP) {
                dc.setColor(0x44FF44, Graphics.COLOR_TRANSPARENT);
                dc.drawText(_sw / 2, ty, Graphics.FONT_XTINY,
                            "P2 TURN", Graphics.TEXT_JUSTIFY_CENTER);
            } else {
                dc.setColor(0x444455, Graphics.COLOR_TRANSPARENT);
                dc.drawText(_sw / 2, ty, Graphics.FONT_XTINY,
                            "AI...", Graphics.TEXT_JUSTIFY_CENTER);
            }
        }

        // Boxes-remaining count (below board, if room)
        var botY = _by + DB_BOXES * _step + _dr + 6;
        if (botY < _sh - 14) {
            var rem = DB_B - _pScore - _aiScore;
            dc.setColor(0x333348, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_sw / 2, botY, Graphics.FONT_XTINY,
                        rem.format("%d") + " left", Graphics.TEXT_JUSTIFY_CENTER);
        }
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
        if (_overType == DOV_PWIN)      { msg = (_mode == MODE_PVP) ? "P1 WINS!" : "YOU WIN!"; mc = 0xFF2200; }
        else if (_overType == DOV_AIWIN){ msg = (_mode == MODE_PVP) ? "P2 WINS!" : "AI WINS!"; mc = 0x0099FF; }
        else                            { msg = "TIE GAME!"; mc = 0xFFDD00; }
        dc.setColor(mc, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, oy + 8, Graphics.FONT_SMALL, msg, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x555566, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, oy + 38, Graphics.FONT_XTINY,
                    "YOU " + _pScore.format("%d") + " \u2013 " + _aiScore.format("%d") + " AI",
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
        dc.setColor(0xFF3355, Graphics.COLOR_TRANSPARENT);
        dc.drawText(hw, _sh * 11 / 100, Graphics.FONT_SMALL, "DOTS & BOXES", Graphics.TEXT_JUSTIFY_CENTER);
        var modeStr = (_mode == MODE_PVAI) ? "P vs AI" : ((_mode == MODE_PVP) ? "P vs P" : "AI vs AI");
        var diffStr = (_diff == DIFF_EASY) ? "Easy" : ((_diff == DIFF_MED) ? "Med" : "Hard");
        var sideStr = _playerFirst ? "Side: Blu" : "Side: Red";
        var rows = ["Mode: " + modeStr, "Diff: " + diffStr, sideStr, "START"];
        var nR = 4;
        var rowH = _sh * 10 / 100; if (rowH < 22) { rowH = 22; } if (rowH > 30) { rowH = 30; }
        var rowW = _sw * 74 / 100; var rowX = (_sw - rowW) / 2;
        var gap = 6; var tot = nR * rowH + (nR - 1) * gap; var rowY0 = (_sh - tot) / 2 + rowH;
        var i = 0;
        while (i < nR) {
            var ry = rowY0 + i * (rowH + gap); var sel = (i == _menuSel); var isStart = (i == nR - 1);
            dc.setColor(sel ? (isStart ? 0x3A0010 : 0x0A2040) : 0x0A0A0A, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(rowX, ry, rowW, rowH, 5);
            dc.setColor(sel ? (isStart ? 0xFF3355 : 0x4499FF) : 0x1A1A2A, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(rowX, ry, rowW, rowH, 5);
            if (sel) {
                dc.setColor(isStart ? 0xFF3355 : 0x4499FF, Graphics.COLOR_TRANSPARENT);
                var ay = ry + rowH / 2;
                dc.fillPolygon([[rowX + 5, ay - 4], [rowX + 5, ay + 4], [rowX + 11, ay]]);
            }
            var dimmed = (i == 1 && _mode == MODE_PVP) || (i == 2 && _mode != MODE_PVAI);
            dc.setColor(dimmed ? 0x445566 : (sel ? (isStart ? 0xFFAABB : 0xAADDFF) : 0x556677), Graphics.COLOR_TRANSPARENT);
            dc.drawText(hw, ry + (rowH - 14) / 2, Graphics.FONT_XTINY, rows[i], Graphics.TEXT_JUSTIFY_CENTER);
            i++;
        }
        dc.setColor(0x334455, Graphics.COLOR_TRANSPARENT);
        dc.drawText(hw, _sh - 14, Graphics.FONT_XTINY, "UP/DN sel  SELECT set/start", Graphics.TEXT_JUSTIFY_CENTER);
    }

    function doTap(tx, ty) {
        if (_state == GS_MENU) {
            var nR = 4;
            var rowH = _sh * 10 / 100; if (rowH < 22) { rowH = 22; } if (rowH > 30) { rowH = 30; }
            var rowW = _sw * 74 / 100; var rowX = (_sw - rowW) / 2;
            var gap = 6; var tot = nR * rowH + (nR - 1) * gap; var rowY0 = (_sh - tot) / 2 + rowH;
            for (var i = 0; i < nR; i++) {
                var ry = rowY0 + i * (rowH + gap);
                if (tx >= rowX && tx < rowX + rowW && ty >= ry && ty < ry + rowH) {
                    _menuSel = i; doAction(); return;
                }
            }
            return;
        }
        if (_state == DBS_OVER) { _state = GS_MENU; _menuSel = 0; return; }
        if (_state == DBS_AI && _mode != MODE_PVP) { return; }
        if (_step <= 0) { return; }
        // Find nearest edge midpoint.
        // Horizontal edges: idx = r*DB_BOXES+c, midpoint = (_bx+c*_step+_step/2, _by+r*_step)
        // Vertical edges:   idx = DB_H+r*DB_DOTS+c, midpoint = (_bx+c*_step, _by+r*_step+_step/2)
        var best = 0; var bestDist = 0x7FFFFFFF;
        var half = _step / 2;
        var r; var c;
        for (r = 0; r < DB_DOTS; r++) {
            for (c = 0; c < DB_BOXES; c++) {
                var mx = _bx + c * _step + half;
                var my = _by + r * _step;
                var dx2 = tx - mx; var dy2 = ty - my;
                var dist = dx2 * dx2 + dy2 * dy2;
                if (dist < bestDist) { bestDist = dist; best = r * DB_BOXES + c; }
            }
        }
        for (r = 0; r < DB_BOXES; r++) {
            for (c = 0; c < DB_DOTS; c++) {
                var mx = _bx + c * _step;
                var my = _by + r * _step + half;
                var dx2 = tx - mx; var dy2 = ty - my;
                var dist = dx2 * dx2 + dy2 * dy2;
                if (dist < bestDist) { bestDist = dist; best = DB_H + r * DB_DOTS + c; }
            }
        }
        _cursor = best;
        doAction();
    }
}
