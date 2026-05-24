// ═══════════════════════════════════════════════════════════════
// GameController.mc — Game flow & turn logic.
//
// States:  GM_S_MENU → GM_S_PLAY → GM_S_WIN | GM_S_OVER → menu
//
// One player action = one turn:
//   • Move L / R: step horizontally if cell is empty/diggable.
//     Diggable = DIRT only.  Rocks/Ore/Gem block lateral movement.
//   • Mine D: mine the tile below; collect points; then settle
//     gravity; then apply player gravity (fall until supported).
//   After every action, if any rock falls onto the player tile,
//   they lose a life and respawn at the top of their column.
//
// Reach the bottom platform row → level cleared, +bonus, next level.
// ═══════════════════════════════════════════════════════════════

using Toybox.Application;

const GM_S_MENU = 0;
const GM_S_PLAY = 1;
const GM_S_WIN  = 2;
const GM_S_OVER = 3;

class GameController {
    var state;
    var menuRow;
    var menuDiff;
    var menuLives;

    var grid;
    var player;
    var res;
    var lives;
    var pendingDir;     // currently-selected mine/move target

    function initialize() {
        state = GM_S_MENU;
        menuRow = 0;
        menuDiff = 1;
        menuLives = 3;
        grid = new GridManager(9, 12);
        grid.generate(menuDiff);
        player = new Player();
        res = new ResourceManager();
        lives = menuLives;
        pendingDir = GM_DIR_D;
        _loadSettings();
    }

    hidden function _loadSettings() {
        try {
            var d = Application.Storage.getValue("gm_diff");
            if (d instanceof Number && d >= 0 && d < 3) { menuDiff = d; }
        } catch (e) {}
        try {
            var l = Application.Storage.getValue("gm_lives");
            if (l instanceof Number && l >= 1 && l <= 5) { menuLives = l; }
        } catch (e) {}
    }
    hidden function _saveSettings() {
        try { Application.Storage.setValue("gm_diff",  menuDiff);  } catch (e) {}
        try { Application.Storage.setValue("gm_lives", menuLives); } catch (e) {}
    }

    // ── Menu ─────────────────────────────────────────────────────
    function menuNext() { menuRow = (menuRow + 1) % GM_MENU_ROWS; }
    function menuPrev() { menuRow = (menuRow + GM_MENU_ROWS - 1) % GM_MENU_ROWS; }
    function setMenuRow(i) { if (i >= 0 && i < GM_MENU_ROWS) { menuRow = i; } }
    function menuActivate() {
        if (menuRow == 0)      { menuDiff = (menuDiff + 1) % 3; _saveSettings(); }
        else if (menuRow == 1) { menuLives = (menuLives % 5) + 1; _saveSettings(); }
        else { _startLevel(true); }
    }

    function gotoMenu() { state = GM_S_MENU; }

    hidden function _startLevel(reset) {
        grid.generate(menuDiff);
        player.spawnAt(0, grid.w / 2);
        if (reset) {
            res.reset();
            res.level = 1;
            lives = menuLives;
        }
        pendingDir = GM_DIR_D;
        state = GM_S_PLAY;
    }

    // ── Turn loop ───────────────────────────────────────────────
    function actMove(d) {
        if (state != GM_S_PLAY) { return; }
        pendingDir = d;
        if (d == GM_DIR_L || d == GM_DIR_R) { _stepHoriz(d); }
        else if (d == GM_DIR_D)             { _mineDown();   }
        _postTurn();
    }

    hidden function _stepHoriz(d) {
        var nc = player.c + (d == GM_DIR_R ? 1 : -1);
        player.facing = d;
        var t = grid.get(player.r, nc);
        if (t == GM_EMPTY)   { player.c = nc; }
        else if (t == GM_DIRT) {
            grid.set(player.r, nc, GM_EMPTY);
            player.c = nc;
            res.score = res.score + 1;
        }
        // Rocks/ore/gem block — they're too heavy to push sideways.
    }

    hidden function _mineDown() {
        player.facing = GM_DIR_D;
        var nr = player.r + 1;
        var t  = grid.get(nr, player.c);
        if (t == GM_WALL) { return; }
        if (t == GM_EMPTY) {
            player.r = nr;     // fall in
            return;
        }
        res.collect(t);
        grid.set(nr, player.c, GM_EMPTY);
        player.r = nr;
    }

    hidden function _postTurn() {
        // 1. Gravity for blocks above.
        var crushed = GravityEngine.settle(grid, player.r, player.c, 16);
        // 2. Player falls until supported.
        var f = GravityEngine.applyPlayerGravity(grid, player.r, player.c, grid.h);
        player.r = f[0];
        // Re-run gravity once after the player fell — a falling rock
        // can now land on the player's new tile.
        var crushed2 = GravityEngine.settle(grid, player.r, player.c, 8);
        if (crushed || crushed2) {
            _onCrushed(); return;
        }
        // 3. Bottom-row platform reached?
        if (player.r == grid.h - 2) {
            _onLevelClear();
        }
    }

    hidden function _onCrushed() {
        lives = lives - 1;
        if (lives <= 0) {
            state = GM_S_OVER;
            res.commitBest();
            return;
        }
        // Respawn at top of current column.
        player.spawnAt(0, grid.w / 2);
        var crushed = GravityEngine.settle(grid, player.r, player.c, 4);
        if (crushed) { _onCrushed(); }
    }

    hidden function _onLevelClear() {
        res.score = res.score + 100;
        res.level = res.level + 1;
        if (res.level > 9) {
            state = GM_S_WIN;
            res.commitBest();
            return;
        }
        // Next level, same lives.
        _startLevel(false);
    }
}
