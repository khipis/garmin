// ═══════════════════════════════════════════════════════════════
// GameController.mc — Game state machine + persistence.
//
// States:
//   GS_MENU    title screen — START / How to play / Reset best
//   GS_PLAY    live 4×4 game; reacts to swipe directions
//   GS_WIN     2048 reached for the first time this run — player may
//              continue playing for a higher score
//   GS_OVER    no more moves possible
//
// Score:
//   `score`         resets each new run, +sum of merged tile values
//   `best`          highest score ever, persisted via Application.Storage
//   `bestExp`       largest tile reached ever, persisted similarly
//
// Win condition:
//   The first move that creates a 2048 tile transitions to GS_WIN.
//   The player can then return to GS_PLAY to keep going for a
//   higher score. After GS_WIN, further 2048 tiles do not retrigger.
// ═══════════════════════════════════════════════════════════════

using Toybox.Application;
using Toybox.System;

const GS_MENU = 0;
const GS_PLAY = 1;
const GS_WIN  = 2;
const GS_OVER = 3;

// Menu items
const MI_START       = 0;
const MI_MODE        = 1;   // Classic (endless score) / Time (fastest to 2048)
const MI_LEADERBOARD = 2;
const MI_RESET_BEST  = 3;
const MI_ITEMS       = 4;

// Leaderboard game ids (match _LOGOS / web ids).
//   classic → highest score (DESC)
//   time    → fastest time to reach the 2048 tile, in seconds (ASC). It needs
//             its own id because the backend sort direction is per-game.
const LB_GAME_ID      = "twentyfortyeight";
const LB_GAME_ID_TIME = "twentyfortyeight_time";

class GameController {
    var state;
    var grid;
    var score;
    var best;
    var bestExp;
    var hasWonThisRun;     // true once player has hit 2048 in current run
    var menuCursor;

    // ── Time mode (speedrun: fastest to the 2048 tile) ──────────────
    var timeMode;          // false = Classic endless score, true = Time
    var elapsedMs;         // running time this run (Time mode only)
    var lastTimeMs;        // time of the run that just reached 2048
    var bestTimeMs;        // fastest 2048 time ever (persisted), -1 = none
    hidden var _startMs;   // System.getTimer() at run start

    function initialize() {
        state          = GS_MENU;
        grid           = new GridManager();
        score          = 0;
        best           = _loadInt("best",    0);
        bestExp        = _loadInt("bestExp", 0);
        hasWonThisRun  = false;
        menuCursor     = MI_START;
        timeMode       = _loadBool("tf_timemode", false);
        elapsedMs      = 0;
        lastTimeMs     = 0;
        bestTimeMs     = _loadInt("tf_besttime", -1);
        _startMs       = 0;
    }

    hidden function _loadBool(key, dflt) {
        try {
            var v = Application.Storage.getValue(key);
            if (v instanceof Boolean) { return v; }
        } catch (e) {}
        return dflt;
    }

    hidden function _loadInt(key, dflt) {
        try {
            var v = Application.Storage.getValue(key);
            if (v != null && v instanceof Number && v >= 0) { return v; }
        } catch (e) {}
        return dflt;
    }
    hidden function _saveInt(key, v) {
        try { Application.Storage.setValue(key, v); } catch (e) {}
    }

    // ── Menu actions ────────────────────────────────────────────────
    function menuPrev() {
        menuCursor = (menuCursor + MI_ITEMS - 1) % MI_ITEMS;
    }
    function menuNext() {
        menuCursor = (menuCursor + 1) % MI_ITEMS;
    }
    function menuActivate() {
        if (menuCursor == MI_START) {
            newGame();
        } else if (menuCursor == MI_MODE) {
            timeMode = !timeMode;
            try { Application.Storage.setValue("tf_timemode", timeMode); } catch (e) {}
        } else if (menuCursor == MI_RESET_BEST) {
            best = 0;
            bestExp = 0;
            _saveInt("best",    0);
            _saveInt("bestExp", 0);
        }
    }

    function modeName() { return timeMode ? "Time" : "Classic"; }

    // Format milliseconds as "mm:ss" (caps at 99:59).
    function fmtMs(ms) {
        if (ms < 0) { return "--:--"; }
        var s = ms / 1000;
        var m = s / 60;
        s = s % 60;
        if (m > 99) { m = 99; s = 59; }
        return m.format("%02d") + ":" + s.format("%02d");
    }

    // ── Game flow ───────────────────────────────────────────────────
    function newGame() {
        grid.clear();
        grid.spawnRandom();
        grid.spawnRandom();
        score = 0;
        hasWonThisRun = false;
        elapsedMs  = 0;
        lastTimeMs = 0;
        _startMs   = System.getTimer();
        state = GS_PLAY;
    }

    // Called from the view's timer (Time mode only) to keep the on-screen
    // stopwatch current while playing.
    function tickTimer() {
        if (state != GS_PLAY || !timeMode) { return; }
        var dt = System.getTimer() - _startMs;
        if (dt < 0) { dt = 0; }
        elapsedMs = dt;
    }

    function gotoMenu() { state = GS_MENU; }

    // Continue playing after hitting 2048 (one-shot toggle).
    function continueAfterWin() {
        if (state == GS_WIN) { state = GS_PLAY; }
    }

    // ── Swipe handler ───────────────────────────────────────────────
    // Called by InputHandler with one of DIR_*. Applies the move,
    // updates score/best, spawns a tile, and transitions state if a
    // win/loss happened.
    function tryMove(dir) {
        if (state != GS_PLAY) { return; }
        var r = MergeEngine.applyMove(grid, dir);
        if (!r.moved) { return; }

        if (r.gained > 0) {
            score = score + r.gained;
            if (score > best) {
                best = score;
                _saveInt("best", best);
            }
        }

        var top = grid.maxExp();
        if (top > bestExp) {
            bestExp = top;
            _saveInt("bestExp", bestExp);
        }

        // Spawn first, then check for game-over so the player sees
        // the freshly-placed tile on the over screen.
        grid.spawnRandom();

        if (r.reached2048 && !hasWonThisRun) {
            hasWonThisRun = true;
            // Time mode: reaching 2048 IS the goal — lock the time, save the
            // best, and submit it to the speedrun leaderboard (lower is better).
            if (timeMode) {
                var dt = System.getTimer() - _startMs;
                if (dt < 0) { dt = 0; }
                elapsedMs  = dt;
                lastTimeMs = dt;
                if (bestTimeMs < 0 || dt < bestTimeMs) {
                    bestTimeMs = dt;
                    _saveInt("tf_besttime", dt);
                }
                var secs = dt / 1000;
                if (secs < 1) { secs = 1; }
                Leaderboard.submitScore(LB_GAME_ID_TIME, secs, "");
                Leaderboard.showPostGame(LB_GAME_ID_TIME, "", "2048 TIME");
            }
            state = GS_WIN;
            return;
        }

        if (!grid.hasAnyMove()) {
            state = GS_OVER;
            // Classic only: submit final score (higher is better). Time-mode
            // runs that never reached 2048 simply don't post.
            if (!timeMode) {
                Leaderboard.submitScore(LB_GAME_ID, score, "");
                Leaderboard.showPostGame(LB_GAME_ID, "", "2048");
            }
        }
    }
}
