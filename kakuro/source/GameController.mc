// ═══════════════════════════════════════════════════════════════
// GameController.mc — Kakuro state machine + persistence.
//
// States:
//   KS_MENU    chess-style menu (diff, mode, START)
//   KS_PLAY    puzzle in progress
//   KS_WIN     completed
//
// Menu rows (chess-style):
//   0  Difficulty (Easy / Med / Hard)
//   1  Mode       (Practice / Daily)
//   2  START
//
// Persistence keys:
//   kk_diff             selected difficulty
//   kk_mode             selected mode (0=practice, 1=daily)
//   kk_slot_practice    practice slot (cycles puzzles after wins)
//   kk_best_easy_ms     fastest solve per (mode≠daily, difficulty)
//   kk_best_med_ms
//   kk_best_hard_ms
//   kk_daily_date       day-of-year of last daily completion
//   kk_daily_best_ms    fastest daily solve time
//   kk_streak           consecutive daily completions
//   kk_solved_total     lifetime puzzles solved
//
// Daily flow: when the mode is Daily, slot = today's DOY.  The
// player can re-attempt the same daily until they win — only the
// fastest completed time is recorded.
// ═══════════════════════════════════════════════════════════════

using Toybox.System;
using Toybox.Application;

const KS_MENU = 0;
const KS_PLAY = 1;
const KS_WIN  = 2;

const KK_MODE_PRACTICE = 0;
const KK_MODE_DAILY    = 1;

const KK_MENU_ROWS = 3;

class GameController {
    var state;
    var menuRow;
    var diff;            // 0 easy, 1 med, 2 hard
    var mode;            // KK_MODE_PRACTICE or KK_MODE_DAILY

    var grid;            // GridManager
    var err;             // flat n*n error flags (Number, 0/1)

    var curR;
    var curC;

    var elapsedMs;
    hidden var _lastResume;
    var lastTimeMs;

    var practiceSlot;
    var currentPuzzleId;

    var bestEasyMs;
    var bestMedMs;
    var bestHardMs;
    var bestDailyMs;
    var dailyDate;
    var dailyDoneToday;
    var streak;
    var solvedTotal;

    var dirty;

    function initialize() {
        state         = KS_MENU;
        menuRow       = 0;
        diff          = KK_DIFF_EASY;
        mode          = KK_MODE_PRACTICE;

        grid          = new GridManager();
        err           = [];

        curR          = 0; curC = 0;
        elapsedMs     = 0;
        _lastResume   = 0;
        lastTimeMs    = 0;
        practiceSlot  = 0;
        currentPuzzleId = -1;

        bestEasyMs    = -1;
        bestMedMs     = -1;
        bestHardMs    = -1;
        bestDailyMs   = -1;
        dailyDate     = 0;
        dailyDoneToday = false;
        streak        = 0;
        solvedTotal   = 0;
        dirty         = true;

        _loadAll();
        _refreshDailyStatus();
    }

    // ── Persistence ─────────────────────────────────────────────
    hidden function _loadInt(key, defv) {
        try {
            var v = Application.Storage.getValue(key);
            if (v instanceof Number) { return v; }
        } catch (e) {}
        return defv;
    }
    hidden function _save(key, v) {
        try { Application.Storage.setValue(key, v); } catch (e) {}
    }

    hidden function _loadAll() {
        diff         = _loadInt("kk_diff", KK_DIFF_EASY);
        if (diff < 0 || diff > 2) { diff = KK_DIFF_EASY; }
        mode         = _loadInt("kk_mode", KK_MODE_PRACTICE);
        if (mode < 0 || mode > 1) { mode = KK_MODE_PRACTICE; }
        practiceSlot = _loadInt("kk_slot_practice", 0);
        bestEasyMs   = _loadInt("kk_best_easy_ms",  -1);
        bestMedMs    = _loadInt("kk_best_med_ms",   -1);
        bestHardMs   = _loadInt("kk_best_hard_ms",  -1);
        bestDailyMs  = _loadInt("kk_daily_best_ms", -1);
        dailyDate    = _loadInt("kk_daily_date",     0);
        streak       = _loadInt("kk_streak",         0);
        solvedTotal  = _loadInt("kk_solved_total",   0);
    }

    function saveMenuSettings() {
        _save("kk_diff", diff);
        _save("kk_mode", mode);
    }

    hidden function _todayDoy() { return PuzzleLoader.todaySlot(); }
    hidden function _refreshDailyStatus() {
        var t = _todayDoy();
        dailyDoneToday = (t > 0 && dailyDate == t);
    }

    // ── Menu ───────────────────────────────────────────────────
    function menuNext() { menuRow = (menuRow + 1) % KK_MENU_ROWS; }
    function menuPrev() { menuRow = (menuRow + KK_MENU_ROWS - 1) % KK_MENU_ROWS; }
    function setMenuRow(i) { if (i >= 0 && i < KK_MENU_ROWS) { menuRow = i; } }

    function menuActivate() {
        if (menuRow == 0) {
            diff = (diff + 1) % 3;
            saveMenuSettings();
        } else if (menuRow == 1) {
            mode = (mode + 1) % 2;
            saveMenuSettings();
        } else {
            _startGame();
        }
        dirty = true;
    }

    function gotoMenu() {
        state = KS_MENU;
        _refreshDailyStatus();
        dirty = true;
    }

    function difficultyName() {
        if (diff == KK_DIFF_EASY) { return "Easy"; }
        if (diff == KK_DIFF_MED)  { return "Med";  }
        return "Hard";
    }
    function modeName() {
        if (mode == KK_MODE_DAILY) { return "Daily"; }
        return "Practice";
    }

    function bestForCurrent() {
        if (mode == KK_MODE_DAILY)  { return bestDailyMs; }
        if (diff == KK_DIFF_EASY)   { return bestEasyMs;  }
        if (diff == KK_DIFF_MED)    { return bestMedMs;   }
        return bestHardMs;
    }

    // ── Lifecycle ───────────────────────────────────────────────
    hidden function _startGame() {
        _refreshDailyStatus();
        var pid;
        if (mode == KK_MODE_DAILY) {
            // Daily uses today's DOY across all difficulties combined.
            pid = PuzzleLoader.todaySlot() % KK_PUZZLE_COUNT;
        } else {
            pid = PuzzleLoader.pick(diff, practiceSlot);
        }
        currentPuzzleId = pid;
        var n  = KKPuzzles.getN(pid);
        var sol = KKPuzzles.getSol(pid);
        grid.loadPuzzle(n, sol);
        err = new [n * n];
        for (var i = 0; i < n * n; i++) { err[i] = 0; }

        // Cursor on first white cell.
        curR = 0; curC = 0;
        for (var r = 0; r < n && !grid.isWhite(curR, curC); r++) {
            for (var c = 0; c < n; c++) {
                if (grid.isWhite(r, c)) { curR = r; curC = c; r = n; break; }
            }
        }

        elapsedMs   = 0;
        _lastResume = System.getTimer();
        state       = KS_PLAY;
        dirty       = true;
    }

    function tickTimer() {
        if (state != KS_PLAY) { return; }
        var now = System.getTimer();
        var dt  = now - _lastResume;
        if (dt < 0) { dt = 0; }
        elapsedMs   = elapsedMs + dt;
        _lastResume = now;
    }

    // ── Cell ops ───────────────────────────────────────────────
    function moveCursor(dr, dc) {
        if (state != KS_PLAY) { return; }
        var rc = grid.nextWhite(curR, curC, dr, dc);
        curR = rc[0]; curC = rc[1];
        dirty = true;
    }
    function advanceCursor() {
        if (state != KS_PLAY) { return; }
        var rc = grid.nextWhiteScan(curR, curC);
        curR = rc[0]; curC = rc[1];
        dirty = true;
    }
    function setCursor(r, c) {
        if (state != KS_PLAY) { return; }
        if (!grid.inBounds(r, c)) { return; }
        if (!grid.isWhite(r, c))  { return; }
        curR = r; curC = c;
        dirty = true;
    }

    function setCellTo(v) {
        if (state != KS_PLAY) { return; }
        if (!grid.setVal(curR, curC, v)) { return; }
        _afterEdit();
    }
    function clearCell() { setCellTo(0); }

    function cycleCell(forward) {
        if (state != KS_PLAY) { return; }
        if (!grid.isWhite(curR, curC)) { return; }
        var cur = grid.getVal(curR, curC);
        var next;
        if (forward) { next = (cur >= 9) ? 0 : (cur + 1); }
        else         { next = (cur <= 0) ? 9 : (cur - 1); }
        grid.setVal(curR, curC, next);
        _afterEdit();
    }

    hidden function _afterEdit() {
        ValidationEngine.recomputeErrors(grid, err);
        dirty = true;
        if (grid.isFilled() && ValidationEngine.isWin(grid)) {
            _finishWin();
        }
    }

    // Pro feature: fill the first empty cell with its canonical value.
    function hint() {
        if (state != KS_PLAY) { return; }
        var rc = ValidationEngine.firstEmpty(grid);
        if (rc[0] < 0) { return; }
        var sol = grid.getSol(rc[0], rc[1]);
        grid.setVal(rc[0], rc[1], sol);
        curR = rc[0]; curC = rc[1];
        _afterEdit();
    }

    // Restart current puzzle.
    function restart() {
        if (currentPuzzleId < 0) { return; }
        grid.clearAll();
        for (var i = 0; i < err.size(); i++) { err[i] = 0; }
        elapsedMs   = 0;
        _lastResume = System.getTimer();
        state       = KS_PLAY;
        dirty       = true;
    }

    hidden function _finishWin() {
        tickTimer();
        lastTimeMs  = elapsedMs;
        solvedTotal = solvedTotal + 1;
        _save("kk_solved_total", solvedTotal);

        if (mode == KK_MODE_DAILY) {
            var t = _todayDoy();
            if (dailyDate == t - 1) { streak = streak + 1; }
            else                     { streak = 1; }
            dailyDate      = t;
            dailyDoneToday = true;
            _save("kk_daily_date", dailyDate);
            _save("kk_streak", streak);
            if (bestDailyMs < 0 || lastTimeMs < bestDailyMs) {
                bestDailyMs = lastTimeMs;
                _save("kk_daily_best_ms", bestDailyMs);
            }
        } else {
            // Practice mode: cycle to next slot for variety on next
            // start.  Update best per difficulty.
            practiceSlot = practiceSlot + 1;
            _save("kk_slot_practice", practiceSlot);
            if (diff == KK_DIFF_EASY) {
                if (bestEasyMs < 0 || lastTimeMs < bestEasyMs) {
                    bestEasyMs = lastTimeMs;
                    _save("kk_best_easy_ms", bestEasyMs);
                }
            } else if (diff == KK_DIFF_MED) {
                if (bestMedMs < 0 || lastTimeMs < bestMedMs) {
                    bestMedMs = lastTimeMs;
                    _save("kk_best_med_ms", bestMedMs);
                }
            } else {
                if (bestHardMs < 0 || lastTimeMs < bestHardMs) {
                    bestHardMs = lastTimeMs;
                    _save("kk_best_hard_ms", bestHardMs);
                }
            }
        }
        state = KS_WIN;
        dirty = true;
    }

    // mm:ss formatter capped at 99:59.
    function fmtMs(ms) {
        if (ms < 0) { return "--:--"; }
        var s = ms / 1000;
        var m = s / 60;
        s = s % 60;
        if (m > 99) { m = 99; s = 59; }
        return m.format("%02d") + ":" + s.format("%02d");
    }
}
