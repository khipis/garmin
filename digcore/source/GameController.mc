// ═══════════════════════════════════════════════════════════════
// GameController.mc — Boulder-Dash style flow.
//
// States:   DC_MENU → DC_PLAY → DC_WIN | DC_LOSE → DC_MENU
//
// Menu (chess-style, 3 rows):
//   0  Start Level (1..N)
//   1  Lives (1..5)
//   2  START
//
// In play the game runs on a single fixed-rate timer (handled by
// MainView).  Each tick:
//   1. Decrement the time-left counter (every ~10 ticks at 100 ms).
//   2. Step fireflies on every other tick (they move slowly so the
//      player has a fighting chance).
//   3. Settle gravity until the cave is stable or the player is
//      crushed.
//   4. Check collision with fireflies (firefly steps onto player).
//   5. Open the exit once `diamondGoal` is collected.
//   6. Detect win (player at exit) or lose (dead / out of time).
//
// Swipe inputs queue a single move that's applied at the next
// tick — this keeps the game responsive without letting the
// player out-step physics.
// ═══════════════════════════════════════════════════════════════

using Toybox.Application;
using Toybox.System;

const DC_MENU = 0;
const DC_PLAY = 1;
const DC_WIN  = 2;
const DC_LOSE = 3;

const DC_MENU_ROWS = 3;
const DC_BEST_KEY  = "dc_best";

class GameController {
    var state;
    var menuRow;
    var menuStartLevel;
    var menuLives;

    var grid;
    var player;
    var fireflies;
    var exitPos;
    var exitOpen;
    var diamondGoal;
    var timeLeft;          // seconds remaining
    var level;             // 1-based
    var lives;
    var score;
    var bestScore;

    // Pending input: a direction the player has just swiped, applied
    // at the next gameplay tick.  -1 means no input queued.
    var pendingDir;

    // Internal sub-tick counters.
    hidden var _flyTick;
    hidden var _secondTick;

    function initialize() {
        state = DC_MENU;
        menuRow = 0;
        menuStartLevel = 1;
        menuLives      = 3;
        score    = 0;
        bestScore = 0;
        exitOpen  = false;
        player    = new Player();
        fireflies = [];
        var lvl = LevelGenerator.build(0);
        grid        = lvl[0];
        exitPos     = lvl[2];
        diamondGoal = lvl[3];
        timeLeft    = lvl[4];
        level       = 1;
        lives       = 3;
        pendingDir  = -1;
        _flyTick    = 0;
        _secondTick = 0;
        _loadBest();
        _loadSettings();
    }

    // ── Persistence ──────────────────────────────────────────────
    hidden function _loadBest() {
        try {
            var v = Application.Storage.getValue(DC_BEST_KEY);
            if (v != null) { bestScore = v; }
        } catch (e) {}
    }
    hidden function _saveBest() {
        try { Application.Storage.setValue(DC_BEST_KEY, bestScore); } catch (e) {}
    }
    hidden function _loadSettings() {
        try {
            var s = Application.Storage.getValue("dc_slvl");
            if (s instanceof Number && s >= 1 && s <= LevelGenerator.levelCount()) {
                menuStartLevel = s;
            }
        } catch (e) {}
        try {
            var l = Application.Storage.getValue("dc_lives");
            if (l instanceof Number && l >= 1 && l <= 5) { menuLives = l; }
        } catch (e) {}
    }
    hidden function _saveSettings() {
        try { Application.Storage.setValue("dc_slvl",  menuStartLevel); } catch (e) {}
        try { Application.Storage.setValue("dc_lives", menuLives);      } catch (e) {}
    }

    // ── Menu ─────────────────────────────────────────────────────
    function menuNext() { menuRow = (menuRow + 1) % DC_MENU_ROWS; }
    function menuPrev() { menuRow = (menuRow + DC_MENU_ROWS - 1) % DC_MENU_ROWS; }
    function setMenuRow(i) { if (i >= 0 && i < DC_MENU_ROWS) { menuRow = i; } }
    function menuActivate() {
        if (menuRow == 0) {
            menuStartLevel = (menuStartLevel % LevelGenerator.levelCount()) + 1;
            _saveSettings();
        } else if (menuRow == 1) {
            menuLives = (menuLives % 5) + 1;
            _saveSettings();
        } else {
            _startGame();
        }
    }

    function gotoMenu() { state = DC_MENU; }

    // ── Lifecycle ────────────────────────────────────────────────
    hidden function _startGame() {
        level = menuStartLevel;
        lives = menuLives;
        score = 0;
        _buildLevel();
        state = DC_PLAY;
    }

    hidden function _buildLevel() {
        var lvl = LevelGenerator.build(level - 1);
        grid        = lvl[0];
        var sp      = lvl[1];
        exitPos     = lvl[2];
        diamondGoal = lvl[3];
        timeLeft    = lvl[4];
        var flies   = lvl[5];

        player.spawnAt(sp);
        fireflies = [];
        for (var i = 0; i < flies.size(); i++) {
            var f = flies[i];
            fireflies.add(new Firefly(f[0], f[1], f[2]));
        }
        exitOpen   = false;
        pendingDir = -1;
        _flyTick    = 0;
        _secondTick = 0;
    }

    // Called by InputHandler when the player swipes.
    function queueMove(d) {
        if (state != DC_PLAY) { return; }
        pendingDir = d;
    }

    // ── Tick: 100 ms cadence ────────────────────────────────────
    // The view's timer fires every 100 ms and calls this.  We
    // distribute work across sub-ticks so we never spend too long
    // in one frame:
    //   every tick   → consume queued move + settle gravity
    //   every 2nd    → step fireflies
    //   every 10th   → decrement time
    function tick() {
        if (state != DC_PLAY) { return; }

        // 1. Player intent.
        if (pendingDir >= 0) {
            _applyPlayerMove(pendingDir);
            pendingDir = -1;
            if (state != DC_PLAY) { return; }
        }

        // 2. Settle gravity.  Cap iterations so a chain reaction
        //    can't blow the watchdog.
        var crushed = PhysicsSim.settle(grid, player.r, player.c, fireflies, 6);
        if (crushed) { _onPlayerDeath(); return; }

        // 3. Fireflies — every other tick.
        _flyTick = (_flyTick + 1) % 2;
        if (_flyTick == 0) {
            for (var i = 0; i < fireflies.size(); i++) {
                var f = fireflies[i];
                if (!f.alive) { continue; }
                f.step(grid);
                if (f.alive && f.r == player.r && f.c == player.c) {
                    _onPlayerDeath();
                    return;
                }
            }
        }

        // 4. Open exit once diamond goal met.
        if (!exitOpen && player.diamonds >= diamondGoal) {
            grid.set(exitPos[0], exitPos[1], TC_EXIT);
            exitOpen = true;
        }

        // 5. Tick the clock once per second (every 10 frames @ 100 ms).
        _secondTick = (_secondTick + 1) % 10;
        if (_secondTick == 0 && timeLeft > 0) {
            timeLeft = timeLeft - 1;
            if (timeLeft <= 0) {
                _onPlayerDeath();
                return;
            }
        }
    }

    hidden function _applyPlayerMove(d) {
        var res = player.tryMove(grid, d);
        if (res.equals("gem"))  { score = score + 50; }
        else if (res.equals("move")) { score = score + 1; }
        else if (res.equals("push")) { score = score + 5; }
        else if (res.equals("exit")) { _onLevelClear(); return; }

        // After moving, the cell we left is now EMPTY — physics may
        // chain-react in the next tick.  Did we walk straight into a
        // firefly?
        for (var i = 0; i < fireflies.size(); i++) {
            var f = fireflies[i];
            if (f.alive && f.r == player.r && f.c == player.c) {
                _onPlayerDeath();
                return;
            }
        }
    }

    // ── State transitions ──────────────────────────────────────
    hidden function _onPlayerDeath() {
        lives = lives - 1;
        player.alive = false;
        if (lives <= 0) {
            state = DC_LOSE;
            if (score > bestScore) { bestScore = score; _saveBest(); }
            return;
        }
        // Retry the same level.
        _buildLevel();
    }

    hidden function _onLevelClear() {
        // Cap bonus so even slow runs still earn something positive.
        score = score + 200 + level * 50 + timeLeft * 5;
        if (level >= LevelGenerator.levelCount()) {
            state = DC_WIN;
            if (score > bestScore) { bestScore = score; _saveBest(); }
            return;
        }
        level = level + 1;
        _buildLevel();
    }
}
