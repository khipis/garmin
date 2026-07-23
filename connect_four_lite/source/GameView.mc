using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.Math;
using Toybox.Application;
using Toybox.Lang;
using Toybox.Attention;

// ── Global leaderboard ──────────────────────────────────────────────────────
const LB_GAME_ID = "connectfour";
const LB_STREAK_KEY = "connectfour_streak";
const CF_FX_KEY = "cf_fx";   // 0/unset = sound+haptics ON, 1 = OFF

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

    // ── Sound + haptics (OPTIONS: cf_fx) ──────────────────────────────────
    hidden var _fxOn;
    hidden var _fxEndDone;   // one-shot guard for end-of-game feedback

    // ── Timer ─────────────────────────────────────────────────────────────
    hidden var _timer;

    // ── Alpha-beta column ordering ────────────────────────────────────────
    hidden var _abCols;   // center-out order [3,2,4,1,5,0,6]

    // ── Iterative alpha-beta stack (depth ≤ 8) — no recursion ────────────
    // Each "frame" represents the search state at a particular depth.
    hidden var _stCi;        // current column index iterator
    hidden var _stCol;       // column actually played at this depth (for undo)
    hidden var _stRow;       // row played
    hidden var _stAlpha;
    hidden var _stBeta;
    hidden var _stBest;      // best score found so far at this depth
    hidden var _stMark;      // mark to play
    hidden var _stOpp;       // opponent of mark

    // ── Tick-spread alpha-beta search state ─────────────────────────────
    // The search runs incrementally across multiple timer ticks to stay
    // well under the per-callback watchdog limit on slow devices
    // (e.g. fenix8 solar 51mm). Each tick processes at most _abBudget
    // iterations of the main loop.
    hidden var _abActive;        // true while a search is in progress
    hidden var _abSp;            // current stack pointer (depth)
    hidden var _abLastResult;    // last child score returned to integrate
    hidden var _abHasResult;     // pending child result?
    hidden var _abRootBestScore;
    hidden var _abRootBestCol;
    hidden var _abMaxDepth;
    hidden var _abRootMark;
    hidden var _abRootOpp;

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
        _fxOn      = _loadFx();
        _fxEndDone = false;
        _abCols = new [COLS];
        _abCols[0] = 3; _abCols[1] = 2; _abCols[2] = 4;
        _abCols[3] = 1; _abCols[4] = 5; _abCols[5] = 0; _abCols[6] = 6;
        // Allocate stack frames for max search depth = 8 (more than enough).
        var MAXD = 8;
        _stCi    = new [MAXD]; _stCol   = new [MAXD]; _stRow = new [MAXD];
        _stAlpha = new [MAXD]; _stBeta  = new [MAXD]; _stBest = new [MAXD];
        _stMark  = new [MAXD]; _stOpp   = new [MAXD];
        _abActive        = false;
        _abSp            = -1;
        _abLastResult    = 0;
        _abHasResult     = false;
        _abRootBestScore = -999999;
        _abRootBestCol   = -1;
        _abMaxDepth      = 0;
        _abRootMark      = MARK_AI;
        _abRootOpp       = MARK_P;
        // Settings come from the shared OPTIONS screen (persisted in Storage).
        // Read them, configure, and drop straight into a game.
        _applySettings();
        _startGame();
    }

    // ── Settings (driven by the shared OPTIONS screen) ─────────────────────
    // Keys: cf_mode (0..2), cf_diff (0..2), cf_side (0=Red first, 1=Yellow).
    hidden function _stgIdx(key, def, lo, hi) {
        try {
            var v = Application.Storage.getValue(key);
            if (v instanceof Lang.Number && v >= lo && v <= hi) { return v; }
        } catch (e) {}
        return def;
    }

    hidden function _applySettings() {
        _cfMode      = _stgIdx("cf_mode", CF_MODE_PVAI, 0, 2);
        _cfDiff      = _stgIdx("cf_diff", CF_DIFF_MED, 0, 2);
        _playerFirst = (_stgIdx("cf_side", 0, 0, 1) == 0);
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
    }

    function onShow() {
        if (_timer == null) { _timer = new Timer.Timer(); }
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
            if (dir < 0) { _menuSel = (_menuSel + 4) % 5; }
            else if (dir > 0) { _menuSel = (_menuSel + 1) % 5; }
            return;
        }
        if (_state != GS_PLAY) { return; }
        _curCol = _curCol + dir;
        if (_curCol < 0)     { _curCol = COLS - 1; }   // wrap left → right
        if (_curCol >= COLS) { _curCol = 0; }           // wrap right → left
    }

    // BACK: menu → pop app, in-game → return to menu
    // BACK: always return to the shared menu (pop this gameplay view).
    function doBack() {
        return false;
    }

    function doAction() {
        if (_state == GS_MENU) {
            if (_menuSel == 0) {
                _cfMode = (_cfMode + 1) % 3;
            } else if (_menuSel == 1) {
                if (_cfMode != CF_MODE_PVP) { _cfDiff = (_cfDiff + 1) % 3; }
            } else if (_menuSel == 2) {
                if (_cfMode == CF_MODE_PVAI) { _playerFirst = !_playerFirst; }
            } else if (_menuSel == 3) {
                _startGame();
            } else {
                openLeaderboard();
            }
            return;
        }
        if (_state == GS_OVER) { _startGame(); return; }
        if (_state != GS_PLAY) { return; }
        if (_cfMode == CF_MODE_AIAI) { return; }  // AiAI: no human input
        var r = _dropRow(_curCol);
        if (r < 0) { _tone(2); return; }   // column full
        _dropDisc(_curCol, r, MARK_P);
        if (_checkWin(MARK_P)) {
            _overType = OVER_PWIN; _scoreP = _scoreP + 1; _state = GS_OVER; _onGameEnd(); return;
        }
        if (_moveCount == COLS * ROWS) { _overType = OVER_DRAW; _state = GS_OVER; _onGameEnd(); return; }
        _state = GS_AI;
    }

    // ── Global leaderboard ────────────────────────────────────────────────
    // Metric = WIN STREAK: consecutive wins vs the AI. Higher is better.
    // Persisted across games in Application.Storage[LB_STREAK_KEY].
    // Variant = difficulty so each level keeps its own ranking.
    hidden function _variant() {
        return (_cfDiff == CF_DIFF_EASY) ? "Easy"
               : ((_cfDiff == CF_DIFF_MED) ? "Med" : "Hard");
    }

    hidden function _loadStreak() {
        var s = Application.Storage.getValue(LB_STREAK_KEY);
        if (s instanceof Lang.Number) { return s; }
        return 0;
    }

    // Called whenever a game reaches GS_OVER. Win streak only counts the
    // human beating the AI, so it's a no-op outside Player-vs-AI mode.
    hidden function _onGameEnd() {
        if (_cfMode != CF_MODE_PVAI) { return; }
        if (_overType == OVER_PWIN) {
            var newStreak = _loadStreak() + 1;
            Application.Storage.setValue(LB_STREAK_KEY, newStreak);
            Leaderboard.submitScore(LB_GAME_ID, newStreak, _variant());
            Leaderboard.showPostGame(LB_GAME_ID, _variant(), "CONNECT FOUR");
        } else {
            // Loss or draw breaks the streak.
            Application.Storage.setValue(LB_STREAK_KEY, 0);
        }
    }

    function openLeaderboard() {
        var variant = _variant();
        var v = new LbScoresView(LB_GAME_ID, variant, "CONNECT FOUR");
        WatchUi.pushView(v, new LbScoresDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // ── Timer tick ────────────────────────────────────────────────────────
    // _aiTickFor() may return false ("still thinking") for tick-spread
    // alpha-beta on Med/Hard. In that case we leave the state untouched
    // and resume the search on the next tick.
    function gameTick() as Void {
        if (_state != GS_AI && (_state != GS_PLAY || _cfMode != CF_MODE_AIAI)) { return; }
        if (_state == GS_AI) {
            var committed = _aiTickFor(MARK_AI, MARK_P);
            if (committed) {
                if (_checkWin(MARK_AI)) {
                    _overType = OVER_AIWIN; _scoreAI = _scoreAI + 1; _state = GS_OVER; _onGameEnd();
                } else if (_moveCount == COLS * ROWS) {
                    _overType = OVER_DRAW; _state = GS_OVER; _onGameEnd();
                } else {
                    _state = GS_PLAY;
                }
            }
        } else {
            var committed2 = _aiTickFor(MARK_P, MARK_AI);
            if (committed2) {
                if (_checkWin(MARK_P)) {
                    _overType = OVER_PWIN; _scoreP = _scoreP + 1; _state = GS_OVER;
                } else if (_moveCount == COLS * ROWS) {
                    _overType = OVER_DRAW; _state = GS_OVER;
                } else {
                    _state = GS_AI;
                }
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
        _fxOn      = _loadFx();
        _fxEndDone = false;
        // Abort any in-progress AI search from a previous game so the board
        // doesn't get marks dropped into it after a restart.
        _abActive  = false;
        _abSp      = -1;
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
        _tone(0); _vibe(30, 35);   // disc dropped (player or AI)
    }

    // ── Best-effort feedback (silent/absent hardware is fine) ──────────────
    // kind: 0 drop/move · 1 generic win · 2 illegal/draw · 3 win · 4 loss.
    hidden function _loadFx() {
        try {
            var v = Application.Storage.getValue(CF_FX_KEY);
            if (v instanceof Number && v == 1) { return false; }
        } catch (e) { }
        return true;
    }
    hidden function _tone(kind) {
        if (!_fxOn) { return; }
        if (!(Toybox has :Attention)) { return; }
        if (!(Attention has :playTone)) { return; }
        var t;
        if      (kind == 0) { t = Attention.TONE_KEY; }
        else if (kind == 1) { t = Attention.TONE_LOUD_BEEP; }
        else if (kind == 2) { t = Attention.TONE_ALERT_LO; }
        else if (kind == 3) { t = Attention.TONE_SUCCESS; }
        else                { t = Attention.TONE_FAILURE; }
        try { Attention.playTone(t); } catch (e) {}
    }
    hidden function _vibe(intensity, duration) {
        if (!_fxOn) { return; }
        if (!(Toybox has :Attention)) { return; }
        if (!(Attention has :vibrate)) { return; }
        try { Attention.vibrate([new Attention.VibeProfile(intensity, duration)]); } catch (e) {}
    }

    // End-of-game feedback (win / loss / draw), fired once per game from onUpdate.
    hidden function _endFx() {
        if (_overType == OVER_DRAW) { _tone(2); _vibe(40, 120); return; }
        if (_cfMode != CF_MODE_PVAI) { _tone(1); _vibe(80, 180); return; }
        if (_overType == OVER_PWIN) { _tone(3); _vibe(100, 250); }
        else                        { _tone(4); _vibe(100, 350); }
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
    // Easy:  win/block + fork + heuristic                    (~5K ops)
    // Med:   win/block + fork + alpha-beta depth 2           (~10K ops)
    // Hard:  win/block + fork + alpha-beta depth 3           (~78K ops worst)
    //
    // DEPTH LIMITS (empirically determined):
    //   depth=4 CRASHES: even with cheap eval, 7^4=2401 nodes × overhead.
    //   depth=3 SAFE: 7^3=343 worst × 228 ops/leaf = ~78K ops — fits watchdog.
    //   depth=3 + window-scan (1659 ops/leaf) CRASHES: 343×1659=569K ops.
    //
    // Leaf eval: row-weighted column counts (228 ops).
    //   Bottom rows get higher weights (more winning sequences pass through them).
    //   This creates diverse scores → effective α-β pruning even in early game.
    //   Combined with _findForkCol for all non-easy levels, AI plays well tactically.

    // Tick-spread AI driver. Returns true when a disc has been dropped
    // (move committed); false while the AI is still "thinking" — the
    // caller should keep the state at GS_AI and call again next tick.
    //
    // Watchdog strategy: pre-checks (win/block/fork) finish in one tick.
    // Med/Hard alpha-beta runs incrementally via _alphaBetaStep so each
    // timer callback stays well below the device's per-tick CPU budget.
    hidden function _aiTickFor(mark, opp) {
        // Resume an in-progress search.
        if (_abActive) {
            var done = _alphaBetaStep(120);  // ~120 frames × ~200 ops ≈ 24K ops/tick — safe
            if (!done) { return false; }
            var rc = _abRootBestCol;
            _abActive = false;
            if (rc < 0) { rc = _bestScoredColFor(_abRootMark, _abRootOpp); }
            if (rc >= 0) { _dropDisc(rc, _dropRow(rc), _abRootMark); return true; }
            // Fallback: drop in first legal column
            var fc = 0;
            while (fc < COLS) {
                if (_dropRow(fc) >= 0) { _dropDisc(fc, _dropRow(fc), _abRootMark); return true; }
                fc = fc + 1;
            }
            return true;
        }

        // 1. Win immediately
        var col = _findWinningCol(mark);
        if (col >= 0) { _dropDisc(col, _dropRow(col), mark); return true; }

        // 2. Block immediate loss
        col = _findWinningCol(opp);
        if (col >= 0) { _dropDisc(col, _dropRow(col), mark); return true; }

        // 3. Fork attacks — fast pre-check (~7K ops), prevents missed forks
        col = _findForkCol(mark);
        if (col >= 0) { _dropDisc(col, _dropRow(col), mark); return true; }
        col = _findForkCol(opp);
        if (col >= 0) { _dropDisc(col, _dropRow(col), mark); return true; }

        if (_cfDiff == CF_DIFF_EASY) {
            col = _bestScoredColFor(mark, opp);
            if (col < 0) {
                var k = 0;
                while (k < COLS) {
                    if (_dropRow(k) >= 0) { col = k; break; }
                    k = k + 1;
                }
            }
            if (col >= 0) { _dropDisc(col, _dropRow(col), mark); }
            return true;
        }

        // Med/Hard: tick-spread alpha-beta search.
        //   Easy : heuristic only            (above)
        //   Med  : depth 2 → ~50 leaves, finishes in one tick (cheap)
        //   Hard : depth 3 → ~80-150 leaves, ~5-9 ticks × 300 ms ≈ 1.5-2.7 s.
        //          Depth 4 was too slow even with tick-spread (≥9 s).
        //          Combined with win/block + 2-ply fork pre-tactics, the
        //          effective tactical depth is ~5 plies — still a strong
        //          Connect-4 opponent.
        var depth = (_cfDiff == CF_DIFF_HARD) ? 3 : 2;
        _alphaBetaSetup(depth, mark, opp);
        var doneNow = _alphaBetaStep(120);
        if (doneNow) {
            var rc2 = _abRootBestCol;
            _abActive = false;
            if (rc2 < 0) { rc2 = _bestScoredColFor(mark, opp); }
            if (rc2 >= 0) { _dropDisc(rc2, _dropRow(rc2), mark); return true; }
            var fc2 = 0;
            while (fc2 < COLS) {
                if (_dropRow(fc2) >= 0) { _dropDisc(fc2, _dropRow(fc2), mark); return true; }
                fc2 = fc2 + 1;
            }
            return true;
        }
        return false; // still thinking
    }

    // Row-weighted leaf eval — extracted from inline body for reuse.
    // Bottom rows weighted higher (more win-lines pass through them).
    hidden function _leafEvalFor(mark, opp) {
        var sc = 0; var cr = 0;
        while (cr < ROWS) {
            var idx = cr * COLS; var v;
            if (cr >= 4) {
                v = _cells[idx];     if (v == mark) { sc = sc + 3; } else if (v == opp) { sc = sc - 3; }
                v = _cells[idx + 1]; if (v == mark) { sc = sc + 5; } else if (v == opp) { sc = sc - 5; }
                v = _cells[idx + 2]; if (v == mark) { sc = sc + 7; } else if (v == opp) { sc = sc - 7; }
                v = _cells[idx + 3]; if (v == mark) { sc = sc + 9; } else if (v == opp) { sc = sc - 9; }
                v = _cells[idx + 4]; if (v == mark) { sc = sc + 7; } else if (v == opp) { sc = sc - 7; }
                v = _cells[idx + 5]; if (v == mark) { sc = sc + 5; } else if (v == opp) { sc = sc - 5; }
                v = _cells[idx + 6]; if (v == mark) { sc = sc + 3; } else if (v == opp) { sc = sc - 3; }
            } else {
                v = _cells[idx];     if (v == mark) { sc = sc + 2; } else if (v == opp) { sc = sc - 2; }
                v = _cells[idx + 1]; if (v == mark) { sc = sc + 4; } else if (v == opp) { sc = sc - 4; }
                v = _cells[idx + 2]; if (v == mark) { sc = sc + 6; } else if (v == opp) { sc = sc - 6; }
                v = _cells[idx + 3]; if (v == mark) { sc = sc + 8; } else if (v == opp) { sc = sc - 8; }
                v = _cells[idx + 4]; if (v == mark) { sc = sc + 6; } else if (v == opp) { sc = sc - 6; }
                v = _cells[idx + 5]; if (v == mark) { sc = sc + 4; } else if (v == opp) { sc = sc - 4; }
                v = _cells[idx + 6]; if (v == mark) { sc = sc + 2; } else if (v == opp) { sc = sc - 2; }
            }
            cr = cr + 1;
        }
        return sc;
    }

    // Iterative alpha-beta negamax with explicit stack — phase 1 (setup).
    // Cheap: initializes the root frame and shared search state.
    // Phase 2 (_alphaBetaStep) processes the search incrementally, a few
    // hundred iterations per timer tick, to stay well under the watchdog
    // limit on slow devices (fenix 8 solar 51mm).
    hidden function _alphaBetaSetup(maxDepth, rootMark, rootOpp) {
        _abActive        = true;
        _abMaxDepth      = maxDepth;
        _abRootMark      = rootMark;
        _abRootOpp       = rootOpp;
        _abRootBestScore = -999999;
        _abRootBestCol   = -1;
        _abSp            = 0;
        _abLastResult    = 0;
        _abHasResult     = false;
        _stCi[0]    = 0;
        _stCol[0]   = -1;
        _stRow[0]   = -1;
        _stAlpha[0] = -9999;
        _stBeta[0]  =  9999;
        _stBest[0]  = -9999;
        _stMark[0]  = rootMark;
        _stOpp[0]   = rootOpp;
    }

    // Process up to `budget` iterations of the main alpha-beta loop.
    // Returns true if the search is complete (caller should commit
    // _abRootBestCol), false if there's more work to do on the next tick.
    //
    // Each "iteration" either:
    //   • integrates a child's returned score, or
    //   • pops an exhausted frame, or
    //   • plays one column at the current depth (descend / leaf eval).
    //
    // Per-iteration cost: ~50 ops (interior) … ~300 ops (leaf with eval).
    // With budget=120 that's ~6K–36K ops per tick, comfortable on every
    // supported Garmin watch.
    hidden function _alphaBetaStep(budget) {
        var maxDepth = _abMaxDepth;
        var sp         = _abSp;
        var hasResult  = _abHasResult;
        var lastResult = _abLastResult;
        var processed  = 0;

        while (sp >= 0 && processed < budget) {
            processed = processed + 1;
            if (hasResult) {
                var childScore = -lastResult;
                hasResult = false;
                _cells[_stRow[sp] * COLS + _stCol[sp]] = MARK_NONE;
                _moveCount = _moveCount - 1;
                if (childScore > _stBest[sp])  { _stBest[sp]  = childScore; }
                if (childScore > _stAlpha[sp]) { _stAlpha[sp] = childScore; }
                if (sp == 0 && childScore > _abRootBestScore) {
                    _abRootBestScore = childScore;
                    _abRootBestCol   = _stCol[sp];
                }
                if (_stAlpha[sp] >= _stBeta[sp]) { _stCi[sp] = COLS; }
                else                              { _stCi[sp] = _stCi[sp] + 1; }
                continue;
            }
            if (_stCi[sp] >= COLS) {
                if (sp == 0) { sp = -1; break; }
                lastResult = (_stBest[sp] == -9999) ? 0 : _stBest[sp];
                hasResult  = true;
                sp = sp - 1;
                continue;
            }
            var c = _abCols[_stCi[sp]];
            var r = _dropRow(c);
            if (r < 0) { _stCi[sp] = _stCi[sp] + 1; continue; }

            _cells[r * COLS + c] = _stMark[sp];
            _moveCount = _moveCount + 1;

            if (_checkWinAt(_stMark[sp], c, r)) {
                var sc = 8000 + (maxDepth - sp);
                _cells[r * COLS + c] = MARK_NONE;
                _moveCount = _moveCount - 1;
                if (sc > _stBest[sp])  { _stBest[sp]  = sc; }
                if (sc > _stAlpha[sp]) { _stAlpha[sp] = sc; }
                if (sp == 0 && sc > _abRootBestScore) {
                    _abRootBestScore = sc; _abRootBestCol = c;
                }
                if (_stAlpha[sp] >= _stBeta[sp]) { _stCi[sp] = COLS; }
                else                              { _stCi[sp] = _stCi[sp] + 1; }
                continue;
            }
            if (_moveCount == COLS * ROWS) {
                _cells[r * COLS + c] = MARK_NONE;
                _moveCount = _moveCount - 1;
                if (0 > _stBest[sp])  { _stBest[sp]  = 0; }
                if (0 > _stAlpha[sp]) { _stAlpha[sp] = 0; }
                if (sp == 0 && 0 > _abRootBestScore) {
                    _abRootBestScore = 0; _abRootBestCol = c;
                }
                if (_stAlpha[sp] >= _stBeta[sp]) { _stCi[sp] = COLS; }
                else                              { _stCi[sp] = _stCi[sp] + 1; }
                continue;
            }
            if (sp == maxDepth - 1) {
                var sc2 = _leafEvalFor(_stMark[sp], _stOpp[sp]);
                _cells[r * COLS + c] = MARK_NONE;
                _moveCount = _moveCount - 1;
                if (sc2 > _stBest[sp])  { _stBest[sp]  = sc2; }
                if (sc2 > _stAlpha[sp]) { _stAlpha[sp] = sc2; }
                if (sp == 0 && sc2 > _abRootBestScore) {
                    _abRootBestScore = sc2; _abRootBestCol = c;
                }
                if (_stAlpha[sp] >= _stBeta[sp]) { _stCi[sp] = COLS; }
                else                              { _stCi[sp] = _stCi[sp] + 1; }
                continue;
            }
            _stCol[sp] = c;
            _stRow[sp] = r;
            sp = sp + 1;
            _stCi[sp]    = 0;
            _stCol[sp]   = -1;
            _stRow[sp]   = -1;
            _stAlpha[sp] = -_stBeta[sp - 1];
            _stBeta[sp]  = -_stAlpha[sp - 1];
            _stBest[sp]  = -9999;
            _stMark[sp]  = _stOpp[sp - 1];
            _stOpp[sp]   = _stMark[sp - 1];
        }

        _abSp         = sp;
        _abHasResult  = hasResult;
        _abLastResult = lastResult;
        return (sp < 0);  // true → search complete, false → resume next tick
    }

    // Legacy single-shot wrapper kept for back-compat / fallback paths.
    // NOT used by the regular AI flow (which now calls _alphaBetaSetup +
    // _alphaBetaStep across multiple timer ticks for watchdog safety).
    hidden function _alphaBetaIterativeRoot(maxDepth, rootMark, rootOpp) {
        _alphaBetaSetup(maxDepth, rootMark, rootOpp);
        while (!_alphaBetaStep(200)) { }
        _abActive = false;
        return _abRootBestCol;
    }

    hidden function _aiDrop() { _aiTickFor(MARK_AI, MARK_P); }

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
        if (_state == GS_MENU) { _startGame(); }
        if (_state == GS_OVER && !_fxEndDone) { _fxEndDone = true; _endFx(); }
        dc.setColor(0x060610, 0x060610);
        dc.clear();
        _drawBoard(dc);
        _drawSelector(dc);
        _drawHUD(dc);
        if (_state == GS_OVER) { _drawGameOver(dc); }
    }

    // ── Pre-game menu ─────────────────────────────────────────────────────
    // Layout for the 5-row menu (Mode / Diff / Side / START / LEADERBOARD).
    // Space-aware: rows are sized to fit between the title and footer and the
    // height is capped ~18% smaller than the old 4-row layout so the extra
    // LEADERBOARD row never overlaps anything on round watches.
    // Returns [nR, rowX, rowY0, rowW, rowH, gap]. Shared by _drawMenu/doTap.
    hidden function _menuGeom() {
        var nR   = 5;
        var gap  = 4;
        var topY = _sh * 23 / 100;   // below the title
        var botY = _sh - 18;          // above the footer hint
        var avail = botY - topY;
        var rowH = (avail - (nR - 1) * gap) / nR;
        if (rowH > 22) { rowH = 22; }  // ~18% smaller, then ~10% more compact
        if (rowH < 13) { rowH = 13; }
        var rowW = _sw * 67 / 100;
        var rowX = (_sw - rowW) / 2;
        var tot  = nR * rowH + (nR - 1) * gap;
        var rowY0 = topY + (avail - tot) / 2;
        return [nR, rowX, rowY0, rowW, rowH, gap];
    }

    hidden function _drawMenu(dc) {
        dc.setColor(0x060610, 0x060610);
        dc.clear();
        var hw = _sw / 2;
        dc.setColor(0x06060E, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(hw, _sh / 2, _sw / 2 - 1);

        dc.setColor(0xFF2200, Graphics.COLOR_TRANSPARENT);
        dc.drawText(hw, _sh * 15 / 100, Graphics.FONT_SMALL, "CONNECT FOUR", Graphics.TEXT_JUSTIFY_CENTER);

        var modeStr = (_cfMode == CF_MODE_PVAI) ? "P vs AI"
                      : ((_cfMode == CF_MODE_PVP) ? "P vs P" : "AI vs AI");
        var diffStr = (_cfDiff == CF_DIFF_EASY) ? "Easy"
                      : ((_cfDiff == CF_DIFF_MED) ? "Med" : "Hard");
        var sideStr = _playerFirst ? "Side: Red" : "Side: Yel";
        var rows = ["Mode: " + modeStr, "Diff: " + diffStr, sideStr, "START"];

        var g    = _menuGeom();
        var nR   = g[0];
        var rowX = g[1];
        var rowY0 = g[2];
        var rowW = g[3];
        var rowH = g[4];
        var gap  = g[5];

        var i = 0;
        while (i < nR) {
            var ry  = rowY0 + i * (rowH + gap);
            var sel = (i == _menuSel);
            if (i == nR - 1) {
                // Gold "LEADERBOARD" row from the shared library.
                LbBadge.drawRow(dc, rowX, ry, rowW, rowH, sel);
                i = i + 1;
                continue;
            }
            var isStart = (i == 3);
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

    function doTap(tx, ty) {
        if (_state == GS_MENU) {
            var g    = _menuGeom();
            var nR   = g[0];
            var rowX = g[1];
            var rowY0 = g[2];
            var rowW = g[3];
            var rowH = g[4];
            var gap  = g[5];
            for (var i = 0; i < nR; i++) {
                var ry = rowY0 + i * (rowH + gap);
                if (tx >= rowX && tx < rowX + rowW && ty >= ry && ty < ry + rowH) {
                    _menuSel = i; doAction(); return;
                }
            }
            return;
        }
        if (_state == GS_OVER) { _startGame(); return; }
        if (_state != GS_PLAY) { return; }
        if (_cell <= 0) { return; }
        var col = (tx - _boardX) / _cell;
        if (col < 0 || col >= COLS) { return; }
        _curCol = col;
        doAction();
    }
}
