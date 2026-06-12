// ═══════════════════════════════════════════════════════════════
// GameController.mc — StarSwarm game flow.
//
// States: SS_MENU → SS_PLAY → SS_WIN | SS_OVER → SS_MENU
//
// Menu (chess-style, 3 rows):
//   0  Difficulty (Easy / Normal / Hard)
//   1  Lives (1..5)
//   2  START
//
// Tick (80 ms cadence, driven by MainView's timer):
//   1. Glide player toward targetCol.
//   2. Step bullets up; resolve hits → score, remove bullets.
//   3. Animate formation sway.
//   4. Advance divers along their DiveAI path.
//   5. Promote idle formation members to divers (probabilistic).
//   6. Collision check — diving enemy on player cell → lose life.
//   7. If every enemy dead → wave bonus, next wave (or WIN at 9).
//
// Difficulty knob: starting dive speed (Easy 0.018 / Normal 0.022
//                  / Hard 0.028).  Wave number further scales it.
// ═══════════════════════════════════════════════════════════════

using Toybox.Application;
using Toybox.Math;

const SS_MENU = 0;
const SS_PLAY = 1;
const SS_WIN  = 2;
const SS_OVER = 3;

// Menu rows. Row 3 is the global LEADERBOARD (split by difficulty
// variant); it pushes a view from the View layer.
const SS_MENU_ROWS = 4;
const SS_ROW_DIFF  = 0;
const SS_ROW_LIVES = 1;
const SS_ROW_START = 2;
const SS_ROW_LB    = 3;

// Global leaderboard game id (matches _LOGOS / web id).
const SS_LB_GAME_ID = "starswarm";

const SS_BEST_KEY  = "ss_best";
const SS_DIFF_KEY  = "ss_diff";
const SS_LIVES_KEY = "ss_lives";

const SS_DIFF_EASY   = 0;
const SS_DIFF_NORMAL = 1;
const SS_DIFF_HARD   = 2;

const SS_MAX_WAVE = 9;

class GameController {
    var state;
    var menuRow;
    var menuDiff;
    var menuLives;

    var player;
    var bullets;
    var swarm;

    var wave;
    var lives;
    var score;
    var bestScore;

    function initialize() {
        state     = SS_MENU;
        menuRow   = 0;
        menuDiff  = SS_DIFF_NORMAL;
        menuLives = 3;

        player  = new Player();
        bullets = new ProjectileSystem();
        swarm   = new EnemyWaveSystem();

        wave  = 1; lives = 3; score = 0; bestScore = 0;
        _loadAll();
    }

    // ── Persistence ──────────────────────────────────────────────
    hidden function _loadAll() {
        try {
            var b = Application.Storage.getValue(SS_BEST_KEY);
            if (b != null) { bestScore = b; }
        } catch (e) {}
        try {
            var d = Application.Storage.getValue(SS_DIFF_KEY);
            if (d instanceof Number && d >= 0 && d <= 2) { menuDiff = d; }
        } catch (e) {}
        try {
            var l = Application.Storage.getValue(SS_LIVES_KEY);
            if (l instanceof Number && l >= 1 && l <= 5) { menuLives = l; }
        } catch (e) {}
    }
    hidden function _saveBest() {
        try { Application.Storage.setValue(SS_BEST_KEY, bestScore); } catch (e) {}
    }
    hidden function _saveSettings() {
        try { Application.Storage.setValue(SS_DIFF_KEY,  menuDiff);  } catch (e) {}
        try { Application.Storage.setValue(SS_LIVES_KEY, menuLives); } catch (e) {}
    }

    // ── Menu ────────────────────────────────────────────────────
    function menuNext() { menuRow = (menuRow + 1) % SS_MENU_ROWS; }
    function menuPrev() { menuRow = (menuRow + SS_MENU_ROWS - 1) % SS_MENU_ROWS; }
    function setMenuRow(i) { if (i >= 0 && i < SS_MENU_ROWS) { menuRow = i; } }
    function menuActivate() {
        if (menuRow == SS_ROW_DIFF) {
            menuDiff = (menuDiff + 1) % 3;
            _saveSettings();
        } else if (menuRow == SS_ROW_LIVES) {
            menuLives = (menuLives % 5) + 1;
            _saveSettings();
        } else if (menuRow == SS_ROW_START) {
            _startGame();
        }
        // SS_ROW_LB is handled by MainView.openLeaderboard().
    }

    function gotoMenu() { state = SS_MENU; }

    function difficultyName() {
        if (menuDiff == SS_DIFF_EASY)   { return "Easy";   }
        if (menuDiff == SS_DIFF_NORMAL) { return "Normal"; }
        return "Hard";
    }

    hidden function _baseDiveSpeed() {
        if (menuDiff == SS_DIFF_EASY)   { return 0.018; }
        if (menuDiff == SS_DIFF_NORMAL) { return 0.022; }
        return 0.028;
    }

    hidden function _maxDivers() {
        if (menuDiff == SS_DIFF_EASY)   { return 1 + wave / 3; }   // 1..4
        if (menuDiff == SS_DIFF_NORMAL) { return 1 + wave / 2; }
        return 1 + (wave * 2) / 3;
    }

    // ── Lifecycle ───────────────────────────────────────────────
    hidden function _startGame() {
        wave  = 1;
        lives = menuLives;
        score = 0;
        _spawnWave();
        state = SS_PLAY;
    }

    hidden function _spawnWave() {
        player.spawn();
        bullets.reset();
        swarm.populate(wave, _baseDiveSpeed());
    }

    // ── Input intents ───────────────────────────────────────────
    function moveLeft()  { if (state == SS_PLAY) { player.nudge(-1); } }
    function moveRight() { if (state == SS_PLAY) { player.nudge( 1); } }
    function fire() {
        if (state != SS_PLAY) { return; }
        if (!player.canFire()) { return; }
        if (bullets.fire(player.intCol(), player.row)) {
            player.markFired();
        }
    }

    // ── Tick (80 ms) ────────────────────────────────────────────
    function tick() {
        if (state != SS_PLAY) { return; }

        // 1. Ship glide.
        player.tickGlide();

        // 2. Bullets.
        bullets.tick();
        var killed = bullets.collideAndKill(swarm.enemies);
        if (killed > 0) { score = score + killed * 50; }

        // 3-5. Enemies.
        swarm.tickFormation();
        swarm.tickDives();
        swarm.pickDivers(_maxDivers(), player.col);

        // 6. Player collision: any diver standing on player cell?
        var pc = player.intCol();
        var pr = player.row;
        var cells = swarm.divingCells();
        for (var i = 0; i < cells.size(); i++) {
            var c = cells[i];
            if (c[0] == pc && c[1] == pr) { _onPlayerHit(); return; }
        }

        // 7. Wave cleared?
        if (swarm.allDead()) {
            score = score + 100 + wave * 50;
            if (wave >= SS_MAX_WAVE) {
                state = SS_WIN;
                if (score > bestScore) { bestScore = score; _saveBest(); }
                // Submit to the global leaderboard, split by difficulty variant.
                Leaderboard.submitScore(SS_LB_GAME_ID, score, difficultyName());
                Leaderboard.showPostGame(SS_LB_GAME_ID, difficultyName(), "STAR SWARM");
                return;
            }
            wave = wave + 1;
            _spawnWave();
        }
    }

    hidden function _onPlayerHit() {
        lives = lives - 1;
        if (lives <= 0) {
            state = SS_OVER;
            if (score > bestScore) { bestScore = score; _saveBest(); }
            // Submit to the global leaderboard, split by difficulty variant.
            Leaderboard.submitScore(SS_LB_GAME_ID, score, difficultyName());
            Leaderboard.showPostGame(SS_LB_GAME_ID, difficultyName(), "STAR SWARM");
            return;
        }
        // Soft restart: keep the swarm but freeze divers, respawn ship.
        for (var i = 0; i < swarm.enemies.size(); i++) {
            var e = swarm.enemies[i];
            if (e.state == E_DIVING) {
                e.state = E_FORMATION;
                e.col   = e.formC + 0.0;
                e.row   = e.formR + 0.0;
            }
        }
        player.spawn();
        bullets.reset();
    }
}
