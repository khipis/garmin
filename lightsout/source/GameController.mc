// ═══════════════════════════════════════════════════════════════
// GameController.mc — LightsOut state machine.
//
// States:
//   LS_MENU   chess-style menu
//   LS_PLAY   solving the current level
//   LS_WIN    level solved
//
// Menu rows (chess-style, 3 rows):
//   0  Diff (Easy / Med / Hard)   ← purely affects daily-board size
//                                   AND which predefined level
//                                   bucket the START button jumps to
//   1  Mode (Levels / Daily)
//   2  START
//
// Persistence keys:
//   lo_diff             selected difficulty
//   lo_mode             selected mode (0 = levels, 1 = daily)
//   lo_level            current level number (1..LO_TOTAL_LEVELS)
//   lo_best_lvl_NN      best-moves per level (Number)
//   lo_solved_total     lifetime solves
//   lo_daily_date       last completed daily DOY
//   lo_daily_best       fewest moves on a daily
//   lo_streak           consecutive daily completions
// ═══════════════════════════════════════════════════════════════

using Toybox.Application;
using Toybox.System;
using Toybox.Time;
using Toybox.Time.Gregorian;

const LS_MENU = 0;
const LS_PLAY = 1;
const LS_WIN  = 2;

const LO_MODE_LEVELS = 0;
const LO_MODE_DAILY  = 1;

// Global leaderboard game id (MUST match the backend / shared library).
const LB_GAME_ID = "lightsout";

// Menu rows (chess-style). A "LEADERBOARD" row is appended after START.
const LO_ROW_DIFF        = 0;
const LO_ROW_MODE        = 1;
const LO_ROW_START       = 2;
const LO_ROW_LEADERBOARD = 3;
const LO_MENU_ROWS       = 4;

class GameController {
    var state;
    var menuRow;
    var diff;
    var mode;

    var grid;             // GridManager
    var startSnap;        // snapshot to restore on Restart

    var level;
    var moves;
    var solvePresses;     // canonical solve sequence (used for hint)
    var hintIndex;        // next press to suggest (in solvePresses)

    var curR;
    var curC;

    var solvedTotal;
    var dailyDate;
    var dailyDoneToday;
    var dailyBestMoves;
    var streak;

    var dirty;

    function initialize() {
        state         = LS_MENU;
        menuRow       = 0;
        diff          = 1;       // default = Medium (4×4)
        mode          = LO_MODE_LEVELS;

        grid          = new GridManager();
        startSnap     = [];

        level         = 1;
        moves         = 0;
        solvePresses  = [];
        hintIndex     = 0;

        curR          = 0; curC = 0;
        solvedTotal   = 0;
        dailyDate     = 0;
        dailyDoneToday = false;
        dailyBestMoves = -1;
        streak        = 0;
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
        diff = _loadInt("lo_diff", 1);
        if (diff < 0 || diff > 2) { diff = 1; }
        mode = _loadInt("lo_mode", LO_MODE_LEVELS);
        if (mode < 0 || mode > 1) { mode = LO_MODE_LEVELS; }
        level = _loadInt("lo_level", 1);
        if (level < 1) { level = 1; }
        if (level > LO_TOTAL_LEVELS) { level = LO_TOTAL_LEVELS; }
        solvedTotal    = _loadInt("lo_solved_total",  0);
        dailyDate      = _loadInt("lo_daily_date",    0);
        dailyBestMoves = _loadInt("lo_daily_best",   -1);
        streak         = _loadInt("lo_streak",        0);
    }

    function saveMenuSettings() {
        _save("lo_diff",  diff);
        _save("lo_mode",  mode);
        _save("lo_level", level);
    }

    hidden function _bestKey(lvl) {
        return "lo_best_lvl_" + lvl.format("%d");
    }
    function bestForLevel(lvl) { return _loadInt(_bestKey(lvl), -1); }
    hidden function _maybeUpdateBest(lvl, m) {
        var cur = bestForLevel(lvl);
        if (cur < 0 || m < cur) { _save(_bestKey(lvl), m); }
    }

    hidden function _todayDoy() {
        // Re-use LevelGenerator's daily helper via PuzzleLoader-style
        // call (we just do it inline to avoid extra modules).
        return _doyInline();
    }

    hidden function _doyInline() {
        // Approximate DOY: 31*(month-1) + day.  Same scheme used in
        // DiceRoyale/Kakuro for consistent daily-rotation behaviour.
        try {
            var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
            return 31 * (now.month - 1) + now.day;
        } catch (e) {
            return 0;
        }
    }

    hidden function _refreshDailyStatus() {
        var t = _doyInline();
        dailyDoneToday = (t > 0 && dailyDate == t);
    }

    // ── Menu ───────────────────────────────────────────────────
    function menuNext() { menuRow = (menuRow + 1) % LO_MENU_ROWS; }
    function menuPrev() { menuRow = (menuRow + LO_MENU_ROWS - 1) % LO_MENU_ROWS; }
    function setMenuRow(i) { if (i >= 0 && i < LO_MENU_ROWS) { menuRow = i; } }

    function menuActivate() {
        if (menuRow == LO_ROW_DIFF) {
            diff = (diff + 1) % 3;
            // Reset level to start of bucket so the diff change is
            // immediately reflected in the START button.
            level = _bucketStart(diff);
            saveMenuSettings();
        } else if (menuRow == LO_ROW_MODE) {
            mode = (mode + 1) % 2;
            saveMenuSettings();
        } else if (menuRow == LO_ROW_START) {
            _startGame();
        }
        // LO_ROW_LEADERBOARD is handled by the view (openLeaderboard).
        dirty = true;
    }

    // Board-size variant string ("3x3" / "4x4" / "5x5") for the puzzle
    // the player is configured to play. Used for both leaderboard
    // submission and the leaderboard view so they always agree.
    function boardVariant() {
        var n;
        if (mode == LO_MODE_DAILY) {
            n = LevelGenerator.gridSizeForDiff(diff);
        } else {
            n = LevelGenerator.gridSizeForLevel(level);
        }
        return n.format("%d") + "x" + n.format("%d");
    }
    hidden function _bucketStart(d) {
        if (d == 0) { return 1; }
        if (d == 1) { return LO_EASY_LAST + 1; }
        return LO_MED_LAST + 1;
    }
    function gotoMenu() {
        state = LS_MENU;
        _refreshDailyStatus();
        dirty = true;
    }

    function difficultyName() {
        if (diff == 0) { return "Easy (3x3)"; }
        if (diff == 1) { return "Med (4x4)";  }
        return "Hard (5x5)";
    }
    function modeName() {
        if (mode == LO_MODE_DAILY) { return "Daily"; }
        return "Levels";
    }

    // ── Lifecycle ───────────────────────────────────────────────
    hidden function _startGame() {
        _refreshDailyStatus();
        var lvl;
        var rec;
        if (mode == LO_MODE_DAILY) {
            rec = LevelGenerator.generateDaily(_doyInline(), diff);
        } else {
            lvl = level;
            if (lvl < 1) { lvl = 1; }
            if (lvl > LO_TOTAL_LEVELS) { lvl = LO_TOTAL_LEVELS; }
            level = lvl;
            rec = LevelGenerator.generateForLevel(level);
        }
        var n          = rec[0];
        var startCells = rec[1];
        var presses    = rec[2];

        grid.resize(n);
        for (var i = 0; i < n * n; i++) { grid.cells[i] = startCells[i]; }
        startSnap = grid.snapshot();

        solvePresses = presses;
        hintIndex    = 0;
        moves        = 0;
        curR         = 0;
        curC         = 0;
        state        = LS_PLAY;
        dirty        = true;
    }

    function restart() {
        if (state != LS_PLAY && state != LS_WIN) { return; }
        if (startSnap.size() == grid.cells.size()) {
            grid.restore(startSnap);
        }
        moves     = 0;
        hintIndex = 0;
        state     = LS_PLAY;
        dirty     = true;
    }

    // Skip to the next level (e.g. after a win).
    function nextLevel() {
        if (mode != LO_MODE_LEVELS) { gotoMenu(); return; }
        if (level < LO_TOTAL_LEVELS) {
            level = level + 1;
            saveMenuSettings();
            _startGame();
        } else {
            gotoMenu();
        }
    }

    // ── Cell ops ───────────────────────────────────────────────
    function moveCursor(dr, dc) {
        if (state != LS_PLAY) { return; }
        var n = grid.n;
        curR = ((curR + dr) + n) % n;
        curC = ((curC + dc) + n) % n;
        dirty = true;
    }
    function setCursor(r, c) {
        if (state != LS_PLAY) { return; }
        if (!grid.inBounds(r, c)) { return; }
        curR = r; curC = c;
        dirty = true;
    }
    function pressCursor() {
        if (state != LS_PLAY) { return; }
        _pressAt(curR, curC);
    }
    function pressAt(r, c) {
        if (state != LS_PLAY) { return; }
        if (!grid.inBounds(r, c)) { return; }
        curR = r; curC = c;
        _pressAt(r, c);
    }
    hidden function _pressAt(r, c) {
        grid.toggle(r, c);
        moves = moves + 1;
        dirty = true;
        if (grid.isAllOff()) { _finishWin(); }
    }

    // Hint: highlight the next cell in the canonical solve sequence.
    // Returns [r, c] of suggested cell, or [-1,-1] if no hint left.
    function hintCell() {
        if (state != LS_PLAY) { return [-1, -1]; }
        if (hintIndex >= solvePresses.size()) { return [-1, -1]; }
        var p = solvePresses[hintIndex];
        var n = grid.n;
        return [p / n, p % n];
    }
    function advanceHint() {
        if (state != LS_PLAY) { return; }
        if (hintIndex < solvePresses.size()) {
            hintIndex = hintIndex + 1;
        }
    }

    hidden function _finishWin() {
        // Submit fewest-moves-to-solve to the global leaderboard BEFORE any
        // level mutation below, so boardVariant() reflects the solved board.
        // Lower is better; the backend sorts this game ascending, so we send
        // the raw positive move count (do NOT negate).
        Leaderboard.submitScore(LB_GAME_ID, moves, boardVariant());
        Leaderboard.showPostGame(LB_GAME_ID, boardVariant(), "LIGHTS OUT");

        solvedTotal = solvedTotal + 1;
        _save("lo_solved_total", solvedTotal);
        if (mode == LO_MODE_LEVELS) {
            // Record the best for the level just solved. Advancing to
            // the next level is handled solely by nextLevel() from the
            // WIN screen — incrementing here too would skip a level.
            _maybeUpdateBest(level, moves);
        } else {
            var t = _doyInline();
            if (dailyDate == t - 1) { streak = streak + 1; }
            else                     { streak = 1; }
            dailyDate      = t;
            dailyDoneToday = true;
            _save("lo_daily_date", dailyDate);
            _save("lo_streak", streak);
            if (dailyBestMoves < 0 || moves < dailyBestMoves) {
                dailyBestMoves = moves;
                _save("lo_daily_best", dailyBestMoves);
            }
        }
        state = LS_WIN;
        dirty = true;
    }
}
