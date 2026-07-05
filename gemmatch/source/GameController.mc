// ═══════════════════════════════════════════════════════════════
// GameController.mc — State machine + scoring + cascade orchestrator.
//
// States:
//   GS_MENU    chess-style menu (3 rows: Mode / Param / Start)
//   GS_PLAY    game running
//   GS_OVER    round ended, score frozen
//
// Game Modes:
//   GM_TIME    Time Attack — score before the clock hits zero
//   GM_ZEN     Zen — no timer; back button ends the session
//   GM_MOVES   Moves — each successful match costs one move;
//              run out of moves → game over
//
// Menu rows (MENU_MODE / MENU_PARAM / MENU_START):
//   MODE  cycles: Time Attack → Zen → Moves
//   PARAM cycles: time presets (GM_TIME) or move-count presets (GM_MOVES)
//                 shows "Endless" and is inert for GM_ZEN
//   START begins the game
//
// Tap on a gem only positions the cursor (no implicit pick).
// SELECT button / long-press picks/swaps — keeps the two-button
// scheme usable while making tapping feel like natural cursor nav.
// Swipe directly swaps the cursor gem — best gesture for touch.
//
// Animation state machine (runs alongside GS_PLAY):
//   ANIM_NONE   idle
//   ANIM_SWAP   gems sliding (ANIM_SWAP_FRAMES × 50 ms).
//               animReverse=false = forward; true = bounce-back.
//   ANIM_FLASH  matched gems glowing (ANIM_FLASH_FRAMES × 50 ms)
//               before they clear.
//   ANIM_FALL   gravity-fallen + freshly-spawned gems tumbling into
//               place (ANIM_FALL_FRAMES × 50 ms). Once settled, the
//               board is rescanned — a new match flips back to
//               ANIM_FLASH, so FLASH→FALL→FLASH→… is the visible
//               chain-reaction loop the player watches play out.
//
// Power gems: any match of 4+ leaves one BOMB gem behind (see
// Tile.TILE_BOMB). Clearing a bomb (via a later match, a chain blast,
// or swapping directly into it) detonates a 3×3 area — which can
// catch further bombs and keep the chain going (MatchEngine handles
// the propagation via expandBombChains()).
// ═══════════════════════════════════════════════════════════════

using Toybox.System;
using Toybox.Application;

const GS_MENU = 0;
const GS_PLAY = 1;
const GS_OVER = 2;

const GM_TIME  = 0;   // Time Attack
const GM_ZEN   = 1;   // Zen (no limit)
const GM_MOVES = 2;   // Limited moves

const MENU_MODE  = 0;
const MENU_PARAM = 1;   // time limit or move count (inert in ZEN)
const MENU_START = 2;
const MENU_LB    = 3;   // global leaderboard (pushed by the view layer)
const MENU_ROW_COUNT = 4;

// Global leaderboard game id (matches _LOGOS / web id).
const LB_GAME_ID = "gemmatch";

const ANIM_NONE  = 0;
const ANIM_SWAP  = 1;
const ANIM_FLASH = 2;
const ANIM_FALL  = 3;

const ANIM_SWAP_FRAMES  = 4;   // 4 × 50 ms = 200 ms
const ANIM_FLASH_FRAMES = 5;   // 5 × 50 ms = 250 ms
const ANIM_FALL_FRAMES  = 6;   // 6 × 50 ms = 300 ms

class GameController {

    // Time-attack presets
    static var TIME_MS    = [30000, 60000, 90000, 120000, 180000];
    static var TIME_NAMES = ["30s", "1min", "90s", "2min", "3min"];
    static var TIME_COUNT = 5;

    // Moves-mode presets
    static var MOVES_VALS  = [10, 15, 20, 30];
    static var MOVES_NAMES = ["10", "15", "20", "30"];
    static var MOVES_COUNT = 4;

    var state;
    var grid;
    var engine;

    // Menu state
    var menuRow;
    var gameMode;
    var timeIdx;
    var movesIdx;

    // Cursor + selection
    var curR;
    var curC;
    var selR;
    var selC;

    // Score / per-mode bests
    var score;
    var hiTime;
    var hiZen;
    var hiMoves;

    // Timing
    var roundMs;       // active round length (0 = no limit)
    var lastTickMs;
    var elapsedMs;

    // Moves mode
    var movesLeft;
    var movesTotal;

    // UI feedback
    var lastCascade;
    var lastClearScore;
    var msgT;          // ms remaining for transient message
    var msg;
    var invalidFlash;  // frames for red cursor on bad swap

    // Chain-reaction feedback
    var cascadeDepth;    // current chain depth within the active cascade
    var bestChainRun;    // longest chain reached so far this run
    var bombsPopped;     // bombs detonated so far this run
    var chainPopT;       // ms remaining for the floating "+score" popup
    var boomT;           // ms remaining for the big "BOOM!" banner
    var shakeT;          // frames of screen shake remaining

    // Animation state
    var animState;
    var animFrame;
    var animReverse;
    var animR1; var animC1;
    var animR2; var animC2;
    var animGem1; var animGem2;
    var animMarks;
    var fallFrom;      // Int[rows*cols] — per-cell source row during ANIM_FALL

    function initialize() {
        state    = GS_MENU;
        grid     = new GridManager();
        engine   = new MatchEngine();

        menuRow  = MENU_MODE;
        gameMode = GM_TIME;
        timeIdx  = 2;    // default 90 s
        movesIdx = 2;    // default 20 moves

        curR = 0; curC = 0;
        selR = -1; selC = -1;

        score   = 0;
        hiTime  = _load("hi_t");
        hiZen   = _load("hi_z");
        hiMoves = _load("hi_m");

        roundMs    = TIME_MS[timeIdx];
        lastTickMs = 0;
        elapsedMs  = 0;
        movesLeft  = 0;
        movesTotal = MOVES_VALS[movesIdx];

        lastCascade    = 0;
        lastClearScore = 0;
        msgT           = 0;
        msg            = "";
        invalidFlash   = 0;

        cascadeDepth = 0;
        bestChainRun = 0;
        bombsPopped  = 0;
        chainPopT    = 0;
        boomT        = 0;
        shakeT       = 0;

        animState   = ANIM_NONE;
        animFrame   = 0;
        animReverse = false;
        animR1 = 0; animC1 = 0;
        animR2 = 0; animC2 = 0;
        animGem1 = 0; animGem2 = 0;
        animMarks = null;
        fallFrom  = new [grid.rows * grid.cols];

        // Restore last-used settings
        var gm = _load("gm_mode"); if (gm >= 0 && gm < 3)            { gameMode = gm; }
        var ti = _load("gm_tidx"); if (ti >= 0 && ti < TIME_COUNT)   { timeIdx  = ti; }
        var mi = _load("gm_midx"); if (mi >= 0 && mi < MOVES_COUNT)  { movesIdx = mi; }
        roundMs    = TIME_MS[timeIdx];
        movesTotal = MOVES_VALS[movesIdx];
    }

    // ── Persistence ─────────────────────────────────────────────────
    hidden function _load(key) {
        try {
            var v = Application.Storage.getValue(key);
            if (v != null && v instanceof Number) { return v; }
        } catch (e) {}
        return -1;
    }
    hidden function _save(key, val) {
        try { Application.Storage.setValue(key, val); } catch (e) {}
    }
    hidden function _saveSettings() {
        _save("gm_mode", gameMode);
        _save("gm_tidx", timeIdx);
        _save("gm_midx", movesIdx);
    }

    // Returns the best score for the currently selected mode.
    function currentBest() {
        if (gameMode == GM_TIME)  { return hiTime;  }
        if (gameMode == GM_ZEN)   { return hiZen;   }
        if (gameMode == GM_MOVES) { return hiMoves; }
        return 0;
    }
    hidden function _updateBest() {
        if (gameMode == GM_TIME  && score > hiTime)  { hiTime  = score; _save("hi_t", hiTime);  }
        if (gameMode == GM_ZEN   && score > hiZen)   { hiZen   = score; _save("hi_z", hiZen);   }
        if (gameMode == GM_MOVES && score > hiMoves) { hiMoves = score; _save("hi_m", hiMoves); }
    }

    // ── Menu actions ─────────────────────────────────────────────────
    function menuNext() { menuRow = (menuRow + 1) % MENU_ROW_COUNT; }
    function menuPrev() { menuRow = (menuRow + MENU_ROW_COUNT - 1) % MENU_ROW_COUNT; }
    function setMenuRow(r) {
        if (r >= 0 && r < MENU_ROW_COUNT) { menuRow = r; }
    }

    // Activate the focused row (chess doSelect equivalent).
    function menuActivate() {
        if (menuRow == MENU_MODE)  { _cycleMode(1);  return; }
        if (menuRow == MENU_PARAM) { _cycleParam(1); return; }
        if (menuRow == MENU_START) { startGame();    return; }
        // MENU_LB is handled by MainView.openLeaderboard() (pushes a view).
    }
    function menuValueNext() {
        if (menuRow == MENU_MODE)  { _cycleMode(1);  return; }
        if (menuRow == MENU_PARAM) { _cycleParam(1); return; }
    }
    function menuValuePrev() {
        if (menuRow == MENU_MODE)  { _cycleMode(-1);  return; }
        if (menuRow == MENU_PARAM) { _cycleParam(-1); return; }
    }

    hidden function _cycleMode(dir) {
        gameMode = (gameMode + 3 + dir) % 3;
        _saveSettings();
    }
    hidden function _cycleParam(dir) {
        if (gameMode == GM_TIME) {
            timeIdx  = (timeIdx  + TIME_COUNT  + dir) % TIME_COUNT;
            roundMs  = TIME_MS[timeIdx];
            _saveSettings();
        } else if (gameMode == GM_MOVES) {
            movesIdx   = (movesIdx + MOVES_COUNT + dir) % MOVES_COUNT;
            movesTotal = MOVES_VALS[movesIdx];
            _saveSettings();
        }
        // ZEN: param row is inert
    }

    // Human-readable strings used by the menu renderer.
    function modeLabel() {
        if (gameMode == GM_TIME)  { return "Time Attack"; }
        if (gameMode == GM_ZEN)   { return "Zen";         }
        return "Moves";
    }
    function paramLabel() {
        if (gameMode == GM_TIME)  { return "Time: "  + TIME_NAMES[timeIdx];  }
        if (gameMode == GM_ZEN)   { return "Play: Endless";                   }
        return "Moves: " + MOVES_NAMES[movesIdx];
    }

    // ── Lifecycle ────────────────────────────────────────────────────
    function startGame() {
        grid.fillNoMatches();
        var safety = 0;
        while (!grid.hasAnyValidMove() && safety < 6) {
            grid.fillNoMatches(); safety = safety + 1;
        }
        curR = grid.rows / 2; curC = grid.cols / 2;
        selR = -1; selC = -1;
        score          = 0;
        lastCascade    = 0;
        lastClearScore = 0;
        msgT           = 0;
        msg            = "";
        invalidFlash   = 0;
        cascadeDepth   = 0;
        bestChainRun   = 0;
        bombsPopped    = 0;
        chainPopT      = 0;
        boomT          = 0;
        shakeT         = 0;
        animState      = ANIM_NONE;
        animFrame      = 0;
        animReverse    = false;
        animMarks      = null;

        if (gameMode == GM_TIME) {
            roundMs    = TIME_MS[timeIdx];
        } else if (gameMode == GM_MOVES) {
            movesTotal = MOVES_VALS[movesIdx];
            movesLeft  = movesTotal;
            roundMs    = 0;
        } else {
            roundMs = 0;   // ZEN: no limit
        }

        var now    = System.getTimer();
        lastTickMs = now;
        elapsedMs  = 0;
        state      = GS_PLAY;
    }

    // Ends a ZEN session (called when back is pressed during ZEN play).
    function endZen() {
        if (state == GS_PLAY && gameMode == GM_ZEN) { _endGame(); }
    }

    // Called every 50 ms from MainView.
    function tick50ms() {
        // ── Animation ─────────────────────────────────────────────────
        if (animState == ANIM_SWAP) {
            animFrame = animFrame + 1;
            if (animFrame >= ANIM_SWAP_FRAMES) {
                if (!animReverse) {
                    _finishSwapIn();
                } else {
                    animState   = ANIM_NONE;
                    animFrame   = 0;
                    animReverse = false;
                }
            }
        } else if (animState == ANIM_FLASH) {
            animFrame = animFrame + 1;
            if (animFrame >= ANIM_FLASH_FRAMES) {
                _clearAndDrop();
            }
        } else if (animState == ANIM_FALL) {
            animFrame = animFrame + 1;
            if (animFrame >= ANIM_FALL_FRAMES) {
                _afterFall();
            }
        }
        if (shakeT > 0)   { shakeT = shakeT - 1; }
        if (boomT > 0)    { boomT = boomT - 50; if (boomT < 0) { boomT = 0; } }
        if (chainPopT > 0){ chainPopT = chainPopT - 50; if (chainPopT < 0) { chainPopT = 0; } }

        // ── Game clock ────────────────────────────────────────────────
        if (state != GS_PLAY) { return; }
        var now = System.getTimer();
        var dt  = now - lastTickMs;
        if (dt < 0) { dt = 0; }
        elapsedMs  = elapsedMs + dt;
        lastTickMs = now;
        if (msgT > 0) { msgT = msgT - 50; if (msgT < 0) { msgT = 0; } }
        if (invalidFlash > 0) { invalidFlash = invalidFlash - 1; }

        // Time-attack: end when timer hits zero.
        // ZEN and MOVES: no auto-end; tick just accumulates elapsed.
        if (gameMode == GM_TIME && elapsedMs >= roundMs) { _endGame(); }
    }

    hidden function _finishSwapIn() {
        grid.swap(animR1, animC1, animR2, animC2);
        var t1 = grid.get(animR1, animC1);
        var t2 = grid.get(animR2, animC2);
        // Swapping directly into a bomb always detonates it, even if the
        // swap alone wouldn't otherwise form a match — a deliberate,
        // rewarding "power move" for the player.
        var bombSwap = (t1 == TILE_BOMB || t2 == TILE_BOMB);
        if (!bombSwap && !engine.anyMatch(grid)) {
            grid.swap(animR1, animC1, animR2, animC2);
            animReverse  = true;
            animFrame    = 0;
            invalidFlash = 20;
            return;
        }
        // Successful match — cost one move in GM_MOVES
        if (gameMode == GM_MOVES) {
            movesLeft = movesLeft - 1;
            if (movesLeft < 0) { movesLeft = 0; }
        }
        cascadeDepth = 0;
        if (bombSwap) {
            _prepMarks(animR1, animC1, animR2, animC2);
        } else {
            _prepMarks(-1, -1, -1, -1);
        }
        animMarks = engine.getMarks();
        animState = ANIM_FLASH;
        animFrame = 0;
    }

    // Rescans for matches, optionally detonating a directly-swapped bomb
    // first, then lets any bomb adjacent to the resulting marks chain-blast
    // too. Leaves the final marks in engine.getMarks().
    hidden function _prepMarks(bR1, bC1, bR2, bC2) {
        engine.markOnly(grid);
        if (bR1 >= 0) { engine.markBombBlast(grid, bR1, bC1); }
        if (bR2 >= 0) { engine.markBombBlast(grid, bR2, bC2); }
        engine.expandBombChains(grid);
    }

    // Flash phase finished — clear the marked cells (bomb-spawns survive
    // as new bombs), score the step, then animate gravity/refill.
    hidden function _clearAndDrop() {
        var total   = grid.rows * grid.cols;
        var marks   = engine.getMarks();
        var boomed  = false;
        for (var i = 0; i < total; i++) {
            if (marks[i] && grid.cells[i] == TILE_BOMB) { boomed = true; break; }
        }

        var cleared = engine.clearMarked(grid);
        cascadeDepth   = cascadeDepth + 1;
        var added      = cleared * 10 * cascadeDepth;
        score          = score + added;
        lastClearScore = added;
        chainPopT      = 700;

        if (boomed) {
            bombsPopped = bombsPopped + 1;
            boomT  = 650;
            shakeT = 14;
        } else if (cascadeDepth >= 3) {
            shakeT = 4 + cascadeDepth; if (shakeT > 12) { shakeT = 12; }
        }

        if (fallFrom == null || fallFrom.size() != total) { fallFrom = new [total]; }
        for (var i2 = 0; i2 < total; i2++) { fallFrom[i2] = i2 / grid.cols; }
        grid.applyGravityAnimated(fallFrom);
        grid.refillAnimated(fallFrom);

        animMarks = null;
        animState = ANIM_FALL;
        animFrame = 0;
    }

    // Gems have settled — rescan. A new match (or a bomb chaining off the
    // settled board) loops back to ANIM_FLASH; otherwise the cascade ends.
    hidden function _afterFall() {
        _prepMarks(-1, -1, -1, -1);
        var marks = engine.getMarks();
        var total = grid.rows * grid.cols;
        var any   = false;
        for (var i = 0; i < total; i++) { if (marks[i]) { any = true; break; } }

        if (any) {
            animMarks = marks;
            animState = ANIM_FLASH;
            animFrame = 0;
            return;
        }

        // Cascade sequence finished.
        if (cascadeDepth > bestChainRun) { bestChainRun = cascadeDepth; }
        lastCascade = cascadeDepth;
        msgT = 2500;
        msg  = (cascadeDepth >= 2) ? ("CHAIN x" + cascadeDepth.format("%d")) : "";

        var safety = 0;
        while (!grid.hasAnyValidMove() && safety < 4) {
            grid.fillNoMatches();
            while (engine.findAndClear(grid) > 0) { grid.applyGravity(); grid.refill(); }
            safety = safety + 1;
        }

        animState = ANIM_NONE;
        animFrame = 0;

        // Moves mode: end game when all moves are spent
        if (gameMode == GM_MOVES && movesLeft <= 0) { _endGame(); }
    }

    // Returns ms remaining (time-attack only; 0 otherwise).
    function timeLeftMs() {
        if (gameMode == GM_TIME) {
            var t = roundMs - elapsedMs;
            return (t < 0) ? 0 : t;
        }
        return 0;
    }

    hidden function _endGame() {
        state = GS_OVER;
        _updateBest();
        // Submit the finished round's score to the global leaderboard,
        // plus the fun secondary chain-reaction stats for this run.
        Leaderboard.submitScore(LB_GAME_ID, score, "");
        if (bestChainRun > 0) { Leaderboard.submitScore(LB_GAME_ID, bestChainRun, "chain"); }
        if (bombsPopped  > 0) { Leaderboard.submitScore(LB_GAME_ID, bombsPopped,  "bombs"); }
        Leaderboard.showPostGame(LB_GAME_ID, "", "GEM MATCH");
    }

    function gotoMenu() {
        state = GS_MENU;
        selR = -1; selC = -1;
    }

    function isAnimating() { return animState != ANIM_NONE; }

    // ── Swap entry-point ─────────────────────────────────────────────
    function beginSwap(r1, c1, r2, c2) {
        if (state != GS_PLAY || animState != ANIM_NONE) { return; }
        if (!grid.isAdjacent(r1, c1, r2, c2)) { invalidFlash = 20; return; }
        animR1      = r1; animC1 = c1;
        animR2      = r2; animC2 = c2;
        animGem1    = grid.get(r1, c1);
        animGem2    = grid.get(r2, c2);
        animReverse = false;
        animState   = ANIM_SWAP;
        animFrame   = 0;
        animMarks   = null;
        curR = r1; curC = c1;
        selR = -1; selC = -1;
    }

    // ── Cursor / selection ───────────────────────────────────────────
    function moveCursor(dr, dc) {
        if (state != GS_PLAY || animState != ANIM_NONE) { return; }
        if (selR >= 0) {
            var tr = selR + dr;
            var tc = selC + dc;
            if (tr < 0 || tr >= grid.rows || tc < 0 || tc >= grid.cols) {
                selR = -1; selC = -1; return;
            }
            var sr = selR; var sc = selC;
            selR = -1; selC = -1;
            beginSwap(sr, sc, tr, tc);
            return;
        }
        var nr = curR + dr;
        var nc = curC + dc;
        if (nr < 0)          { nr = grid.rows - 1; }
        if (nr >= grid.rows) { nr = 0; }
        if (nc < 0)          { nc = grid.cols - 1; }
        if (nc >= grid.cols) { nc = 0; }
        curR = nr; curC = nc;
    }

    // SELECT: pick/swap at cursor (button workflow).
    function selectAction() {
        if (state == GS_MENU) { menuActivate(); return; }
        if (state == GS_OVER) { gotoMenu();     return; }
        if (state != GS_PLAY || animState != ANIM_NONE) { return; }

        if (selR < 0) {
            selR = curR; selC = curC;
            return;
        }
        if (selR == curR && selC == curC) {
            selR = -1; selC = -1; return;
        }
        if (grid.isAdjacent(selR, selC, curR, curC)) {
            var sr = selR; var sc = selC;
            selR = -1; selC = -1;
            beginSwap(sr, sc, curR, curC);
        } else {
            selR = curR; selC = curC;
        }
    }

    // Tap a cell — moves cursor there (no implicit pick).
    // Exception: if a gem is already selected and the tapped cell
    // is adjacent, immediately attempt the swap (tap-pick-then-tap
    // workflow still works naturally via SELECT-then-tap).
    function tapCell(r, c) {
        if (state != GS_PLAY || animState != ANIM_NONE) { return; }
        if (selR >= 0) {
            if (selR == r && selC == c) {
                selR = -1; selC = -1; return;   // deselect
            }
            if (grid.isAdjacent(selR, selC, r, c)) {
                var sr = selR; var sc = selC;
                selR = -1; selC = -1;
                beginSwap(sr, sc, r, c);        // swap
                return;
            }
            selR = -1; selC = -1;               // deselect on non-adjacent tap
        }
        curR = r; curC = c;                     // just move cursor
    }

    // Format ms → "MM:SS".
    function fmtSec(ms) {
        if (ms < 0) { ms = 0; }
        var s = ms / 1000;
        var m = s / 60;
        s = s % 60;
        if (m > 99) { m = 99; s = 59; }
        return m.format("%02d") + ":" + s.format("%02d");
    }
}
