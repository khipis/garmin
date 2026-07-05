using Toybox.Application;
using Toybox.System;

// ── States ────────────────────────────────────────────────────────
const GS_MENU = 0;
const GS_PLAY = 1;
const GS_WIN  = 2;
const GS_LOSE = 3;

// ── Menu rows ─────────────────────────────────────────────────────
const MENU_SIZE   = 0;
const MENU_BOMBS  = 1;
const MENU_START  = 2;
const MENU_LEADER = 3;
const MENU_ROW_COUNT = 4;

// Shared global-leaderboard game id (see _shared/leaderboard).
const LB_GAME_ID = "minesweeper";

const DIFF_COUNT = 6;
const DENS_COUNT = 5;

class GameController {

    static var SIZES = [8, 10, 12, 16, 24, 32];
    static var NAMES = ["8²", "10²", "12²", "16²", "24²", "32²"];
    static var SKEYS = ["bS0", "bS1", "bS2", "bS3", "bS4", "bS5"];

    static var DENS_PCT   = [10, 15, 20, 25, 30];
    static var DENS_NAMES = ["10%", "15%", "20%", "25%", "30%"];

    var state;
    var grid;

    // Menu
    var menuRow;
    var difficulty;
    var bombDensity;

    // Cursor
    var curR;
    var curC;

    // Timing
    var startMs;
    var elapsedMs;
    var bestMs;

    function initialize() {
        state       = GS_MENU;
        grid        = new GridManager();
        menuRow     = MENU_SIZE;
        difficulty  = 3;   // 16×16
        bombDensity = 1;   // 15 %
        curR = 0; curC = 0;
        startMs = 0; elapsedMs = 0;
        bestMs = new [DIFF_COUNT];
        for (var i = 0; i < DIFF_COUNT; i++) { bestMs[i] = _load(SKEYS[i]); }
        var d = _load("lDiff"); if (d >= 0 && d < DIFF_COUNT) { difficulty  = d; }
        var b = _load("lDens"); if (b >= 0 && b < DENS_COUNT)  { bombDensity = b; }
    }

    hidden function _load(k) {
        try { var v = Application.Storage.getValue(k);
              if (v != null && v instanceof Number && v >= 0) { return v; }
        } catch (e) {} return 0;
    }
    hidden function _save(k, v) {
        try { Application.Storage.setValue(k, v); } catch (e) {}
    }

    // ── Menu ──────────────────────────────────────────────────────
    function menuNext()    { menuRow = (menuRow + 1) % MENU_ROW_COUNT; }
    function menuPrev()    { menuRow = (menuRow + MENU_ROW_COUNT - 1) % MENU_ROW_COUNT; }
    function setMenuRow(r) { if (r >= 0 && r < MENU_ROW_COUNT) { menuRow = r; } }

    function menuActivate() {
        if      (menuRow == MENU_SIZE)  { _cycleSize(1); }
        else if (menuRow == MENU_BOMBS) { _cycleDens(1); }
        else if (menuRow == MENU_START) { startGame();   }
        // MENU_LEADER is handled by the view (pushes the scores view).
    }
    function menuValuePrev() {
        if      (menuRow == MENU_SIZE)  { _cycleSize(-1); }
        else if (menuRow == MENU_BOMBS) { _cycleDens(-1); }
    }
    function menuValueNext() {
        if      (menuRow == MENU_SIZE)  { _cycleSize(1); }
        else if (menuRow == MENU_BOMBS) { _cycleDens(1); }
    }
    hidden function _cycleSize(d) {
        difficulty  = (difficulty  + DIFF_COUNT + d) % DIFF_COUNT;
        _save("lDiff", difficulty);
    }
    hidden function _cycleDens(d) {
        bombDensity = (bombDensity + DENS_COUNT + d) % DENS_COUNT;
        _save("lDens", bombDensity);
    }

    // ── Game start ────────────────────────────────────────────────
    function startGame() {
        var sz = SIZES[difficulty];
        var m  = (sz * sz * DENS_PCT[bombDensity]) / 100;
        if (m < 1) { m = 1; }
        var cap = sz * sz - 9; if (cap < 1) { cap = 1; }
        if (m > cap) { m = cap; }
        grid.configure(sz, m);
        curR = sz / 2; curC = sz / 2;
        startMs = 0; elapsedMs = 0;
        state = GS_PLAY;
    }

    function gotoMenu() { state = GS_MENU; }

    // ── Cursor — ONLY movement, never reveal ──────────────────────
    // Bottom button: step right, wrapping within the row.
    function moveCursorHoriz() {
        curC = curC + 1;
        if (curC >= grid.n) { curC = 0; }
    }
    // Upper button: step down, wrapping within the column.
    function moveCursorVert() {
        curR = curR + 1;
        if (curR >= grid.n) { curR = 0; }
    }
    function moveCursorTo(r, c) {
        if (r >= 0 && r < grid.n && c >= 0 && c < grid.n) {
            curR = r; curC = c;
        }
    }

    // ── Reveal / flag ─────────────────────────────────────────────
    function revealAt(r, c) {
        if (state != GS_PLAY) { return; }
        if (grid.floodPending) { return; }   // BFS still running — wait
        if (startMs == 0) { startMs = System.getTimer(); }
        var res = grid.reveal(r, c);
        if (res == REV_BOOM) { _lose(); }
        // Win is checked in floodTick() once the BFS drains
    }
    function revealCursor() { revealAt(curR, curC); }

    // Toggle flag at (r,c) and immediately check for flag-based win.
    function flagAt(r, c) {
        if (state != GS_PLAY) { return; }
        if (startMs == 0) { startMs = System.getTimer(); }
        grid.toggleFlag(r, c);
        if (grid.isWon()) { _win(); }
    }
    function flagCursor() { flagAt(curR, curC); }

    // ── Flood tick (called every timer tick from MainView) ────────
    // Continues the BFS one chunk at a time and checks win after
    // the queue empties so we never do more than MAX_FLOOD_PER_STEP
    // cells in a single callback.
    function floodTick() {
        if (state != GS_PLAY) { return; }
        if (!grid.floodPending) { return; }
        grid.bfsStep();
        if (!grid.floodPending && grid.isWon()) { _win(); }
    }

    // ── Tick ──────────────────────────────────────────────────────
    function tick() {
        if (state == GS_PLAY && startMs > 0) {
            elapsedMs = System.getTimer() - startMs;
        }
    }

    // ── Helpers ───────────────────────────────────────────────────
    function currentMineCount() {
        var sz = SIZES[difficulty];
        var m  = (sz * sz * DENS_PCT[bombDensity]) / 100;
        if (m < 1) { m = 1; }
        var cap = sz * sz - 9; if (cap < 1) { cap = 1; }
        if (m > cap) { m = cap; }
        return m;
    }
    function minesLeft() {
        var m = grid.mineCount - grid.flagCount; return (m < 0) ? 0 : m;
    }
    function bestForCurrent() { return bestMs[difficulty]; }
    function isNewBest() {
        return state == GS_WIN && elapsedMs > 0
            && elapsedMs == bestForCurrent();
    }
    function currentName()        { return NAMES[difficulty];     }
    function currentDensityName() { return DENS_NAMES[bombDensity]; }
    // Leaderboard variant — board size like "16x16".
    function variantStr() {
        return SIZES[difficulty].toString() + "x" + SIZES[difficulty].toString();
    }
    function fmtTime(ms) {
        var s = ms / 1000; if (s > 9999) { s = 9999; } return s.format("%d");
    }

    hidden function _lose() { state = GS_LOSE; grid.revealAllMines(); }
    hidden function _win() {
        state = GS_WIN;
        if (bestMs[difficulty] <= 0 || elapsedMs < bestMs[difficulty]) {
            bestMs[difficulty] = elapsedMs; _save(SKEYS[difficulty], elapsedMs);
        }
        // Submit solve time in whole seconds (lower is better → raw positive).
        var secs = elapsedMs / 1000;
        if (secs < 1) { secs = 1; }
        Leaderboard.submitScore(LB_GAME_ID, secs, variantStr());
        Leaderboard.showPostGame(LB_GAME_ID, variantStr(), "MINESWEEPER");
    }
}
