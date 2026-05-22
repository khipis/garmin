// ═══════════════════════════════════════════════════════════════
// GameController.mc — Game-state machine + per-puzzle book-keeping.
//
// States:
//   GS_MENU       main menu (mode / difficulty / start)
//   GS_PLAY       puzzle in progress
//   GS_PAUSED     freeze the timer (player paused)
//   GS_COMPLETE   puzzle solved
//   GS_FAILED     strict-mode invalid submission
//
// Time tracking: started_ms recorded on transition to GS_PLAY,
// then accumulated elapsed_ms incremented whenever the controller is
// stepped (pauses subtracted automatically).
//
// Hi-score (fastest solve time) is persisted per (mode, difficulty)
// in App Storage so it survives reboots.
// ═══════════════════════════════════════════════════════════════

using Toybox.System;
using Toybox.Application;

const GS_MENU     = 0;
const GS_PLAY     = 1;
const GS_PAUSED   = 2;
const GS_COMPLETE = 3;
const GS_FAILED   = 4;

const MODE_QUICK   = 0;   // 4x4
const MODE_CLASSIC = 1;   // 9x9

// Validation strategy
const VAL_RELAXED = 0;    // highlight conflicts immediately
const VAL_STRICT  = 1;    // only validate on submit

class GameController {

    var state;
    var mode;            // MODE_QUICK / MODE_CLASSIC
    var diff;            // DIFF_EASY / DIFF_MED / DIFF_HARD
    var valMode;         // VAL_RELAXED / VAL_STRICT

    var grid;            // SudokuGrid
    var gen;             // SudokuGenerator

    // Cursor (in cell coordinates)
    var curR;
    var curC;

    // Menu cursor (0..3)
    var menuSel;

    // Time tracking — milliseconds since the puzzle started, accumulated
    // across pause sessions. _lastResume holds the system-ms of the most
    // recent transition INTO GS_PLAY.
    var elapsedMs;
    hidden var _lastResume;

    // Best (lowest) solve time per (mode, difficulty) — persisted.
    // bestKey() builds a unique storage key.
    var bestMs;          // current best for the active (mode, diff) combo

    // Last-completed time (shown on the GS_COMPLETE screen).
    var lastTimeMs;

    // True when the player has just made progress and the UI needs
    // an immediate redraw (set by setCell, clearCell, etc).
    var dirty;

    function initialize() {
        state    = GS_MENU;
        mode     = MODE_CLASSIC;
        diff     = DIFF_EASY;
        valMode  = VAL_RELAXED;
        menuSel  = 0;
        grid     = new SudokuGrid();
        gen      = new SudokuGenerator();
        curR     = 0; curC = 0;
        elapsedMs   = 0;
        _lastResume = 0;
        bestMs      = -1;
        lastTimeMs  = 0;
        dirty       = true;
    }

    // Persisted-best key (one record per mode+difficulty).
    function bestKey() {
        return "best_" + mode.format("%d") + "_" + diff.format("%d");
    }

    function loadBest() {
        try {
            var v = Application.Storage.getValue(bestKey());
            if (v != null && v instanceof Number && v > 0) {
                bestMs = v;
                return;
            }
        } catch (e) { }
        bestMs = -1;
    }

    function saveBestIfBetter(ms) {
        if (bestMs < 0 || ms < bestMs) {
            bestMs = ms;
            try { Application.Storage.setValue(bestKey(), ms); } catch (e) { }
        }
    }

    // ── Game flow ────────────────────────────────────────────────────
    function startGame() {
        var size = (mode == MODE_QUICK) ? SZ_4 : SZ_9;
        grid.setSize(size);
        var pair = gen.generate(size, diff);
        grid.loadPuzzle(pair[0], pair[1]);

        // Cursor lands on first empty cell (or 0,0 if all are clues).
        curR = 0; curC = 0;
        var n = grid.n;
        var found = false;
        for (var r = 0; r < n && !found; r++) {
            for (var c = 0; c < n && !found; c++) {
                if (!grid.isFixed(r, c)) { curR = r; curC = c; found = true; }
            }
        }

        if (valMode == VAL_RELAXED) { grid.recomputeErrors(); }
        loadBest();

        elapsedMs   = 0;
        _lastResume = System.getTimer();
        state = GS_PLAY;
        dirty = true;
    }

    // Call from a periodic timer (or on demand) — updates `elapsedMs`
    // while the puzzle is being played.
    function tickTimer() {
        if (state != GS_PLAY) { return; }
        var now = System.getTimer();
        var dt  = now - _lastResume;
        if (dt < 0) { dt = 0; }
        elapsedMs   = elapsedMs + dt;
        _lastResume = now;
    }

    function pause() {
        if (state != GS_PLAY) { return; }
        tickTimer();
        state = GS_PAUSED;
        dirty = true;
    }

    function resume() {
        if (state != GS_PAUSED) { return; }
        _lastResume = System.getTimer();
        state = GS_PLAY;
        dirty = true;
    }

    // Back out of GS_FAILED into GS_PLAY so the player can fix conflicts.
    // Restarts the elapsed-time clock from now (no time is added during
    // the failed-overlay viewing).
    function resumeFromFailed() {
        if (state != GS_FAILED) { return; }
        _lastResume = System.getTimer();
        state = GS_PLAY;
        dirty = true;
    }

    // Return to menu (cancel current puzzle).
    function gotoMenu() {
        state   = GS_MENU;
        menuSel = 0;
        dirty   = true;
    }

    // ── Cell edit API (used by InputHandler) ─────────────────────────
    function moveCursor(dr, dc) {
        if (state != GS_PLAY) { return; }
        var n = grid.n;
        curR = (curR + dr + n) % n;
        curC = (curC + dc + n) % n;
        dirty = true;
    }

    function setCellTo(value) {
        if (state != GS_PLAY) { return; }
        if (!grid.setValue(curR, curC, value)) { return; }
        if (valMode == VAL_RELAXED) { grid.recomputeErrors(); }
        dirty = true;
        _checkAutoComplete();
    }

    function clearCell() { setCellTo(0); }

    // Cycle the current cell's digit 1..n → 0 → 1.
    function cycleCell(forward) {
        if (state != GS_PLAY) { return; }
        if (grid.isFixed(curR, curC)) { return; }
        var n = grid.n;
        var cur = grid.getValue(curR, curC);
        var next;
        if (forward) {
            next = (cur >= n) ? 0 : (cur + 1);
        } else {
            next = (cur <= 0) ? n : (cur - 1);
        }
        setCellTo(next);
    }

    // In relaxed mode, if the player completes the puzzle perfectly,
    // transition to COMPLETE automatically. Strict mode requires submit.
    hidden function _checkAutoComplete() {
        if (valMode != VAL_RELAXED) { return; }
        if (grid.emptyCount() != 0) { return; }
        if (grid.isComplete())      { _finishWin(); }
    }

    // Player explicitly submits the board (Strict mode).
    function submit() {
        if (state != GS_PLAY) { return; }
        if (grid.isFilledAndValid() && grid.isComplete()) {
            _finishWin();
        } else {
            state = GS_FAILED;
            dirty = true;
        }
    }

    hidden function _finishWin() {
        tickTimer();
        lastTimeMs = elapsedMs;
        saveBestIfBetter(lastTimeMs);
        state = GS_COMPLETE;
        dirty = true;
    }

    // Format milliseconds as "mm:ss" (caps at 99:59).
    function fmtMs(ms) {
        if (ms < 0) { return "--:--"; }
        var s = ms / 1000;
        var m = s / 60;
        s = s % 60;
        if (m > 99) { m = 99; s = 59; }
        return m.format("%02d") + ":" + s.format("%02d");
    }
}
