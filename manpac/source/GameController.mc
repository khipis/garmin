// ═══════════════════════════════════════════════════════════════
// GameController.mc — Manpac game state machine.
//
// States:   GS_MENU → GS_PLAY → GS_WIN | GS_OVER → GS_MENU
//
// Menu (chess-style, 3 rows):
//   0  Start Level (1..9)
//   1  Lives (1..5)
//   2  START
//
// Level progression (each cleared maze increments `level`):
//   • Maze layout cycles 0 → 1 → 2 → 0 → ...
//   • Ghost count        2 → 3 → 3 → 4 → 4 (capped at 4)
//   • Tick interval      ramps from 210 ms (lvl 1) down to ~95 ms
//     (lvl 9+).  The view reads `tickMs()` after each level.
//
// Gameplay tick (called by MainView's timer):
//   1. Apply queued direction if legal.
//   2. Move Pac-Man one cell.
//   3. Eat pellet / power pellet.  Power pellet → frighten ghosts.
//   4. Step ghosts (skip respawning ones).
//   5. Resolve overlap:
//        • If frightened ghost → eat it (+200, +400, +800, +1600).
//        • Else → lose a life, respawn at start.
//   6. Decay frightened timer; bonus chain resets when timer hits 0.
//   7. If all pellets eaten → next level (or WIN at level 9).
// ═══════════════════════════════════════════════════════════════

using Toybox.Application;
using Toybox.Math;
using Toybox.System;

const GS_MENU = 0;
const GS_PLAY = 1;
const GS_WIN  = 2;
const GS_OVER = 3;

const MENU_ROWS = 3;

const MP_BEST_KEY = "mp_best";
const MP_SLVL_KEY = "mp_slvl";
const MP_LIVES_KEY = "mp_lives";

class GameController {
    var state;
    var menuRow;
    var menuStartLevel;
    var menuLives;

    var grid;
    var n;
    var player;
    var ghosts;
    var pelletsLeft;
    var score;
    var lives;
    var level;
    var bestScore;

    // Frightened-mode timer (ticks remaining) and the bonus chain
    // for eating multiple ghosts on one power pellet.
    var frightTicks;
    var fearChain;        // 1,2,3,4 → 200/400/800/1600

    function initialize() {
        state = GS_MENU;
        menuRow = 0;
        menuStartLevel = 1;
        menuLives      = 3;
        n = MAZE_SIZE;
        grid = MazeGenerator.build(0);
        player = new Player();
        ghosts = [];
        pelletsLeft = 0;
        score = 0;
        lives = 3;
        level = 1;
        bestScore = 0;
        frightTicks = 0;
        fearChain   = 0;
        _loadBest();
        _loadSettings();
    }

    hidden function _loadBest() {
        try {
            var v = Application.Storage.getValue(MP_BEST_KEY);
            if (v != null) { bestScore = v; }
        } catch (e) {}
    }
    hidden function _saveBest() {
        try { Application.Storage.setValue(MP_BEST_KEY, bestScore); } catch (e) {}
    }
    hidden function _loadSettings() {
        try {
            var s = Application.Storage.getValue(MP_SLVL_KEY);
            if (s instanceof Number && s >= 1 && s <= 9) { menuStartLevel = s; }
        } catch (e) {}
        try {
            var l = Application.Storage.getValue(MP_LIVES_KEY);
            if (l instanceof Number && l >= 1 && l <= 5) { menuLives = l; }
        } catch (e) {}
    }
    hidden function _saveSettings() {
        try { Application.Storage.setValue(MP_SLVL_KEY,  menuStartLevel); } catch (e) {}
        try { Application.Storage.setValue(MP_LIVES_KEY, menuLives);      } catch (e) {}
    }

    // ── Menu navigation ──────────────────────────────────────────
    function menuNext()    { menuRow = (menuRow + 1) % MENU_ROWS; }
    function menuPrev()    { menuRow = (menuRow + MENU_ROWS - 1) % MENU_ROWS; }
    function setMenuRow(i) { if (i >= 0 && i < MENU_ROWS) { menuRow = i; } }
    function menuActivate() {
        if (menuRow == 0) {
            menuStartLevel = (menuStartLevel % 9) + 1;
            _saveSettings();
        } else if (menuRow == 1) {
            menuLives = (menuLives % 5) + 1;
            _saveSettings();
        } else {
            _startGame();
        }
    }

    // ── Level progression ───────────────────────────────────────
    // Ghost count for current level (capped at 4).
    function ghostCount() {
        var g = 1 + level;        // L1→2, L2→3, L3→4, L4→5, ...
        if (g > 4) { g = 4; }
        if (g < 2) { g = 2; }
        return g;
    }

    // Tick interval in ms for this level — faster each level.
    function tickMs() {
        var v = 210 - (level - 1) * 14;   // L1=210, L2=196, ... L9=98
        if (v < 90)  { v = 90;  }
        if (v > 240) { v = 240; }
        return v;
    }

    // ── Game lifecycle ──────────────────────────────────────────
    hidden function _startGame() {
        level = menuStartLevel;
        lives = menuLives;
        score = 0;
        _buildLevel();
        state = GS_PLAY;
    }

    hidden function _buildLevel() {
        grid = MazeGenerator.build(level - 1);
        var sp = MazeGenerator.spawnPlayer();
        player.setSpawn(sp);
        ghosts = [];
        var gn = ghostCount();
        // Alternate tracker/random so the early levels feel fair.
        var types = [GHOST_TRACKER, GHOST_RANDOM, GHOST_TRACKER, GHOST_RANDOM];
        for (var i = 0; i < gn; i++) {
            var gs = MazeGenerator.spawnGhost(i);
            ghosts.add(new Ghost(gs[0], gs[1], types[i]));
        }
        pelletsLeft = MazeGenerator.countPellets(grid);
        frightTicks = 0;
        fearChain   = 0;
    }

    function gotoMenu() { state = GS_MENU; }

    // Queue a new direction (called by swipe handler).  Reject the
    // direct opposite of the current heading — Pac-Man can U-turn
    // through normal gameplay flow but we don't want a "twitch" to
    // accidentally reverse into a ghost.  Actually classic Pac-Man
    // does allow U-turn, so we let it through.
    function setDir(d) {
        if (state != GS_PLAY) { return; }
        player.setNextDir(d);
    }

    // Called by MainView's timer every `tickMs` ms.
    function tick() {
        if (state != GS_PLAY) { return; }

        // 1. Apply queued direction if legal.
        var nd = player.nextDir;
        var dn = Player.delta(nd);
        if (!CollisionSystem.isWall(grid, n,
                                     player.r + dn[0], player.c + dn[1])) {
            player.dir = nd;
        }

        // 2. Move Pac-Man one cell if not facing a wall.
        var de = Player.delta(player.dir);
        var nr = player.r + de[0]; var nc = player.c + de[1];
        if (!CollisionSystem.isWall(grid, n, nr, nc)) {
            player.r = nr; player.c = nc;
        }
        player.tickAnim();

        // 3. Eat what's under us.
        var t = CollisionSystem.consume(grid, n, player);
        if (t == TILE_PELLET) {
            score = score + 10;
            pelletsLeft = pelletsLeft - 1;
        } else if (t == TILE_POWER) {
            score = score + 50;
            pelletsLeft = pelletsLeft - 1;
            // Power-pellet → frighten every active ghost.
            frightTicks = 30;
            fearChain   = 0;
            for (var i = 0; i < ghosts.size(); i++) { ghosts[i].frighten(30); }
        }

        // 3b. Collision check BEFORE ghosts move (pass-through case:
        //     Pac-Man steps onto a ghost's tile).
        var gi = CollisionSystem.ghostOnPlayer(ghosts, player);
        if (gi >= 0) { _onGhostContact(gi); if (state != GS_PLAY) { return; } }

        // 4. Step ghosts.
        for (var j = 0; j < ghosts.size(); j++) {
            ghosts[j].step(grid, n, player.r, player.c);
        }

        // 5. Collision check AFTER ghost moves (ghost steps onto us).
        gi = CollisionSystem.ghostOnPlayer(ghosts, player);
        if (gi >= 0) { _onGhostContact(gi); if (state != GS_PLAY) { return; } }

        // 6. Decay frightened timer.
        if (frightTicks > 0) {
            frightTicks = frightTicks - 1;
            if (frightTicks == 0) {
                for (var k = 0; k < ghosts.size(); k++) { ghosts[k].unfrighten(); }
                fearChain = 0;
            }
        }

        // 7. Level cleared?
        if (pelletsLeft <= 0) { _onLevelClear(); }
    }

    // Resolve Pac-Man being on the same tile as ghost #i.
    hidden function _onGhostContact(i) {
        var g = ghosts[i];
        if (g.frightened) {
            // Eat the ghost.  Score chain: 200, 400, 800, 1600.
            fearChain = fearChain + 1;
            var bonus = 200;
            if      (fearChain == 2) { bonus = 400; }
            else if (fearChain == 3) { bonus = 800; }
            else if (fearChain >= 4) { bonus = 1600; }
            score = score + bonus;
            g.eaten();
        } else {
            // Pac-Man dies.
            lives = lives - 1;
            if (lives <= 0) {
                _onGameOver();
            } else {
                _respawnAfterDeath();
            }
        }
    }

    hidden function _respawnAfterDeath() {
        var sp = MazeGenerator.spawnPlayer();
        player.setSpawn(sp);
        // Send each ghost home for 6 ticks so the player has a chance.
        for (var i = 0; i < ghosts.size(); i++) {
            var g = ghosts[i];
            g.r = g.homeR; g.c = g.homeC;
            g.respawnTicks = 6;
            g.frightened   = false;
        }
        frightTicks = 0;
        fearChain   = 0;
    }

    hidden function _onLevelClear() {
        // Bonus for clearing + remaining lives.
        score = score + 100 + level * 50 + lives * 25;
        if (level >= 9) {
            _onWin();
            return;
        }
        level = level + 1;
        _buildLevel();
    }

    hidden function _onWin() {
        state = GS_WIN;
        if (score > bestScore) { bestScore = score; _saveBest(); }
    }
    hidden function _onGameOver() {
        state = GS_OVER;
        if (score > bestScore) { bestScore = score; _saveBest(); }
    }
}
