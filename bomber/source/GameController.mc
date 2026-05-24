// ═══════════════════════════════════════════════════════════════
// GameController.mc — Bomber state machine + game loop.
//
// Menu (chess-style, 4 rows):
//   0  Enemies  (1 / 2 / 3)
//   1  Map      (Small 7x7 / Big 9x9)
//   2  Speed    (Slow / Normal / Fast)
//   3  START
//
// Persistence:
//   bm_enemies, bm_mapsize, bm_speed     — menu settings
//   bm_high_score                          — lifetime best score
//   bm_levels_cleared                      — lifetime cleared count
//
// Game loop:
//   tick(dtMs) is driven by MainView's 80 ms timer.  We thread the
//   dt through every subsystem (bomb timers, flame timers, enemy
//   step countdown, power-up timers) so the simulation runs at a
//   stable wall-clock rate independent of how often the view
//   redraws.
// ═══════════════════════════════════════════════════════════════

using Toybox.Application;
using Toybox.Math;

class GameController {
    var state;
    var menuRow;

    var enemyCount;
    var mapSize;
    var speed;

    var grid;
    var bombSys;
    var explSys;
    var enemyMgr;

    var px;        // player col (we keep x = col, y = row for clarity)
    var py;
    var moveCdMs;

    var maxBombs;
    var bombRange;
    var shieldMs;
    var ghostMs;

    var score;
    var level;
    var highScore;
    var lifetimeLevels;

    var dirty;

    function initialize() {
        state          = BS_MENU;
        menuRow        = 0;
        enemyCount     = 1;
        mapSize        = 1;       // big 9x9
        speed          = BSP_NORMAL;
        grid           = new GridManager();
        bombSys        = new BombSystem();
        explSys        = new ExplosionSystem();
        enemyMgr       = new EnemyManager();
        px = 1; py = 1;
        moveCdMs       = 0;
        maxBombs       = 1;
        bombRange      = 2;
        shieldMs       = 0;
        ghostMs        = 0;
        score          = 0;
        level          = 1;
        highScore      = 0;
        lifetimeLevels = 0;
        dirty          = true;
        _loadAll();
    }

    // ── Persistence ────────────────────────────────────────────
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
        enemyCount = _loadInt("bm_enemies", 1);
        if (enemyCount < 1 || enemyCount > 3) { enemyCount = 1; }
        mapSize = _loadInt("bm_mapsize", 1);
        if (mapSize < 0 || mapSize > 1) { mapSize = 1; }
        speed = _loadInt("bm_speed", BSP_NORMAL);
        if (speed < 0 || speed > 2) { speed = BSP_NORMAL; }
        highScore      = _loadInt("bm_high_score", 0);
        lifetimeLevels = _loadInt("bm_levels_cleared", 0);
    }
    function saveMenuSettings() {
        _save("bm_enemies", enemyCount);
        _save("bm_mapsize", mapSize);
        _save("bm_speed",   speed);
    }

    // ── Menu ───────────────────────────────────────────────────
    function menuNext() { menuRow = (menuRow + 1) % BM_MENU_ROWS; dirty = true; }
    function menuPrev() { menuRow = (menuRow + BM_MENU_ROWS - 1) % BM_MENU_ROWS; dirty = true; }
    function setMenuRow(i) {
        if (i >= 0 && i < BM_MENU_ROWS) { menuRow = i; dirty = true; }
    }

    function menuActivate() {
        if (menuRow == 0) {
            enemyCount = enemyCount + 1;
            if (enemyCount > 3) { enemyCount = 1; }
        } else if (menuRow == 1) {
            mapSize = (mapSize + 1) % 2;
        } else if (menuRow == 2) {
            speed = (speed + 1) % 3;
        } else {
            _startGame();
            saveMenuSettings();
            return;
        }
        saveMenuSettings();
        dirty = true;
    }
    function gotoMenu() { state = BS_MENU; dirty = true; }

    function mapEdge()  { return (mapSize == 0) ? 7 : 9; }
    function mapName()  { return (mapSize == 0) ? "Small 7x7" : "Big 9x9"; }
    function speedName() {
        if (speed == BSP_SLOW)   { return "Slow"; }
        if (speed == BSP_FAST)   { return "Fast"; }
        return "Normal";
    }

    // Tick tables (ms).  Faster speed → snappier enemies + shorter fuse.
    hidden function _enemyStepMs() {
        if (speed == BSP_SLOW) { return 1100; }
        if (speed == BSP_FAST) { return 500; }
        return 800;
    }
    hidden function _bombFuseMs() {
        if (speed == BSP_SLOW) { return 2500; }
        if (speed == BSP_FAST) { return 1600; }
        return 2000;
    }

    // ── Lifecycle ──────────────────────────────────────────────
    hidden function _startGame() {
        score = 0; level = 1; dirty = true;
        _setupLevel();
        state = BS_PLAY;
    }
    hidden function _setupLevel() {
        var n = mapEdge();
        // Block density rises slightly with level for a difficulty curve.
        var density = 50 + level * 2;
        if (density > 65) { density = 65; }
        // Use Math.rand() for the seed so each game is unique.
        var seed = Math.rand();
        if (seed < 0) { seed = -seed; }
        if (seed == 0) { seed = 1 + level * 7; }
        grid.generate(n, density, seed);

        bombSys.reset();
        bombSys.fuseMs       = _bombFuseMs();
        bombSys.defaultRange = bombRange;
        explSys.reset();
        enemyMgr.stepIntervalMs = _enemyStepMs();
        enemyMgr.spawn(grid, enemyCount + (level - 1) / 3);   // +1 enemy every 3 levels
        if (enemyMgr.enemies.size() > 3) {
            enemyMgr.enemies = enemyMgr.enemies.slice(0, 3);
        }

        px = 1; py = 1;
        moveCdMs = 0;
        shieldMs = 0;
        ghostMs  = 0;
        // Power-up bonuses persist across levels — tougher progression.
    }

    function restart() {
        if (state != BS_PLAY && state != BS_OVER && state != BS_WIN) { return; }
        score = 0;
        level = 1;
        maxBombs  = 1;
        bombRange = 2;
        _setupLevel();
        state = BS_PLAY;
        dirty = true;
    }

    function nextLevel() {
        level = level + 1;
        _setupLevel();
        state = BS_PLAY;
        dirty = true;
    }

    // ── Game loop ──────────────────────────────────────────────
    function tick(dtMs) {
        if (state != BS_PLAY) { return; }
        if (moveCdMs > 0) { moveCdMs = moveCdMs - dtMs; if (moveCdMs < 0) { moveCdMs = 0; } }
        if (shieldMs > 0) { shieldMs = shieldMs - dtMs; if (shieldMs < 0) { shieldMs = 0; } }
        if (ghostMs  > 0) { ghostMs  = ghostMs  - dtMs; if (ghostMs  < 0) { ghostMs  = 0; } }

        // 1. Decrement bomb fuses; collect ones whose time is up.
        bombSys.tick(dtMs);
        var due = bombSys.drainExploded();
        for (var i = 0; i < due.size(); i++) {
            var b = due[i];
            var destroyed = explSys.ignite(grid, bombSys, b[0], b[1], b[3]);
            score = score + destroyed * 10;
        }

        // 2. Tick flames.
        explSys.tick(dtMs);

        // 3. Enemies first (their move can overlap player → death).
        enemyMgr.tick(dtMs, grid, bombSys);
        var killed = enemyMgr.killOnFlame(explSys);
        if (killed > 0) { score = score + killed * 50; }

        // 4. Damage checks on player.
        if (shieldMs <= 0) {
            if (explSys.isFlameAt(py, px) || enemyMgr.isAt(py, px)) {
                _finishOver();
                return;
            }
        }

        // 5. Pickup power-up if we're sitting on one.
        _maybePickup();

        // 6. Level cleared?
        if (enemyMgr.aliveCount() == 0) {
            _finishLevelClear();
        }

        dirty = true;
    }

    // ── Player intents ─────────────────────────────────────────
    function move(dr, dc) {
        if (state != BS_PLAY) { return; }
        if (moveCdMs > 0) { return; }
        var nr = py + dr;
        var nc = px + dc;
        var ghost = (ghostMs > 0);
        if (!grid.isWalkable(nr, nc, ghost)) { return; }
        if (bombSys.hasBombAt(nr, nc))       { return; }
        py = nr; px = nc;
        moveCdMs = 150;
        _maybePickup();
        dirty = true;
    }

    function placeBomb() {
        if (state != BS_PLAY) { return; }
        var owned = bombSys.count();
        bombSys.place(py, px, owned, maxBombs, bombRange);
        dirty = true;
    }

    hidden function _maybePickup() {
        var t = grid.tileAt(py, px);
        if      (t == BT_PU_BOMB)   { maxBombs  = maxBombs  + 1; score = score + 25; }
        else if (t == BT_PU_RANGE)  { bombRange = bombRange + 1; score = score + 25; }
        else if (t == BT_PU_SHIELD) { shieldMs  = 6000;           score = score + 25; }
        else if (t == BT_PU_GHOST)  { ghostMs   = 6000;           score = score + 25; }
        else { return; }
        if (maxBombs > 8)  { maxBombs  = 8; }
        if (bombRange > 6) { bombRange = 6; }
        grid.setTile(py, px, BT_EMPTY);
    }

    // ── Outcomes ───────────────────────────────────────────────
    hidden function _finishLevelClear() {
        score = score + 100;
        lifetimeLevels = lifetimeLevels + 1;
        _save("bm_levels_cleared", lifetimeLevels);
        if (score > highScore) {
            highScore = score;
            _save("bm_high_score", highScore);
        }
        state = BS_WIN;
        dirty = true;
    }
    hidden function _finishOver() {
        if (score > highScore) {
            highScore = score;
            _save("bm_high_score", highScore);
        }
        state = BS_OVER;
        dirty = true;
    }
}
