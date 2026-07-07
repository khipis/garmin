// ═══════════════════════════════════════════════════════════════
// GameController.mc — Game flow, turn loop, persistence.
//
// States: HG_S_MENU → HG_S_PLAY → HG_S_WIN | HG_S_OVER → menu
//
// One press = one turn:
//   1. Player tries to step in selected direction.
//   2. If blocked: no turn consumed.
//   3. Otherwise: AI blockers all step.
//   4. Collision check (any blocker on player tile → lose life).
//   5. If player on EXIT: level cleared, +bonus, build next level.
// ═══════════════════════════════════════════════════════════════

using Toybox.Application;

const HG_S_MENU = 0;
const HG_S_PLAY = 1;
const HG_S_WIN  = 2;
const HG_S_OVER = 3;

const HG_BEST_KEY = "hg_best";

// Global leaderboard game id (matches _LOGOS / web id). No
// difficulty setting exists (only Start Level / Lives), so the
// leaderboard runs without a variant.
const HG_LB_GAME_ID = "hologrid";

// Menu row indices. The LEADERBOARD row is appended last and is
// handled by MainView.openLeaderboard().
const HG_ROW_START = 2;
const HG_ROW_LB    = 3;

// Levels selectable from the menu.  Cycling through every level
// 1..30 would be tedious, so we hop in jumps that line up with the
// difficulty bands of LevelGenerator.
const HG_START_MARKS = [1, 5, 10, 15, 20, 25, 30];

class GameController {
    var state;
    var menuRow;
    var menuStartLevel;
    var menuLives;

    var grid;
    var player;
    var blockers;
    var level;
    var lives;
    var score;
    var bestScore;

    // Saved per-level so respawn after death uses the same corner
    // (the corner rotates with the level).
    hidden var _spawnR;
    hidden var _spawnC;

    function initialize() {
        state          = HG_S_MENU;
        menuRow        = 0;
        menuStartLevel = 1;
        menuLives      = 3;
        level          = 1;
        lives          = 3;
        score          = 0;
        bestScore      = 0;
        player         = new Player();
        blockers       = [];
        _spawnR        = 1;
        _spawnC        = 1;
        var lvl        = LevelGenerator.build(1);
        grid           = lvl[0];
        _loadBest();
        _loadSettings();
    }

    hidden function _loadBest() {
        try {
            var v = Application.Storage.getValue(HG_BEST_KEY);
            if (v != null) { bestScore = v; }
        } catch (e) {}
    }
    hidden function _saveBest() {
        try { Application.Storage.setValue(HG_BEST_KEY, bestScore); } catch (e) {}
    }
    hidden function _loadSettings() {
        // OPTIONS persists both settings as a 0-based index (the shared
        // GmOption model). Start Level is an index into HG_START_MARKS;
        // Lives is (index + 1).
        try {
            var s = Application.Storage.getValue("hg_slvl");
            if (s instanceof Number && s >= 0 && s < HG_START_MARKS.size()) {
                menuStartLevel = HG_START_MARKS[s];
            }
        } catch (e) {}
        try {
            var l = Application.Storage.getValue("hg_lives");
            if (l instanceof Number && l >= 0 && l <= 4) { menuLives = l + 1; }
        } catch (e) {}
    }
    hidden function _saveSettings() {
        // Kept for completeness; OPTIONS now owns these keys as indices.
        try {
            var idx = 0;
            for (var i = 0; i < HG_START_MARKS.size(); i++) {
                if (HG_START_MARKS[i] == menuStartLevel) { idx = i; break; }
            }
            Application.Storage.setValue("hg_slvl", idx);
        } catch (e) {}
        try { Application.Storage.setValue("hg_lives", menuLives - 1); } catch (e) {}
    }

    // Public entry used by the auto-start MainView (settings from Storage).
    function startGame() { _loadSettings(); _startNewGame(); }

    // ── Menu ─────────────────────────────────────────────────────
    function menuNext() { menuRow = (menuRow + 1) % HG_MENU_ROWS; }
    function menuPrev() { menuRow = (menuRow + HG_MENU_ROWS - 1) % HG_MENU_ROWS; }
    function setMenuRow(i) { if (i >= 0 && i < HG_MENU_ROWS) { menuRow = i; } }
    function menuActivate() {
        if (menuRow == 0) {
            // Cycle to the next mark; wrap at the end.
            var idx = 0;
            for (var i = 0; i < HG_START_MARKS.size(); i++) {
                if (HG_START_MARKS[i] == menuStartLevel) { idx = i; break; }
            }
            idx = (idx + 1) % HG_START_MARKS.size();
            menuStartLevel = HG_START_MARKS[idx];
            _saveSettings();
        } else if (menuRow == 1) {
            menuLives = (menuLives % 5) + 1;
            _saveSettings();
        } else if (menuRow == HG_ROW_START) {
            _startNewGame();
        }
        // HG_ROW_LB is handled by MainView.openLeaderboard().
    }
    function gotoMenu() { state = HG_S_MENU; }

    hidden function _startNewGame() {
        level = menuStartLevel;
        lives = menuLives;
        score = 0;
        _buildLevel();
        state = HG_S_PLAY;
    }

    hidden function _buildLevel() {
        var lvl   = LevelGenerator.build(level);
        grid      = lvl[0];
        var sp    = lvl[1];
        var specs = lvl[3];
        _spawnR   = sp[0];
        _spawnC   = sp[1];
        player.spawnAt(sp);
        blockers = [];
        for (var i = 0; i < specs.size(); i++) {
            var s = specs[i];
            blockers.add(new Blocker(s[0], s[1], s[2]));
        }
    }

    // ── Turn ─────────────────────────────────────────────────────
    function tryMove(d) {
        if (state != HG_S_PLAY) { return; }
        player.facing = d;
        var de = GridSystem.dirDelta(d);
        var nr = player.r + de[0]; var nc = player.c + de[1];
        if (!grid.isWalkable(nr, nc)) { return; }
        player.r = nr; player.c = nc;
        score = score + 1;

        // If we stepped onto the exit, that's a level win — no AI
        // turn happens so the player can't be caught on the exit tile.
        if (grid.get(player.r, player.c) == HG_EXIT) {
            _onLevelClear();
            return;
        }

        // AI moves.
        AIController.step(blockers, grid, player);

        // Collision (after AI move).
        if (AIController.huntersHitPlayer(blockers, player)) {
            _onCaught();
        }
    }

    hidden function _onCaught() {
        lives = lives - 1;
        if (lives <= 0) {
            state = HG_S_OVER;
            if (score > bestScore) { bestScore = score; _saveBest(); }
            Leaderboard.submitScore(HG_LB_GAME_ID, score, "");
            Leaderboard.showPostGame(HG_LB_GAME_ID, "", "HOLOGRID");
            return;
        }
        // Respawn at the *current level's* spawn corner.  AI keeps
        // its positions so the restart feels punitive but fair.
        player.spawnAt([_spawnR, _spawnC]);
    }

    hidden function _onLevelClear() {
        score = score + 100 + level * 25;
        level = level + 1;
        if (level > HG_MAX_LEVEL) {
            state = HG_S_WIN;
            if (score > bestScore) { bestScore = score; _saveBest(); }
            Leaderboard.submitScore(HG_LB_GAME_ID, score, "");
            Leaderboard.showPostGame(HG_LB_GAME_ID, "", "HOLOGRID");
            return;
        }
        _buildLevel();
    }
}
