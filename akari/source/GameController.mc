// ═══════════════════════════════════════════════════════════════
// GameController.mc — Akari state machine.
//
// States:
//   AS_MENU   chess-style 4-row menu
//   AS_PLAY   active puzzle
//   AS_WIN    solved
//
// Menu rows:
//   0  Diff   Easy 6x6 / Hard 7x7
//   1  Mode   Levels / Daily
//   2  Errs   Errors ON / Errors off
//   3  START
//
// Persistence keys (Storage):
//   ak_diff, ak_mode, ak_errs, ak_slot           — menu state
//   ak_best_easy_NN, ak_best_hard_NN             — fastest seconds
//   ak_solved_total                              — lifetime solves
//   ak_daily_date, ak_daily_best, ak_streak      — daily tracking
//
// The illumination map is cached in `lit` and recomputed only when
// the player toggles a cell — drawing during PLAY simply reads the
// cached array.
// ═══════════════════════════════════════════════════════════════

using Toybox.Application;
using Toybox.Time;
using Toybox.Time.Gregorian;

// Global leaderboard game identifier (must match the backend key).
const LB_GAME_ID = "akari";

const AS_MENU = 0;
const AS_PLAY = 1;
const AS_WIN  = 2;

const AK_MODE_LEVELS = 0;
const AK_MODE_DAILY  = 1;

// Labeled config rows (Diff / Mode / Errs / START).
const AK_MENU_ROWS = 4;
// The LEADERBOARD badge sits just below them; it's a navigable row but
// is not part of AK_MENU_ROWS so the label/activation logic stays clean.
const AK_LB_ROW    = AK_MENU_ROWS;
const AK_NAV_ROWS  = AK_MENU_ROWS + 1;

class GameController {
    var state;
    var menuRow;

    var diff;
    var mode;
    var showErrs;

    var grid;
    var startSnap;
    var lit;

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
        state          = AS_MENU;
        menuRow        = 0;
        diff           = 0;
        mode           = AK_MODE_LEVELS;
        showErrs       = false;
        grid           = new GridManager();
        startSnap      = [];
        lit            = [];
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

    // ── Persistence ────────────────────────────────────────────
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
        diff = _loadInt("ak_diff", 0);
        if (diff < 0 || diff > 1) { diff = 0; }
        mode = _loadInt("ak_mode", AK_MODE_LEVELS);
        if (mode < 0 || mode > 1) { mode = AK_MODE_LEVELS; }
        showErrs = _loadBool("ak_errs", false);
        slot = _loadInt("ak_slot", 0);
        if (slot < 0) { slot = 0; }
        solvedTotal  = _loadInt("ak_solved_total", 0);
        dailyDate    = _loadInt("ak_daily_date", 0);
        dailyBestSec = _loadInt("ak_daily_best", -1);
        streak       = _loadInt("ak_streak", 0);
    }

    function saveMenuSettings() {
        _save("ak_diff",  diff);
        _save("ak_mode",  mode);
        _save("ak_errs",  showErrs);
        _save("ak_slot",  slot);
    }

    hidden function _bestKey(d, s) {
        var dn = (d == 0) ? "easy" : "hard";
        return "ak_best_" + dn + "_" + s.format("%d");
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

    // ── Menu ───────────────────────────────────────────────────
    function menuNext() { menuRow = (menuRow + 1) % AK_NAV_ROWS; dirty = true; }
    function menuPrev() { menuRow = (menuRow + AK_NAV_ROWS - 1) % AK_NAV_ROWS; dirty = true; }
    function setMenuRow(i) { if (i >= 0 && i < AK_NAV_ROWS) { menuRow = i; dirty = true; } }

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
        state = AS_MENU;
        _refreshDailyStatus();
        dirty = true;
    }

    function difficultyName() {
        return (diff == 0) ? "Easy 6x6" : "Hard 7x7";
    }
    function modeName() {
        return (mode == AK_MODE_DAILY) ? "Daily" : "Levels";
    }
    function errsName() {
        return showErrs ? "Errs ON" : "Errs off";
    }

    // Leaderboard variant = board size, which dominates solve time, so each
    // size gets its own fastest-time board (e.g. "6x6", "7x7").
    function lbVariant() {
        return (diff == 0) ? "6x6" : "7x7";
    }
    function totalSlots() { return PuzzleLoader.bucketSize(diff); }

    // ── Lifecycle ──────────────────────────────────────────────
    hidden function _startGame() {
        _refreshDailyStatus();
        var rec;
        if (mode == AK_MODE_DAILY) {
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
        // If the first cell is a wall, scoot the cursor into the
        // nearest white cell so SEL is immediately meaningful.
        if (!grid.isWhite(0, 0)) { _findFirstWhite(); }
        elapsed = 0; moves = 0;
        lit     = IlluminationEngine.compute(grid);
        state   = AS_PLAY;
        dirty   = true;
    }
    hidden function _findFirstWhite() {
        var n = grid.n;
        for (var i = 0; i < n * n; i++) {
            if (grid.cells[i] == 0) {
                curR = i / n; curC = i % n;
                return;
            }
        }
    }

    function restart() {
        if (state != AS_PLAY && state != AS_WIN) { return; }
        if (startSnap.size() == grid.marks.size()) {
            grid.restore(startSnap);
        }
        elapsed = 0; moves = 0;
        lit     = IlluminationEngine.compute(grid);
        state   = AS_PLAY;
        dirty   = true;
    }

    function nextLevel() {
        if (mode != AK_MODE_LEVELS) { gotoMenu(); return; }
        slot = (slot + 1) % totalSlots();
        saveMenuSettings();
        _startGame();
    }

    // ── Tick ───────────────────────────────────────────────────
    function tickSecond() {
        if (state == AS_PLAY) { elapsed = elapsed + 1; dirty = true; }
    }

    // ── Cell ops ───────────────────────────────────────────────
    function moveCursor(dr, dc) {
        if (state != AS_PLAY) { return; }
        var n = grid.n;
        curR = ((curR + dr) + n) % n;
        curC = ((curC + dc) + n) % n;
        dirty = true;
    }
    function setCursor(r, c) {
        if (state != AS_PLAY || !grid.inBounds(r, c)) { return; }
        curR = r; curC = c;
        dirty = true;
    }
    function cycleCursor() {
        if (state != AS_PLAY) { return; }
        _cycleAt(curR, curC);
    }
    function cycleAt(r, c) {
        if (state != AS_PLAY || !grid.inBounds(r, c)) { return; }
        // Tapping a wall is a no-op except for moving the cursor.
        if (!grid.isWhite(r, c)) {
            curR = r; curC = c; dirty = true; return;
        }
        curR = r; curC = c;
        _cycleAt(r, c);
    }
    function markX() {
        if (state != AS_PLAY) { return; }
        if (!grid.isWhite(curR, curC)) { return; }
        var v = grid.markAt(curR, curC);
        grid.setMark(curR, curC, (v == AK_X) ? AK_NONE : AK_X);
        moves = moves + 1;
        // X doesn't change illumination but we still re-render.
        dirty = true;
    }
    hidden function _cycleAt(r, c) {
        grid.cycle(r, c);
        moves = moves + 1;
        lit   = IlluminationEngine.compute(grid);
        dirty = true;
        if (ValidationEngine.isSolved(grid, lit)) { _finishWin(); }
    }

    hidden function _finishWin() {
        solvedTotal = solvedTotal + 1;
        _save("ak_solved_total", solvedTotal);
        if (mode == AK_MODE_LEVELS) {
            _maybeUpdateBest(elapsed);
        } else {
            var t = _doy();
            if (dailyDate == t - 1) { streak = streak + 1; }
            else                    { streak = 1; }
            dailyDate      = t;
            dailyDoneToday = true;
            _save("ak_daily_date", dailyDate);
            _save("ak_streak", streak);
            if (dailyBestSec < 0 || elapsed < dailyBestSec) {
                dailyBestSec = elapsed;
                _save("ak_daily_best", dailyBestSec);
            }
        }

        // Submit solve time (whole seconds, LOWER is better — the backend
        // sorts this game ASCENDING, so submit the raw positive value).
        var secs = elapsed;
        if (secs < 1) { secs = 1; }
        Leaderboard.submitScore(LB_GAME_ID, secs, lbVariant());
        Leaderboard.showPostGame(LB_GAME_ID, lbVariant(), "AKARI");

        state = AS_WIN;
        dirty = true;
    }
}
