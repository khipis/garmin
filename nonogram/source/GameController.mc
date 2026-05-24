// ═══════════════════════════════════════════════════════════════
// GameController.mc — Nonogram state machine.
//
// States:
//   NS_MENU   chess-style 4-row menu
//   NS_PLAY   active puzzle
//   NS_WIN    puzzle solved
//
// Menu rows:
//   0  Diff  (Easy / Hard)
//   1  Mode  (Levels / Daily)
//   2  Errs  (Errors ON / Errors OFF)
//   3  START
//
// Persistence keys (Storage):
//   ng_diff, ng_mode, ng_errs    — menu settings
//   ng_slot                       — current level slot
//   ng_best_easy_NN, ng_best_hard_NN — fastest solve seconds
//   ng_solved_total               — lifetime solves
//   ng_daily_date / _best / _streak
//
// Timer:
//   tickSecond() — called once per second from the view; bumps the
//   `elapsed` counter while we're in PLAY state.  We deliberately
//   keep the simulation logic timer-independent so the game state
//   doesn't depend on which tick rate the view chooses.
// ═══════════════════════════════════════════════════════════════

using Toybox.Application;
using Toybox.Time;
using Toybox.Time.Gregorian;

const NS_MENU = 0;
const NS_PLAY = 1;
const NS_WIN  = 2;

const NG_MODE_LEVELS = 0;
const NG_MODE_DAILY  = 1;

const NG_MENU_ROWS = 4;

class GameController {
    var state;
    var menuRow;

    var diff;
    var mode;
    var showErrs;

    var grid;
    var startSnap;

    var slot;
    var curR;
    var curC;

    var elapsed;
    var moves;

    var solvedTotal;
    var dailyDate;
    var dailyDoneToday;
    var dailyBestSec;
    var streak;

    var dirty;

    function initialize() {
        state          = NS_MENU;
        menuRow        = 0;
        diff           = 0;
        mode           = NG_MODE_LEVELS;
        showErrs       = false;
        grid           = new GridManager();
        startSnap      = [];
        slot           = 0;
        curR           = 0; curC = 0;
        elapsed        = 0;
        moves          = 0;
        solvedTotal    = 0;
        dailyDate      = 0;
        dailyDoneToday = false;
        dailyBestSec   = -1;
        streak         = 0;
        dirty          = true;
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
    hidden function _loadBool(key, defv) {
        try {
            var v = Application.Storage.getValue(key);
            if (v instanceof Boolean) { return v; }
        } catch (e) {}
        return defv;
    }
    hidden function _save(key, v) {
        try { Application.Storage.setValue(key, v); } catch (e) {}
    }

    hidden function _loadAll() {
        diff     = _loadInt("ng_diff", 0);
        if (diff < 0 || diff > 1) { diff = 0; }
        mode     = _loadInt("ng_mode", NG_MODE_LEVELS);
        if (mode < 0 || mode > 1) { mode = NG_MODE_LEVELS; }
        showErrs = _loadBool("ng_errs", false);
        slot     = _loadInt("ng_slot", 0);
        if (slot < 0) { slot = 0; }
        solvedTotal  = _loadInt("ng_solved_total", 0);
        dailyDate    = _loadInt("ng_daily_date", 0);
        dailyBestSec = _loadInt("ng_daily_best", -1);
        streak       = _loadInt("ng_streak", 0);
    }

    function saveMenuSettings() {
        _save("ng_diff", diff);
        _save("ng_mode", mode);
        _save("ng_errs", showErrs);
        _save("ng_slot", slot);
    }

    hidden function _bestKey(d, s) {
        var dn = (d == 0) ? "easy" : "hard";
        return "ng_best_" + dn + "_" + s.format("%d");
    }
    function bestForCurrent() { return _loadInt(_bestKey(diff, slot), -1); }
    hidden function _maybeUpdateBest(t) {
        var cur = _loadInt(_bestKey(diff, slot), -1);
        if (cur < 0 || t < cur) { _save(_bestKey(diff, slot), t); }
    }

    hidden function _doy() {
        try {
            var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
            return 31 * (now.month - 1) + now.day;
        } catch (e) {
            return 0;
        }
    }
    hidden function _refreshDailyStatus() {
        var t = _doy();
        dailyDoneToday = (t > 0 && dailyDate == t);
    }

    // ── Menu ────────────────────────────────────────────────────
    function menuNext() { menuRow = (menuRow + 1) % NG_MENU_ROWS; dirty = true; }
    function menuPrev() { menuRow = (menuRow + NG_MENU_ROWS - 1) % NG_MENU_ROWS; dirty = true; }
    function setMenuRow(i) { if (i >= 0 && i < NG_MENU_ROWS) { menuRow = i; dirty = true; } }

    function menuActivate() {
        if (menuRow == 0) {
            diff = (diff + 1) % 2;
            slot = 0;
        } else if (menuRow == 1) {
            mode = (mode + 1) % 2;
        } else if (menuRow == 2) {
            showErrs = !showErrs;
        } else {
            _startGame();
        }
        saveMenuSettings();
        dirty = true;
    }
    function gotoMenu() {
        state = NS_MENU;
        _refreshDailyStatus();
        dirty = true;
    }

    function difficultyName() {
        return (diff == 0) ? "Easy 5x5" : "Hard 6x6";
    }
    function modeName() {
        return (mode == NG_MODE_DAILY) ? "Daily" : "Levels";
    }
    function errsName() {
        return showErrs ? "Errs ON" : "Errs off";
    }

    function totalSlots() { return PuzzleLoader.bucketSize(diff); }

    // ── Lifecycle ──────────────────────────────────────────────
    hidden function _startGame() {
        _refreshDailyStatus();
        var rec;
        if (mode == NG_MODE_DAILY) {
            rec = PuzzleLoader.selectDaily(diff, _doy());
        } else {
            var total = totalSlots();
            if (total <= 0) { total = 1; }
            if (slot < 0) { slot = 0; }
            if (slot >= total) { slot = 0; }
            rec = PuzzleLoader.selectLevel(diff, slot);
        }
        grid.load(rec);
        startSnap = grid.snapshot();
        curR    = 0; curC = 0;
        elapsed = 0; moves = 0;
        state   = NS_PLAY;
        dirty   = true;
    }

    function restart() {
        if (state != NS_PLAY && state != NS_WIN) { return; }
        if (startSnap.size() == grid.cells.size()) {
            grid.restore(startSnap);
        }
        elapsed = 0; moves = 0;
        state   = NS_PLAY;
        dirty   = true;
    }

    function nextLevel() {
        if (mode != NG_MODE_LEVELS) { gotoMenu(); return; }
        slot = (slot + 1) % totalSlots();
        saveMenuSettings();
        _startGame();
    }

    // ── Tick ───────────────────────────────────────────────────
    function tickSecond() {
        if (state == NS_PLAY) { elapsed = elapsed + 1; dirty = true; }
    }

    // ── Cell ops ───────────────────────────────────────────────
    function moveCursor(dr, dc) {
        if (state != NS_PLAY) { return; }
        var n = grid.n;
        curR = ((curR + dr) + n) % n;
        curC = ((curC + dc) + n) % n;
        dirty = true;
    }
    function setCursor(r, c) {
        if (state != NS_PLAY || !grid.inBounds(r, c)) { return; }
        curR = r; curC = c;
        dirty = true;
    }
    function cycleCursor() {
        if (state != NS_PLAY) { return; }
        _cycleAt(curR, curC);
    }
    function cycleAt(r, c) {
        if (state != NS_PLAY || !grid.inBounds(r, c)) { return; }
        curR = r; curC = c;
        _cycleAt(r, c);
    }
    function markX() {
        if (state != NS_PLAY) { return; }
        var v = grid.getCell(curR, curC);
        // Toggle just the X-state on/off independent of fill cycle.
        grid.cells[grid.idx(curR, curC)] = (v == NG_X) ? NG_EMPTY : NG_X;
        moves = moves + 1;
        dirty = true;
    }
    hidden function _cycleAt(r, c) {
        grid.cycle(r, c);
        moves = moves + 1;
        dirty = true;
        _checkWin();
    }

    hidden function _checkWin() {
        if (ValidationEngine.isSolved(grid)) { _finishWin(); }
    }

    hidden function _finishWin() {
        solvedTotal = solvedTotal + 1;
        _save("ng_solved_total", solvedTotal);
        if (mode == NG_MODE_LEVELS) {
            _maybeUpdateBest(elapsed);
        } else {
            var t = _doy();
            if (dailyDate == t - 1) { streak = streak + 1; }
            else                    { streak = 1; }
            dailyDate      = t;
            dailyDoneToday = true;
            _save("ng_daily_date", dailyDate);
            _save("ng_streak", streak);
            if (dailyBestSec < 0 || elapsed < dailyBestSec) {
                dailyBestSec = elapsed;
                _save("ng_daily_best", dailyBestSec);
            }
        }
        state = NS_WIN;
        dirty = true;
    }
}
