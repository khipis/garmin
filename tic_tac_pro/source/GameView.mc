using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.Math;
using Toybox.Application;
using Toybox.Lang;

// ── Leaderboard ─────────────────────────────────────────────────────────────
const LB_GAME_ID    = "tictacpro";
const LB_STREAK_KEY = "tictacpro_streak";  // Application.Storage: consecutive wins vs AI

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

// ── 3D mode (NxNxN tic-tac-toe, N ∈ {2,3,4}) ─────────────────────────────
// Cell index: z * N*N + y * N + x   (z, y, x ∈ 0..N-1)
// Lines per cube of size N:
//   axis lines : 3 × N²        (rows + cols + verticals)
//   plane diag : 6 × N          (xy, xz, yz planes × 2 diagonals each)
//   space diag : 4
//   Total      : 3N² + 6N + 4   → N=2: 28, N=3: 49, N=4: 76
// Max lines-per-cell occurs for N=3 centre (3 axis + 6 plane + 4 space = 13).
// MAX values are used for static array sizing; live values live in class.
const N3D_MAX      = 4;
const TOTAL3D_MAX  = 64;
const LINES3D_MAX  = 76;
const MAX_LPC      = 13;

// ── GameView ───────────────────────────────────────────────────────────────────
class GameView extends WatchUi.View {

    // ── Layout ────────────────────────────────────────────────────────────
    hidden var _sw, _sh;
    hidden var _boardX, _boardY;
    hidden var _cell;

    // ── Board state ───────────────────────────────────────────────────────
    hidden var _cells;       // new [64] — works for 2D (up to 7x7=49) and 3D (4x4x4=64)
    hidden var _moveCount;
    hidden var _winLine;     // new [4]
    hidden var _gridN;       // 3..7  (in 3D mode set to 4)
    hidden var _winLen;      // 3 or 4

    // ── 3D mode ───────────────────────────────────────────────────────────
    hidden var _is3D;        // bool — when true: N×N×N cube, win along any line
    hidden var _n3D;         // active cube size 2..4 (also = win length in 3D)
    hidden var _total3D;     // _n3D ^ 3 — number of live cells
    hidden var _lines3DCnt;  // 3·N² + 6·N + 4 — number of winning lines for current N
    hidden var _lines3D;     // int[LINES3D_MAX*4] flat — line l, cell k at idx l*4+k
    hidden var _cellLinesN;  // int[TOTAL3D_MAX] — how many lines pass through cell i
    hidden var _cellLines;   // int[TOTAL3D_MAX*MAX_LPC]
    hidden var _winLine3D;   // int[4]     — cells of the winning line (3D)
    hidden var _curZ;        // 0..N-1 active layer (3D cursor depth)

    // ── Cursor ────────────────────────────────────────────────────────────
    hidden var _curX, _curY;

    // ── Game flow ─────────────────────────────────────────────────────────
    hidden var _state;
    hidden var _overType;
    hidden var _gameOverHandled;   // streak/submit done once per game-over

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

    // ── 3D Hard pick — tick-spread state ─────────────────────────────────
    // _ai3DBufI/_ai3DBufS hold top-K candidates pre-sorted by 1-ply score.
    // Each tick processes ONE candidate (fork count + opp-win check) to stay
    // well under the watchdog limit (~3K ops/tick vs ~70K in single shot).
    hidden var _ai3DBufI;      // candidate cell indices (top-K)
    hidden var _ai3DBufS;      // 1-ply score for each candidate
    hidden var _ai3DK;          // number of top candidates to evaluate

    // ─────────────────────────────────────────────────────────────────────
    function initialize() {
        View.initialize();
        _cells     = new [TOTAL3D_MAX];  // 64 — covers 2D (≤49) and 3D up to 4×4×4
        _winLine   = new [4];
        _winLine3D = new [4];
        // 3D Hard scratch buffers (pre-allocated to avoid per-move GC churn).
        _ai3DBufI  = new [TOTAL3D_MAX];
        _ai3DBufS  = new [TOTAL3D_MAX];
        _ai3DK     = 0;
        _n3D        = 4;
        _total3D    = 64;
        _lines3DCnt = 76;
        _scoreX  = 0;
        _scoreO  = 0;
        _gridN   = 5;
        _winLen  = 4;
        _is3D    = false;
        _curZ    = 0;
        _mode        = MODE_PVAI;
        _diff        = DIFF_MED;
        _menuSel     = 0;
        _playerFirst = true;
        _sw          = 0;
        _sh      = 0;
        _timer   = null;
        _gameOverHandled = false;
        _init3DTables();
        _startGame();
        _state   = GS_MENU;
    }

    // Build the winning-line tables for an N×N×N cube (N ∈ {2,3,4}).
    // Lines per cube: 3·N² (axes) + 6·N (plane diags) + 4 (space diags).
    // _lines3D[line*4 + k] = cell index for the k-th cell of that line
    //                        (lines shorter than 4 are padded with the last cell).
    // _cellLinesN[c] = number of lines through cell c; _cellLines[c*MAX_LPC+i] = line idx.
    hidden function _init3DTables() {
        var N  = _n3D;
        var N2 = N * N;
        if (_lines3D == null) {
            _lines3D    = new [LINES3D_MAX * 4];
            _cellLinesN = new [TOTAL3D_MAX];
            _cellLines  = new [TOTAL3D_MAX * MAX_LPC];
        }
        _total3D     = N * N * N;
        _lines3DCnt  = 3 * N2 + 6 * N + 4;

        var c = 0;
        while (c < _total3D) { _cellLinesN[c] = 0; c = c + 1; }

        var li = 0;
        var z; var y; var x; var k;

        // Rows  (constant z, y; x = 0..N-1)         → N² lines
        z = 0;
        while (z < N) {
            y = 0;
            while (y < N) {
                k = 0;
                while (k < N) { _lines3D[li*4+k] = z*N2 + y*N + k; k = k + 1; }
                while (k < 4) { _lines3D[li*4+k] = _lines3D[li*4 + N - 1]; k = k + 1; }
                li = li + 1;
                y = y + 1;
            }
            z = z + 1;
        }
        // Columns (constant z, x; y = 0..N-1)        → N² lines
        z = 0;
        while (z < N) {
            x = 0;
            while (x < N) {
                k = 0;
                while (k < N) { _lines3D[li*4+k] = z*N2 + k*N + x; k = k + 1; }
                while (k < 4) { _lines3D[li*4+k] = _lines3D[li*4 + N - 1]; k = k + 1; }
                li = li + 1;
                x = x + 1;
            }
            z = z + 1;
        }
        // Verticals (constant y, x; z = 0..N-1)      → N² lines
        y = 0;
        while (y < N) {
            x = 0;
            while (x < N) {
                k = 0;
                while (k < N) { _lines3D[li*4+k] = k*N2 + y*N + x; k = k + 1; }
                while (k < 4) { _lines3D[li*4+k] = _lines3D[li*4 + N - 1]; k = k + 1; }
                li = li + 1;
                x = x + 1;
            }
            y = y + 1;
        }
        // xy-plane diagonals (constant z, 2 per layer) → 2N lines
        z = 0;
        while (z < N) {
            k = 0;
            while (k < N) { _lines3D[li*4+k] = z*N2 + k*N + k; k = k + 1; }
            while (k < 4) { _lines3D[li*4+k] = _lines3D[li*4 + N - 1]; k = k + 1; }
            li = li + 1;
            k = 0;
            while (k < N) { _lines3D[li*4+k] = z*N2 + k*N + (N-1-k); k = k + 1; }
            while (k < 4) { _lines3D[li*4+k] = _lines3D[li*4 + N - 1]; k = k + 1; }
            li = li + 1;
            z = z + 1;
        }
        // xz-plane diagonals (constant y, 2 per plane) → 2N lines
        y = 0;
        while (y < N) {
            k = 0;
            while (k < N) { _lines3D[li*4+k] = k*N2 + y*N + k; k = k + 1; }
            while (k < 4) { _lines3D[li*4+k] = _lines3D[li*4 + N - 1]; k = k + 1; }
            li = li + 1;
            k = 0;
            while (k < N) { _lines3D[li*4+k] = k*N2 + y*N + (N-1-k); k = k + 1; }
            while (k < 4) { _lines3D[li*4+k] = _lines3D[li*4 + N - 1]; k = k + 1; }
            li = li + 1;
            y = y + 1;
        }
        // yz-plane diagonals (constant x, 2 per plane) → 2N lines
        x = 0;
        while (x < N) {
            k = 0;
            while (k < N) { _lines3D[li*4+k] = k*N2 + k*N + x; k = k + 1; }
            while (k < 4) { _lines3D[li*4+k] = _lines3D[li*4 + N - 1]; k = k + 1; }
            li = li + 1;
            k = 0;
            while (k < N) { _lines3D[li*4+k] = k*N2 + (N-1-k)*N + x; k = k + 1; }
            while (k < 4) { _lines3D[li*4+k] = _lines3D[li*4 + N - 1]; k = k + 1; }
            li = li + 1;
            x = x + 1;
        }
        // 4 space diagonals
        k = 0; while (k < N) { _lines3D[li*4+k] = k*N2 + k*N + k;             k = k + 1; }
        while (k < 4) { _lines3D[li*4+k] = _lines3D[li*4 + N - 1]; k = k + 1; }
        li = li + 1;
        k = 0; while (k < N) { _lines3D[li*4+k] = k*N2 + k*N + (N-1-k);       k = k + 1; }
        while (k < 4) { _lines3D[li*4+k] = _lines3D[li*4 + N - 1]; k = k + 1; }
        li = li + 1;
        k = 0; while (k < N) { _lines3D[li*4+k] = k*N2 + (N-1-k)*N + k;       k = k + 1; }
        while (k < 4) { _lines3D[li*4+k] = _lines3D[li*4 + N - 1]; k = k + 1; }
        li = li + 1;
        k = 0; while (k < N) { _lines3D[li*4+k] = k*N2 + (N-1-k)*N + (N-1-k); k = k + 1; }
        while (k < 4) { _lines3D[li*4+k] = _lines3D[li*4 + N - 1]; k = k + 1; }
        li = li + 1;

        // Build per-cell line index table.
        // We iterate cells of each line ONCE (only first N entries since
        // we padded the rest with the last cell, which would double-count).
        var l = 0;
        while (l < _lines3DCnt) {
            // Use a small "seen" trick: track unique cells per line by checking
            // the first N entries (which are the actual line cells; entries
            // N..3 are duplicates of the last for shorter lines).
            var kk = 0;
            while (kk < N) {
                var ci = _lines3D[l*4 + kk];
                var n  = _cellLinesN[ci];
                if (n < MAX_LPC) {
                    _cellLines[ci * MAX_LPC + n] = l;
                    _cellLinesN[ci] = n + 1;
                }
                kk = kk + 1;
            }
            l = l + 1;
        }
    }

    function onLayout(dc) {
        _sw = dc.getWidth();
        _sh = dc.getHeight();
        _calcLayout();
    }

    function onShow() {
        if (_timer == null) { _timer = new Timer.Timer(); }
        _timer.start(method(:gameTick), 300, true);
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); }
    }

    // ── Layout helper ─────────────────────────────────────────────────────
    hidden function _calcLayout() {
        if (_sw == 0) { return; }
        var minDim = (_sw < _sh) ? _sw : _sh;
        if (_is3D) {
            // Isometric stacked-boards view (like classic 3D tic-tac-toe drawings).
            // Each layer is rendered as a parallelogram (tilted square) and the
            // _n3D layers are stacked vertically with a gap between them so all
            // boards stay fully visible.
            //
            // Per cell unit c:
            //   sx = c (horizontal half-width of one cell in iso projection)
            //   sy = c * 3 / 7  (vertical half-height — shallow tilt for legibility)
            // Each board diamond width  = 2·N·sx = 2Nc
            //              height = 2·N·sy ≈ 0.86·N·c
            // Layer vertical stride (incl. gap): boardH + gap, where
            //   gap = max( c, boardH / 3 )  → clear separation
            //
            // Total bounding box:
            //   width  = 2·N·sx
            //   height = boardH + (Nz-1)·stride  where stride = boardH + gap
            //
            // Solve for c so total fits in (minDim*92)% × available height.
            var N  = _n3D;
            var Nz = _n3D;
            // Try a generous cell size first; shrink until the stack fits.
            var c = minDim / (2 * N);             // upper bound: full width
            // Compute heights assuming sy = c·3/7, gap = boardH/3
            //   boardH = 2·N·(c·3/7) = 6Nc/7
            //   stride = boardH + gap = boardH·4/3 = 8Nc/7
            //   totalH = boardH + (Nz-1)·stride = (6 + 8·(Nz-1)) · N·c / 7
            // Limit: totalH ≤ minDim·78/100  (leave room for HUD top + hint bottom)
            //   c ≤ minDim · 78 · 7 / ( 100 · N · (6 + 8·(Nz-1)) )
            var maxH = minDim * 78 / 100;
            var denomH = N * (6 + 8 * (Nz - 1));
            var cH = (maxH * 7) / denomH;
            if (cH < c) { c = cH; }
            // Width limit: 2Nc ≤ minDim·92/100  → c ≤ minDim·46/(100·N)
            var cW = minDim * 46 / (100 * N);
            if (cW < c) { c = cW; }
            if (c < 5) { c = 5; }
            _cell = c;
            var boardH = 2 * N * c * 3 / 7;
            var stride = boardH * 4 / 3;
            var totalW = 2 * N * c;
            var totalH = boardH + (Nz - 1) * stride;
            _boardX = (_sw - totalW) / 2 + N * c;   // anchor at top centre of first diamond
            _boardY = (_sh - totalH) / 2;
            if (_boardY < 18) { _boardY = 18; }
            return;
        }
        _cell   = minDim * 68 / (100 * _gridN);
        _boardX = (_sw - _gridN * _cell) / 2;
        _boardY = (_sh - _gridN * _cell) / 2 - _sh * 3 / 100;
        if (_boardY < 18) { _boardY = 18; }
    }

    // ── Public input API ──────────────────────────────────────────────────

    // advance cursor in reading order: right → next row → wrap
    // onNextPage (DOWN-RIGHT swipe button): in 2D move RIGHT;
    // in 3D move RIGHT and cycle Z layer when wrapping.
    function advanceCursor() {
        if (_state == GS_MENU) {
            _menuSel = (_menuSel + 1) % 6;
            WatchUi.requestUpdate();
            return;
        }
        if (_mode == MODE_AIAI) { return; }
        if (_state != GS_PLAY && !(_state == GS_AI && _mode == MODE_PVP)) { return; }
        if (_is3D) {
            var N = _n3D; var N2 = N * N;
            var idx = _curZ * N2 + _curY * N + _curX;
            idx = (idx + 1) % _total3D;
            _curZ = idx / N2; var rem = idx % N2; _curY = rem / N; _curX = rem % N;
        } else {
            _curX = (_curX + 1) % _gridN;
        }
        WatchUi.requestUpdate();
    }

    // onPreviousPage (DOWN-LEFT swipe button): in 2D move DOWN;
    // in 3D — cycle through Z layers (rotates active layer).
    function retreatCursor() {
        if (_state == GS_MENU) {
            _menuSel = (_menuSel + 5) % 6;
            WatchUi.requestUpdate();
            return;
        }
        if (_mode == MODE_AIAI) { return; }
        if (_state != GS_PLAY && !(_state == GS_AI && _mode == MODE_PVP)) { return; }
        if (_is3D) {
            _curZ = (_curZ + 1) % _n3D;
        } else {
            _curY = (_curY + 1) % _gridN;
        }
        WatchUi.requestUpdate();
    }

    // move cursor up/down one row, same column, wrapping
    function moveCursorRow(delta) {
        if (_state == GS_MENU) {
            _menuSel = (_menuSel + 6 + delta) % 6;
            WatchUi.requestUpdate();
            return;
        }
        if (_mode == MODE_AIAI) { return; }
        if (_state != GS_PLAY && !(_state == GS_AI && _mode == MODE_PVP)) { return; }
        if (_is3D) {
            // delta -1 → up: cycle Z; delta +1 → down: cycle within layer
            if (delta < 0) { _curZ = (_curZ + _n3D - 1) % _n3D; }
            else {
                _curY = _curY + 1;
                if (_curY >= _n3D) { _curY = 0; }
            }
        } else {
            _curY = _curY + delta;
            if (_curY < 0)        { _curY = _gridN - 1; }
            if (_curY >= _gridN)  { _curY = 0; }
        }
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

        var curIdx = _is3D ? (_curZ * _n3D * _n3D + _curY * _n3D + _curX)
                           : (_curY * _gridN + _curX);
        var totalCells = _is3D ? _total3D : (_gridN * _gridN);

        // PvP: GS_AI = O's turn (P2 places O)
        if (_state == GS_AI && _mode == MODE_PVP) {
            if (_cells[curIdx] != MARK_NONE) { return; }
            _place(_curX, _curY, MARK_O);
            if (_checkWin(MARK_O)) {
                _overType = OVER_OWIN; _scoreO = _scoreO + 1; _state = GS_OVER;
                WatchUi.requestUpdate(); return;
            }
            if (_moveCount == totalCells) {
                _overType = OVER_DRAW; _state = GS_OVER;
                WatchUi.requestUpdate(); return;
            }
            _state = GS_PLAY;
            WatchUi.requestUpdate();
            return;
        }

        // PvAI player goes second: GS_AI = player's turn (player places O)
        if (_state == GS_AI && _mode == MODE_PVAI && !_playerFirst) {
            if (_cells[curIdx] != MARK_NONE) { return; }
            _place(_curX, _curY, MARK_O);
            if (_checkWin(MARK_O)) {
                _overType = OVER_OWIN; _scoreO = _scoreO + 1; _state = GS_OVER;
                WatchUi.requestUpdate(); return;
            }
            if (_moveCount == totalCells) {
                _overType = OVER_DRAW; _state = GS_OVER;
                WatchUi.requestUpdate(); return;
            }
            _state = GS_PLAY;
            WatchUi.requestUpdate();
            return;
        }

        if (_state != GS_PLAY) { return; }
        if (_cells[curIdx] != MARK_NONE) { return; }

        _place(_curX, _curY, MARK_X);
        if (_checkWin(MARK_X)) {
            _overType = OVER_XWIN; _scoreX = _scoreX + 1; _state = GS_OVER;
            WatchUi.requestUpdate(); return;
        }
        if (_moveCount == totalCells) {
            _overType = OVER_DRAW; _state = GS_OVER;
            WatchUi.requestUpdate(); return;
        }
        _state = GS_AI;
        WatchUi.requestUpdate();
    }

    // ── Menu action ───────────────────────────────────────────────────────
    // Grid cycle: 3 → 4 → 5 → 6 → 7 → 3D(2×2×2) → 3D(3×3×3) → 3D(4×4×4) → 3
    hidden function _menuAction() {
        if (_menuSel == 0) {
            _mode = (_mode + 1) % 3;
        } else if (_menuSel == 1) {
            if (_mode != MODE_PVP) { _diff = (_diff + 1) % 3; }
        } else if (_menuSel == 2) {
            if (_is3D) {
                if (_n3D < 4) {
                    _n3D = _n3D + 1;
                    _total3D = _n3D * _n3D * _n3D;
                    _winLen  = _n3D;
                    _init3DTables();
                } else {
                    // exit 3D, back to flat 3×3
                    _is3D = false;
                    _gridN = 3;
                    _winLen = 3;
                }
            } else if (_gridN >= 7) {
                _is3D   = true;
                _n3D    = 2;
                _total3D = 8;
                _gridN  = _n3D;     // for centre/cursor defaults
                _winLen = _n3D;
                _init3DTables();
            } else {
                _gridN = _gridN + 1;
                _winLen = (_gridN == 3) ? 3 : 4;
            }
        } else if (_menuSel == 3) {
            if (_mode == MODE_PVAI) { _playerFirst = !_playerFirst; }
        } else if (_menuSel == 4) {
            _startGame();
        } else {
            openLeaderboard();
        }
    }

    // ── Leaderboard ───────────────────────────────────────────────────────
    // Variant = current AI difficulty (the win-streak is "vs AI", so each
    // difficulty keeps its own ranking). Same expression is used on submit.
    function variant() {
        return (_diff == DIFF_EASY) ? "Easy" : ((_diff == DIFF_MED) ? "Med" : "Hard");
    }

    function openLeaderboard() {
        var v = new LbScoresView(LB_GAME_ID, variant(), "TIC-TAC PRO");
        WatchUi.pushView(v, new LbScoresDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // Called once when a game reaches GS_OVER. Tracks the consecutive-win
    // streak vs the AI (PvAI only): increment + submit on a player win,
    // reset to 0 on a loss or draw.
    hidden function _handleGameOver() {
        _gameOverHandled = true;
        if (_mode != MODE_PVAI) { return; }
        var playerWon = (_playerFirst && _overType == OVER_XWIN) ||
                        (!_playerFirst && _overType == OVER_OWIN);
        if (playerWon) {
            var stored = Application.Storage.getValue(LB_STREAK_KEY);
            var streak = (stored instanceof Lang.Number) ? stored : 0;
            streak = streak + 1;
            Application.Storage.setValue(LB_STREAK_KEY, streak);
            Leaderboard.submitScore(LB_GAME_ID, streak, variant());
            Leaderboard.showPostGame(LB_GAME_ID, variant(), "TIC-TAC PRO");
        } else {
            Application.Storage.setValue(LB_STREAK_KEY, 0);
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

        if (_is3D) {
            var w3 = _findThreat3D(mark);
            if (w3 >= 0) { _aiFinish3D(w3, mark); return; }
            w3 = _findThreat3D(opp);
            if (w3 >= 0) { _aiFinish3D(w3, mark); return; }
            // 3D: 1-ply line-score for Easy/Med (cheap, one tick).
            // Hard: spread over multiple ticks via GS_AI_FORK (3D branch).
            if (_diff == DIFF_HARD) {
                _ai3D_HardSetup(mark, opp);
                if (_ai3DK == 0) {
                    var fallback = _ai3D_1Ply(mark, opp);
                    if (fallback >= 0) { _aiFinish3D(fallback, mark); }
                    return;
                }
                _aiForkAiMk   = mark;
                _aiForkI      = 0;
                _aiForkResult = _ai3DBufI[0];
                _aiForkBest   = -999999;
                _state        = GS_AI_FORK;
                return;
            }
            var pick = _ai3D_1Ply(mark, opp);
            if (pick >= 0) { _aiFinish3D(pick, mark); }
            return;
        }

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
        // Med/Hard: 2-ply threat-aware search spread across ticks (batch=3).
        // Works for all grid sizes including 3×3 — avoids watchdog from deep recursion.
        _aiForkAiMk  = mark;
        _aiForkI     = 0;
        _aiForkResult = -1;
        _aiForkBest  = -999999;
        _state = GS_AI_FORK;
    }

    // 3D — find an empty cell where placing 'col' wins immediately.
    hidden function _findThreat3D(col) {
        var i = 0;
        while (i < _total3D) {
            if (_cells[i] == MARK_NONE) {
                _cells[i] = col;
                if (_checkWinAt3D(col, i)) { _cells[i] = MARK_NONE; return i; }
                _cells[i] = MARK_NONE;
            }
            i = i + 1;
        }
        return -1;
    }

    // 3D 1-ply scoring — for each empty cell, sum line scores through it.
    // Line score: own count^3 (offense), opp count^3 weighted (defense).
    // Also strong centre bias (closer to (1.5,1.5,1.5) is better).
    hidden function _ai3D_1Ply(mark, opp) {
        var best = -999999;
        var bestI = -1;
        var i = 0;
        while (i < _total3D) {
            if (_cells[i] == MARK_NONE) {
                var sc = _scoreCell3D(i, mark, opp);
                sc = sc + Math.rand() % 5;
                if (sc > best) { best = sc; bestI = i; }
            }
            i = i + 1;
        }
        return bestI;
    }

    // 3D cell heuristic — sum of line evaluations through this cell.
    hidden function _scoreCell3D(idx, mark, opp) {
        var N  = _n3D;
        var N2 = N * N;
        var n  = _cellLinesN[idx];
        var sc = 0;
        var i  = 0;
        while (i < n) {
            var l = _cellLines[idx * MAX_LPC + i];
            var base = l * 4;
            var own = 0; var en = 0;
            // Iterate only the N real cells of the line; cells N..3 are
            // padded duplicates of cell N-1 (skip them so they aren't double-counted).
            var k = 0;
            while (k < N) {
                var v = _cells[_lines3D[base+k]];
                if      (v == mark) { own = own + 1; }
                else if (v == opp)  { en  = en  + 1; }
                k = k + 1;
            }
            if (en == 0 && own > 0) { sc = sc + (own + 1) * (own + 1) * (own + 1); }
            else if (own == 0 && en > 0) { sc = sc + en * en * en * 2; }
            // contested → no value
            i = i + 1;
        }
        // Centre bias: reward cells inside the symmetric centre band.
        // For N=2 band = {0,1} (no bias); N=3 band = {1}; N=4 band = {1,2}.
        var z = idx / N2; var rem = idx % N2; var y = rem / N; var x = rem % N;
        var lo = (N - 1) / 2; var hi = N / 2;
        var dx = (x < lo) ? lo - x : ((x > hi) ? x - hi : 0);
        var dy = (y < lo) ? lo - y : ((y > hi) ? y - hi : 0);
        var dz = (z < lo) ? lo - z : ((z > hi) ? z - hi : 0);
        var nearness = (N - dx) + (N - dy) + (N - dz);
        sc = sc + nearness * 3;
        return sc;
    }

    // 3D Hard — phase 1 (CHEAP, runs in one tick):
    // gather all legal cells, score them with the fast 1-ply heuristic, and
    // partial-sort the top-K candidates into _ai3DBufI/_ai3DBufS.
    //
    // Cost: _total3D × (~35 ops _scoreCell3D) + K^2/2 sort ≈ 2.2K + 30 ≈ 2.3K ops.
    // K kept small (6) because each tick of _ai3D_HardStep is the expensive part.
    hidden function _ai3D_HardSetup(mark, opp) {
        var nC = 0;
        var i = 0;
        while (i < _total3D) {
            if (_cells[i] == MARK_NONE) {
                _ai3DBufI[nC] = i;
                _ai3DBufS[nC] = _scoreCell3D(i, mark, opp);
                nC = nC + 1;
            }
            i = i + 1;
        }
        // Top-6 (small K so per-move ticks stay within ~2s of "thinking")
        var K = (nC < 6) ? nC : 6;
        _ai3DK = K;
        var s = 0;
        while (s < K) {
            var bj = s; var bv = _ai3DBufS[s];
            var j = s + 1;
            while (j < nC) {
                if (_ai3DBufS[j] > bv) { bv = _ai3DBufS[j]; bj = j; }
                j = j + 1;
            }
            if (bj != s) {
                var t = _ai3DBufI[s]; _ai3DBufI[s] = _ai3DBufI[bj]; _ai3DBufI[bj] = t;
                var u = _ai3DBufS[s]; _ai3DBufS[s] = _ai3DBufS[bj]; _ai3DBufS[bj] = u;
            }
            s = s + 1;
        }
    }

    // 3D Hard — phase 2: evaluate ONE candidate per timer tick.
    // Per-tick cost (worst case, empty-ish board):
    //   fork count : ~63 × ~28 ops (_checkWinAt3D, with early-exit at 2)  ≈ 1.8K
    //   opp-win    : ~63 × ~28 ops (early-exit on first opp threat)        ≈ 1.8K
    //   total      : ~3.6K ops — safely under any device's watchdog limit.
    // Called from _aiForkStep when _is3D && _diff == DIFF_HARD.
    hidden function _ai3D_HardStep() {
        var mark = _aiForkAiMk;
        var opp  = (mark == MARK_X) ? MARK_O : MARK_X;
        var k    = _aiForkI;

        if (k >= _ai3DK) {
            // All candidates evaluated — commit the best move we found.
            if (_aiForkResult >= 0) { _aiFinish3D(_aiForkResult, mark); }
            else { _state = (mark == MARK_O) ? GS_PLAY : GS_AI; }
            return;
        }

        var mv = _ai3DBufI[k];
        _cells[mv] = mark;

        // Take the win if available.
        if (_checkWinAt3D(mark, mv)) {
            _cells[mv] = MARK_NONE;
            _aiFinish3D(mv, mark);
            return;
        }

        // Count own threats (fork detect, early-exit at 2 — that's all we need).
        var threats = 0;
        var p = 0;
        while (p < _total3D && threats < 2) {
            if (_cells[p] == MARK_NONE) {
                _cells[p] = mark;
                if (_checkWinAt3D(mark, p)) { threats = threats + 1; }
                _cells[p] = MARK_NONE;
            }
            p = p + 1;
        }

        // Check whether opponent has an immediate winning reply (early-exit).
        var oppCanWin = false;
        p = 0;
        while (p < _total3D) {
            if (_cells[p] == MARK_NONE) {
                _cells[p] = opp;
                if (_checkWinAt3D(opp, p)) { oppCanWin = true; _cells[p] = MARK_NONE; break; }
                _cells[p] = MARK_NONE;
            }
            p = p + 1;
        }
        _cells[mv] = MARK_NONE;

        if (!oppCanWin) {
            var forkBonus = (threats >= 2) ? 8000 : ((threats == 1) ? 300 : 0);
            var delta = _ai3DBufS[k] * 10 + forkBonus;
            if (delta > _aiForkBest) {
                _aiForkBest   = delta;
                _aiForkResult = mv;
            }
        }
        // If oppCanWin: candidate is bad (opp wins next turn), skip — keep
        // previous best. _aiForkResult was pre-seeded with top-1 candidate
        // so we always have a fallback.

        _aiForkI = k + 1;
    }

    // Apply 3D move and update state.
    hidden function _aiFinish3D(cellIdx, mark) {
        _place3D(cellIdx, mark);
        if (_checkWin3D(mark)) {
            if (mark == MARK_X) { _overType = OVER_XWIN; _scoreX = _scoreX + 1; }
            else                { _overType = OVER_OWIN; _scoreO = _scoreO + 1; }
            _state = GS_OVER;
        } else if (_moveCount == _total3D) {
            _overType = OVER_DRAW; _state = GS_OVER;
        } else {
            _state = (mark == MARK_O) ? GS_PLAY : GS_AI;
        }
    }

    // Processes outer iterations per tick (2-ply threat-aware search).
    //
    // Watchdog budget analysis (N=7, winLen=4):
    //   _scoreCell (outer) : 8 × _axisPotential(~100)     ≈   800 ops
    //   inner loop         : N²×(_checkWinAt(~72)+center(~8)) ≈ 49×80 = 3920 ops
    //   per tick (batch=3) : 3 × (800 + 3920)             ≈ 14 160 ops — safe
    //
    // NOTE: 3×3 used to run full negamax (recursive _negamax3) in one tick,
    // but on the first move that's ~1M ops (deep recursion × _findThreat overhead)
    // which trips the watchdog. Using the same batch=3 / 2-ply path as larger grids
    // fixes the crash; the AI still plays well on 3×3 with 2-ply.
    hidden function _aiForkStep() {
        // 3D Hard runs via _ai3D_HardStep (one candidate per tick).
        if (_is3D) { _ai3D_HardStep(); return; }
        var mark  = _aiForkAiMk;
        var opp   = (mark == MARK_X) ? MARK_O : MARK_X;
        var total = _gridN * _gridN;
        var batch = 3;
        var mid   = _gridN / 2;
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
                } else {
                    // 2-ply: score own move with full heuristic; check opp wins and
                    // use cheap center score for opp reply (avoids watchdog on 7×7).
                    var myHeur = _scoreCell(_aiForkI, mark);
                    var oppWins = 0; var oppBest = -99999; var j = 0;
                    while (j < total) {
                        if (_cells[j] == MARK_NONE) {
                            _cells[j] = opp;
                            var oppWin = _checkWinAt(opp, j % _gridN, j / _gridN);
                            if (oppWin) {
                                oppWins = oppWins + 1;
                            } else {
                                // Cheap center-distance proxy (~8 ops vs ~800 for full _scoreCell)
                                var jx = j % _gridN; var jy = j / _gridN;
                                var jdx = jx - mid; if (jdx < 0) { jdx = -jdx; }
                                var jdy = jy - mid; if (jdy < 0) { jdy = -jdy; }
                                var os = (_gridN - jdx - jdy) * 4;
                                if (os > oppBest) { oppBest = os; }
                            }
                            _cells[j] = MARK_NONE;
                        }
                        j = j + 1;
                    }
                    // Heavy penalty if opp can win; otherwise 2-ply score difference
                    if (oppWins >= 2) {
                        sc = myHeur - 5000;
                    } else if (oppWins == 1) {
                        sc = myHeur - 2000;
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
        var total = _is3D ? _total3D : (_gridN * _gridN);
        var i = 0;
        while (i < total) { _cells[i] = MARK_NONE; i = i + 1; }
        i = 0;
        while (i < 4) { _winLine[i] = -1; _winLine3D[i] = -1; i = i + 1; }
        _moveCount = 0;
        _gameOverHandled = false;
        if (_is3D) {
            _curX = _n3D / 2; _curY = _n3D / 2;
        } else {
            _curX = _gridN / 2; _curY = _gridN / 2;
        }
        _curZ      = 0;
        _overType  = OVER_NONE;
        if (_mode == MODE_PVAI && !_playerFirst) {
            _state = GS_AI;
        } else {
            _state = GS_PLAY;
        }
    }

    hidden function _place(x, y, mark) {
        if (_is3D) {
            var N = _n3D;
            _cells[_curZ * N * N + y * N + x] = mark;
        } else {
            _cells[y * _gridN + x] = mark;
        }
        _moveCount = _moveCount + 1;
    }

    // Place by absolute 3D cell index.
    hidden function _place3D(cellIdx, mark) {
        _cells[cellIdx] = mark;
        _moveCount = _moveCount + 1;
    }

    // ── Win detection ─────────────────────────────────────────────────────
    // 3D win check: scan all lines (length-padded to 4); populate _winLine3D.
    hidden function _checkWin3D(col) {
        var l = 0;
        while (l < _lines3DCnt) {
            var base = l * 4;
            if (_cells[_lines3D[base]]   == col &&
                _cells[_lines3D[base+1]] == col &&
                _cells[_lines3D[base+2]] == col &&
                _cells[_lines3D[base+3]] == col) {
                _winLine3D[0] = _lines3D[base];
                _winLine3D[1] = _lines3D[base+1];
                _winLine3D[2] = _lines3D[base+2];
                _winLine3D[3] = _lines3D[base+3];
                return true;
            }
            l = l + 1;
        }
        return false;
    }

    // 3D fast win check at a specific cell: only scan lines through that cell.
    hidden function _checkWinAt3D(col, cellIdx) {
        var n = _cellLinesN[cellIdx];
        var i = 0;
        while (i < n) {
            var l = _cellLines[cellIdx * MAX_LPC + i];
            var base = l * 4;
            if (_cells[_lines3D[base]]   == col &&
                _cells[_lines3D[base+1]] == col &&
                _cells[_lines3D[base+2]] == col &&
                _cells[_lines3D[base+3]] == col) {
                return true;
            }
            i = i + 1;
        }
        return false;
    }

    hidden function _checkWin(col) {
        if (_is3D) { return _checkWin3D(col); }
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
        var total = _gridN * _gridN; var mid = _gridN / 2; var i = 0;
        // For N≥6: N²×_scoreCell ≈ 49×800 = ~39K ops — trips watchdog.
        // Use cheap center score for large grids; full _scoreCell for N≤5.
        var cheapOnly = (_gridN >= 6);
        while (i < total) {
            if (_cells[i] != MARK_NONE) { i = i + 1; continue; }
            var s;
            if (cheapOnly) {
                var ix = i % _gridN; var iy = i / _gridN;
                var ddx = ix - mid; if (ddx < 0) { ddx = -ddx; }
                var ddy = iy - mid; if (ddy < 0) { ddy = -ddy; }
                s = (_gridN - ddx - ddy) * 4 + Math.rand() % 5;
            } else {
                s = _scoreCell(i, mark);
            }
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
        if (_state == GS_OVER && !_gameOverHandled) { _handleGameOver(); }
        if (_state == GS_MENU) { _drawMenu(dc); return; }
        dc.setColor(0x080810, 0x080810);
        dc.clear();
        if (_is3D) { _drawBoard3D(dc); }
        else       { _drawBoard(dc); }
        _drawHUD(dc);
        if (_state == GS_OVER) { _drawGameOver(dc); }
    }

    // ── 3D board: N×N×N cube drawn as a vertical stack of isometric ─────
    //              parallelogram boards (classic 3D tic-tac-toe layout).
    //
    // Each layer is a tilted square (diamond) projected via:
    //     scrX = anchorX + (gx - gy) * sx
    //     scrY = anchorY + (gx + gy) * sy + z * stride
    // where sx = _cell, sy = _cell·3/7 and stride = boardH·4/3.
    //
    // _boardX / _boardY mark the TOP vertex of the topmost diamond (z = 0).
    // Successive layers (z = 1, 2, …) are drawn straight below with a gap so
    // every board stays fully visible — exactly as in the reference image.
    hidden function _drawBoard3D(dc) {
        var N      = _n3D;
        var sx     = _cell;
        var sy     = _cell * 3 / 7;        if (sy < 2) { sy = 2; }
        var boardH = 2 * N * sy;
        var stride = boardH * 4 / 3;

        // Draw layers top-down so cursor / marks on lower boards naturally
        // sit on top (they don't overlap with the way layers are spaced).
        var z = 0;
        while (z < N) {
            var yOff = z * stride;
            _drawIsoLayer(dc, z, sx, sy, yOff);
            z = z + 1;
        }
    }

    // Draw a single isometric N×N board at vertical offset yOff.
    hidden function _drawIsoLayer(dc, z, sx, sy, yOff) {
        var N    = _n3D;
        var ax   = _boardX;
        var ay   = _boardY + yOff;
        var isCur = (z == _curZ);

        // Highlight tint for the active layer (slightly brighter grid lines)
        var gridCol = isCur ? 0xD8D8E0 : 0x8888A0;
        var bgCol   = isCur ? 0x141828 : 0x0C0E1C;

        // Compute the 4 corner points of the diamond
        // (gx,gy) =  (0,0) top, (N,0) right, (N,N) bottom, (0,N) left.
        var tx = ax;                   var ty = ay;
        var rx = ax + N * sx;          var ry = ay + N * sy;
        var bx = ax;                   var by = ay + 2 * N * sy;
        var lx = ax - N * sx;          var ly = ay + N * sy;

        // Filled background diamond for contrast (helps marks pop)
        var poly = [ [tx,ty], [rx,ry], [bx,by], [lx,ly] ];
        dc.setColor(bgCol, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(poly);

        // Win-line highlight: tint cells that belong to the winning line.
        if (_state == GS_OVER && (_overType == OVER_XWIN || _overType == OVER_OWIN)) {
            var N2 = N * N;
            dc.setColor(0x114433, Graphics.COLOR_TRANSPARENT);
            var iy = 0;
            while (iy < N) {
                var ix = 0;
                while (ix < N) {
                    var idx = z * N2 + iy * N + ix;
                    if (_inWinLine3D(idx)) {
                        _fillIsoCell(dc, ix, iy, sx, sy, ax, ay);
                    }
                    ix = ix + 1;
                }
                iy = iy + 1;
            }
        }

        // Grid lines (N+1 in each of the two diagonal directions).
        dc.setColor(gridCol, Graphics.COLOR_TRANSPARENT);
        var k = 0;
        while (k <= N) {
            // "row" line constant gy = k, gx 0..N
            //   from (0, k) → ( -k*sx, ay + k*sy )
            //   to   (N, k) → ( (N-k)*sx, ay + (N+k)*sy )
            dc.drawLine(ax - k * sx,        ay + k * sy,
                        ax + (N - k) * sx,  ay + (N + k) * sy);
            // "col" line constant gx = k, gy 0..N
            //   from (k, 0) → ( k*sx, ay + k*sy )
            //   to   (k, N) → ( (k-N)*sx, ay + (k+N)*sy )
            dc.drawLine(ax + k * sx,        ay + k * sy,
                        ax + (k - N) * sx,  ay + (k + N) * sy);
            k = k + 1;
        }

        // Layer label (top-left of each board)
        dc.setColor(isCur ? 0xFFCC44 : 0x556677, Graphics.COLOR_TRANSPARENT);
        dc.drawText(lx - 4, ay + N * sy - 8, Graphics.FONT_XTINY,
                    "Z" + z.format("%d"), Graphics.TEXT_JUSTIFY_RIGHT);

        // Marks + cursor
        var N2b = N * N;
        var iy2 = 0;
        while (iy2 < N) {
            var ix2 = 0;
            while (ix2 < N) {
                // Cell centre: (ix+0.5, iy+0.5)
                var cx = ax + (ix2 - iy2) * sx;        // (gx - gy)*sx + ax
                var cy = ay + (ix2 + iy2 + 1) * sy;    // (gx + gy)*sy + ay  (with +1 for +0.5+0.5)
                var idx = z * N2b + iy2 * N + ix2;
                var v   = _cells[idx];
                if      (v == MARK_X) { _drawX(dc, cx, cy); }
                else if (v == MARK_O) { _drawO(dc, cx, cy); }
                ix2 = ix2 + 1;
            }
            iy2 = iy2 + 1;
        }

        // Active-layer cursor (drawn on top of the marks)
        if (isCur) {
            var occ = (_cells[z * N2b + _curY * N + _curX] != MARK_NONE);
            dc.setColor(occ ? 0xFF6600 : 0xFFFF00, Graphics.COLOR_TRANSPARENT);
            // Cursor cell parallelogram corners
            var cx0 = ax + (_curX     - _curY    ) * sx;
            var cy0 = ay + (_curX     + _curY    ) * sy;
            var cx1 = ax + (_curX + 1 - _curY    ) * sx;
            var cy1 = ay + (_curX + 1 + _curY    ) * sy;
            var cx2 = ax + (_curX + 1 - _curY - 1) * sx;
            var cy2 = ay + (_curX + 1 + _curY + 1) * sy;
            var cx3 = ax + (_curX     - _curY - 1) * sx;
            var cy3 = ay + (_curX     + _curY + 1) * sy;
            dc.drawLine(cx0, cy0, cx1, cy1);
            dc.drawLine(cx1, cy1, cx2, cy2);
            dc.drawLine(cx2, cy2, cx3, cy3);
            dc.drawLine(cx3, cy3, cx0, cy0);
        }
    }

    // Fill a single iso parallelogram cell at grid coords (ix, iy).
    // Corners: (ix,iy) top-left, (ix+1,iy) top-right,
    //          (ix+1,iy+1) bottom-right, (ix,iy+1) bottom-left.
    hidden function _fillIsoCell(dc, ix, iy, sx, sy, ax, ay) {
        var tlx = ax + (ix     - iy    ) * sx; var tly = ay + (ix     + iy    ) * sy;
        var trx = ax + (ix + 1 - iy    ) * sx; var tryy= ay + (ix + 1 + iy    ) * sy;
        var brx = ax + (ix     - iy    ) * sx; var bry = ay + (ix     + iy + 2) * sy;
        var blx = ax + (ix - 1 - iy    ) * sx; var bly = ay + (ix - 1 + iy + 2) * sy;
        dc.fillPolygon([ [tlx,tly], [trx,tryy], [brx,bry], [blx,bly] ]);
    }

    hidden function _inWinLine3D(idx) {
        return (_winLine3D[0] == idx || _winLine3D[1] == idx ||
                _winLine3D[2] == idx || _winLine3D[3] == idx);
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

        // Hint below board — for 3D, place it under the bottom diamond.
        var hintY;
        if (_is3D) {
            var sy = _cell * 3 / 7; if (sy < 2) { sy = 2; }
            var boardH = 2 * _n3D * sy;
            var stride = boardH * 4 / 3;
            hintY = _boardY + boardH + (_n3D - 1) * stride + 4;
        } else {
            hintY = _boardY + _gridN * _cell + 8;
        }
        if (hintY < _sh - 14) {
            dc.setColor(0x222233, Graphics.COLOR_TRANSPARENT);
            var hint = _is3D ? "UP=Z  DN=next  SEL=place" : "DN=next  UP=down  SEL=place";
            dc.drawText(_sw / 2, hintY, Graphics.FONT_XTINY, hint, Graphics.TEXT_JUSTIFY_CENTER);
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
        dc.drawText(hw, _sh * 15 / 100, Graphics.FONT_SMALL,
                    "TIC TAC PRO", Graphics.TEXT_JUSTIFY_CENTER);

        var modeStr = (_mode == MODE_PVAI) ? "P vs AI" : ((_mode == MODE_PVP) ? "P vs P" : "AI vs AI");
        var diffStr = (_diff == DIFF_EASY) ? "Easy" : ((_diff == DIFF_MED) ? "Med" : "Hard");
        var gridStr = _is3D ? ("3D " + _n3D + "x" + _n3D + "x" + _n3D)
                            : ("" + _gridN + "x" + _gridN);
        var sideStr = _playerFirst ? "Side: X" : "Side: O";
        var rows = ["Mode: " + modeStr, "Diff: " + diffStr, "Grid: " + gridStr, sideStr, "START"];
        var nR   = 6;   // 5 settings/START rows + LEADERBOARD
        // ~18% smaller than the old 5-row sizing so all 6 rows fit (incl. round watches).
        var rowH = _sh * 74 / 1000; if (rowH < 16) { rowH = 16; } if (rowH > 23) { rowH = 23; }
        var rowW = _sw * 68 / 100;
        var rowX = (_sw - rowW) / 2;
        var gap  = _sh * 14 / 1000; if (gap < 3) { gap = 3; }
        var tot  = nR * rowH + (nR - 1) * gap;
        var rowY0 = (_sh - tot) / 2 + rowH / 2;
        var i = 0;
        while (i < nR) {
            var ry     = rowY0 + i * (rowH + gap);
            var sel    = (i == _menuSel);
            if (i == 5) {
                // Gold "LEADERBOARD" row from the shared library.
                LbBadge.drawRow(dc, rowX, ry, rowW, rowH, sel);
                i++;
                continue;
            }
            var isStart = (i == 4);
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
            var gap  = _sh * 14 / 1000; if (gap < 3) { gap = 3; }
            var rowH = _sh * 74 / 1000; if (rowH < 16) { rowH = 16; } if (rowH > 23) { rowH = 23; }
            var rowW = _sw * 68 / 100;
            var rowX = (_sw - rowW) / 2;
            var nR = 6;
            var tot  = nR * rowH + (nR - 1) * gap;
            var rowY0 = (_sh - tot) / 2 + rowH / 2;
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

        if (_is3D) {
            // Iso-stacked layout: inverse-project tap into (gx, gy, z).
            //  Forward: scrX = anchorX + (gx - gy)·sx
            //           scrY = anchorY + (gx + gy)·sy   (anchorY = boardY + z·stride)
            //  Solve for gx, gy:
            //    gx = (u/sx + v/sy) / 2
            //    gy = (v/sy - u/sx) / 2
            //  with u = scrX - anchorX, v = scrY - anchorY.
            var N = _n3D;
            var sx = _cell;
            var sy = _cell * 3 / 7; if (sy < 2) { sy = 2; }
            var boardH = 2 * N * sy;
            var stride = boardH * 4 / 3;
            var z = 0;
            while (z < N) {
                var ay = _boardY + z * stride;
                if (ty >= ay && ty <= ay + boardH) {
                    var u = tx - _boardX;
                    var v = ty - ay;
                    // Compute in floats so we can floor correctly for both signs
                    var fx = (u.toFloat() / sx + v.toFloat() / sy) / 2.0;
                    var fy = (v.toFloat() / sy - u.toFloat() / sx) / 2.0;
                    var gx = fx.toNumber();
                    var gy = fy.toNumber();
                    if (fx < 0) { gx = gx - 1; }
                    if (fy < 0) { gy = gy - 1; }
                    if (gx >= 0 && gx < N && gy >= 0 && gy < N) {
                        _curZ = z; _curX = gx; _curY = gy;
                        doAction();
                    }
                    return;
                }
                z = z + 1;
            }
            return;
        }

        var col = (tx - _boardX) / _cell;
        var row = (ty - _boardY) / _cell;
        if (col < 0 || col >= _gridN || row < 0 || row >= _gridN) { return; }
        _curX = col; _curY = row;
        doAction();
    }
}
