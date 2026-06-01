// ═══════════════════════════════════════════════════════════════
// GameController.mc — GyroMaze state machine + game loop.
//
// Menu (3 chess-style rows):
//   0  Diff   Easy 7×7 / Med 9×9 / Hard 11×11
//   1  Biome  Random / Normal / Ice / Trap / Speed / Chaos
//   2  START
//
// Persistence keys:
//   gm_diff, gm_biome           — menu settings
//   gm_level                    — current level index (seed driver)
//   gm_best_0/1/2               — best time ms per difficulty
//
// Level seed: diff * 100000 + level * 137.
//   → same (diff, level) always produces the same maze.
//   → daily mode: seed = 0 + doy * 137.
//
// Cell sizes (pixels) — hardcoded per difficulty.  The UIManager
// centres the resulting board on any screen.
//   Easy 7×7  : cellPx = 28
//   Med  9×9  : cellPx = 22
//   Hard 11×11: cellPx = 18
// ═══════════════════════════════════════════════════════════════

using Toybox.Application;
using Toybox.Time;
using Toybox.Time.Gregorian;

class GameController {
    var state;
    var menuRow;
    var diff;
    var biomeMode;   // -1 = random, else GM_BIOME_*

    // Current maze
    var n;
    var walls;
    var extras;
    var exitCell;
    var cellPx;
    var biome;       // active biome this run

    var physics;
    var gyro;
    var mazeGen;

    // Stats
    var elapsed;     // game ticks since level start
    var level;       // current level index
    var bestMs;      // [easy, med, hard] best times in ms

    // Button-driven acceleration (set by InputHandler each tick)
    var btnAx;
    var btnAy;

    var dirty;

    function initialize() {
        state     = GM_MENU;
        menuRow   = 0;
        diff      = GM_DIFF_EASY;
        biomeMode = -1;

        n        = 7;
        walls    = [];
        extras   = [];
        exitCell = 0;
        cellPx   = 28;
        biome    = GM_BIOME_NORMAL;

        physics  = new PhysicsEngine();
        gyro     = new GyroInput();
        mazeGen  = new MazeGenerator();

        elapsed  = 0;
        level    = 0;
        bestMs   = [-1, -1, -1];
        btnAx    = 0;
        btnAy    = 0;
        dirty    = true;

        _loadAll();
    }

    // ── Persistence ────────────────────────────────────────────
    hidden function _li(key, defv) {
        try {
            var v = Application.Storage.getValue(key);
            if (v instanceof Number) { return v; }
        } catch (e) {}
        return defv;
    }
    hidden function _sv(key, v) {
        try { Application.Storage.setValue(key, v); } catch (e) {}
    }
    hidden function _loadAll() {
        diff      = _li("gm_diff",  GM_DIFF_EASY);
        if (diff < 0 || diff > 2) { diff = GM_DIFF_EASY; }
        biomeMode = _li("gm_biome", -1);
        if (biomeMode < -1 || biomeMode > GM_BIOME_CHAOS) { biomeMode = -1; }
        level     = _li("gm_level", 0);
        if (level < 0) { level = 0; }
        bestMs[0] = _li("gm_best_0", -1);
        bestMs[1] = _li("gm_best_1", -1);
        bestMs[2] = _li("gm_best_2", -1);
    }
    function saveSettings() {
        _sv("gm_diff",  diff);
        _sv("gm_biome", biomeMode);
        _sv("gm_level", level);
    }

    // ── Menu ───────────────────────────────────────────────────
    function menuNext() { menuRow = (menuRow + 1) % GM_MENU_ROWS; dirty = true; }
    function menuPrev() { menuRow = (menuRow + GM_MENU_ROWS - 1) % GM_MENU_ROWS; dirty = true; }
    function setMenuRow(i) {
        if (i >= 0 && i < GM_MENU_ROWS) { menuRow = i; dirty = true; }
    }
    function menuActivate() {
        if (menuRow == 0) {
            diff  = (diff + 1) % 3;
            level = 0;
        } else if (menuRow == 1) {
            biomeMode = biomeMode + 1;
            if (biomeMode > GM_BIOME_CHAOS) { biomeMode = -1; }
        } else {
            _startGame();
        }
        saveSettings();
        dirty = true;
    }
    function gotoMenu() { state = GM_MENU; dirty = true; }

    function diffName() {
        if (diff == GM_DIFF_EASY) { return "Easy 7x7";   }
        if (diff == GM_DIFF_MED)  { return "Med 9x9";    }
        return "Hard 11x11";
    }
    function biomeName() {
        if (biomeMode == -1)             { return "Random"; }
        if (biomeMode == GM_BIOME_ICE)   { return "Ice";    }
        if (biomeMode == GM_BIOME_TRAP)  { return "Trap";   }
        if (biomeMode == GM_BIOME_SPEED) { return "Speed";  }
        if (biomeMode == GM_BIOME_CHAOS) { return "Chaos";  }
        return "Normal";
    }
    function curBiomeName() {
        if (biome == GM_BIOME_ICE)   { return "ICE";   }
        if (biome == GM_BIOME_TRAP)  { return "TRAP";  }
        if (biome == GM_BIOME_SPEED) { return "SPEED"; }
        if (biome == GM_BIOME_CHAOS) { return "CHAOS"; }
        return "NORMAL";
    }
    function bestForDiff() { return bestMs[diff]; }
    function bestSec() {
        var b = bestMs[diff];
        return (b < 0) ? -1 : b / 1000;
    }
    function elapsedSec() { return elapsed * 80 / 1000; }

    // ── Lifecycle ──────────────────────────────────────────────
    hidden function _startGame() {
        if (diff == GM_DIFF_EASY) { n = 7;  cellPx = 28; }
        else if (diff == GM_DIFF_MED) { n = 9; cellPx = 22; }
        else                      { n = 11; cellPx = 18; }

        // Choose biome.
        if (biomeMode == -1) {
            biome = level % 5;
        } else {
            biome = biomeMode;
        }

        var seed = diff * 100000 + level * 137 + 1;
        var result = mazeGen.generate(n, biome, seed);
        walls    = result[0];
        extras   = result[1];
        exitCell = result[2];

        physics.setBiome(biome);
        physics.place(0, 0);   // start = cell (row=0, col=0)

        elapsed = 0;
        btnAx   = 0;
        btnAy   = 0;
        state   = GM_PLAY;
        dirty   = true;
    }

    // Restart current level (same seed / maze).
    function restart() {
        physics.place(0, 0);
        physics.vx = 0.0;
        physics.vy = 0.0;
        elapsed = 0;
        state   = GM_PLAY;
        dirty   = true;
    }

    function nextLevel() {
        level = level + 1;
        saveSettings();
        _startGame();
    }

    function togglePause() {
        if (state == GM_PLAY) { state = GM_PAUSE; }
        else if (state == GM_PAUSE) {
            gyro.calibrate();
            state = GM_PLAY;
        }
        dirty = true;
    }

    function recalibrate() { gyro.calibrate(); }

    // ── Main tick (called every 80 ms) ─────────────────────────
    function tick() {
        if (state != GM_PLAY) { return; }
        elapsed = elapsed + 1;

        // Combine gyro + button fallback.
        var accel = gyro.read();
        physics.applyAccel(accel[0] + btnAx * 80, accel[1] + btnAy * 80);

        physics.step(walls, n);

        // Tile effect.
        var cell  = physics.curCell(n);
        var extra = (cell >= 0 && cell < extras.size()) ? extras[cell] : GM_TILE_FLOOR;
        physics.applyTile(extra);

        // Death check.
        if (extra == GM_TILE_SPIKE) { state = GM_OVER; dirty = true; return; }

        // Win check.
        if (physics.atCell(exitCell, n)) { _win(); return; }

        dirty = true;
    }

    hidden function _win() {
        var ms = elapsed * 80;
        if (bestMs[diff] < 0 || ms < bestMs[diff]) {
            bestMs[diff] = ms;
            _sv("gm_best_" + diff.format("%d"), ms);
        }
        level = level + 1;
        saveSettings();
        state  = GM_WIN;
        dirty  = true;
    }
}
